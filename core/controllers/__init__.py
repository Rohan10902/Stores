# core/controllers/__init__.py
import sys
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import QObject, Signal, Slot, Property, QThreadPool

from core.utils.worker import AsyncRunner
from core.utils.logger import get_logger
from core.controllers.health_controller import HealthController
from core.controllers.repair_controller import RepairController
from core.controllers.validate_controller import ValidateController
from core.controllers.creator_controller import CreatorController
from core.controllers.review_controller import ReviewController

logger = get_logger("MainBackendController")


class MainBackendController(QObject):
    """
    Unified Backend Controller exposed to QML context as 'backend'.
    Delegates commands to sub-controllers while presenting a backward-compatible interface.
    """
    messageChanged = Signal()
    toastSignal = Signal(str, str, str)

    # Signal proxies mapped to sub-controllers
    creatorReady = Signal(str)
    creatorLoaded = Signal(str)
    creatorExported = Signal(str)
    healthReady = Signal(str)
    tableReady = Signal(str)
    statsReady = Signal(str)
    repairReady = Signal(str)
    mappingReady = Signal(str)
    validationReady = Signal(str)
    detailReady = Signal(str)
    singleReviewReady = Signal(str)

    def __init__(self, threadpool: QThreadPool = None):
        super().__init__()
        self._message = "Ready"
        self.async_runner = AsyncRunner(threadpool or QThreadPool.globalInstance(), self.fail)

        # Domain Controllers
        self.health = HealthController(self.async_runner, self.notify, self.say)
        self.repair_ctrl = RepairController(self.async_runner, self.notify, self.fail)
        self.validate_ctrl = ValidateController(self.async_runner, self.notify, self.fail)
        self.creator = CreatorController(self.async_runner, self.notify, self.say)
        self.review = ReviewController(self.async_runner, self.notify)

        # Signal Relays
        self.health.healthReady.connect(self.healthReady.emit)
        self.health.tableReady.connect(self.tableReady.emit)
        self.health.statsReady.connect(self.statsReady.emit)

        self.repair_ctrl.repairReady.connect(self.repairReady.emit)

        self.validate_ctrl.mappingReady.connect(self.mappingReady.emit)
        self.validate_ctrl.validationReady.connect(self.validationReady.emit)
        self.validate_ctrl.detailReady.connect(self.detailReady.emit)

        self.creator.creatorReady.connect(self.creatorReady.emit)
        self.creator.creatorLoaded.connect(self.creatorLoaded.emit)
        self.creator.creatorExported.connect(self.creatorExported.emit)

        self.review.singleReviewReady.connect(self.singleReviewReady.emit)

    @Property(str, notify=messageChanged)
    def message(self):
        return self._message

    @message.setter
    def message(self, val):
        self._message = str(val)
        self.messageChanged.emit()

    @Slot(str)
    def say(self, text):
        self.message = str(text)

    @Slot(str, str, str)
    def notify(self, title, msg, ntype="info"):
        self.toastSignal.emit(str(title), str(msg), str(ntype))

    @Slot(object)
    def fail(self, e):
        err_msg = str(e) if str(e) else "An unexpected error occurred during processing."
        self.message = f"Error: {err_msg}"
        self.notify("Operation Alert", err_msg, "error")
        logger.error(f"Backend caught error: {err_msg}")
        sys.stdout.flush()

    @Slot(result=str)
    def clipboardText(self):
        try:
            return QApplication.clipboard().text() or ""
        except Exception:
            return ""

    # Slot Forwarders
    @Slot(str, str)
    def exportCreator(self, r, d): self.creator.export_creator_file(r, d)
    @Slot(str)
    def validateCreator(self, r): self.creator.validate_creator(r)
    @Slot(str)
    def loadCreatorFile(self, p): self.creator.load_creator_file(p)

    @Slot(str)
    def loadData(self, p): self.health.load_data(p)
    @Slot(str)
    def exportHealthReport(self, p): self.health.export_health_report(p)
    @Slot(str, str)
    def search(self, q, c): self.health.search(q, c)
    @Slot(str)
    def sql(self, q): self.health.sql(q)
    @Slot(str, str, str)
    def stats(self, c, o, g): self.health.stats(c, o, g)

    @Slot(str)
    def inspectRepair(self, p): self.repair_ctrl.inspect_repair(p)
    @Slot()
    def undoRepairAction(self): self.repair_ctrl.undo_repair_action()
    @Slot(int)
    def joinRepairRows(self, i): self.repair_ctrl.join_repair_rows(i)
    @Slot(int, int, str, bool)
    def applyRepairMapping(self, i, c, t, r): self.repair_ctrl.apply_repair_mapping(i, c, t, r)
    @Slot(int, int)
    def keepRepairUnresolved(self, i, c): self.repair_ctrl.keep_repair_unresolved(i, c)
    @Slot(int)
    def keepRepairIssue(self, i): self.repair_ctrl.keep_repair_issue(i)
    @Slot(int, str)
    def createRepairRecord(self, i, m): self.repair_ctrl.create_repair_record(i, m)
    @Slot(int)
    def deleteRepairRecord(self, r): self.repair_ctrl.delete_repair_record(r)
    @Slot(str, str)
    def repair(self, s, d): self.repair_ctrl.repair(s, d)

    @Slot(str)
    def loadMaster(self, p): self.validate_ctrl.load_master(p)
    @Slot(str)
    def loadUpload(self, p): self.validate_ctrl.load_upload(p)
    @Slot()
    def detect(self): self.validate_ctrl.detect()
    @Slot(str)
    def validate(self, k): self.validate_ctrl.validate(k)
    @Slot(int, bool)
    def detail(self, i, d): self.validate_ctrl.detail(i, d)

    @Slot(str)
    def reviewSingleFile(self, p): self.review.review_single_file(p)
    @Slot(str, str)
    def exportSingleReview(self, s, d): self.review.export_single_review(s, d)
