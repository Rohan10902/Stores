from PySide6.QtCore import QObject, Signal

from .validate_controller import ValidateController
from .repair_controller import RepairController
from .review_controller import ReviewController
from .creator_controller import CreatorController
from .health_controller import HealthController

try:
    from core.async_runner import AsyncRunner
except ImportError:
    class AsyncRunner:
        def __init__(self, threadpool=None):
            self.threadpool = threadpool
        def run(self, fn, on_success=None, on_error=None):
            try:
                result = fn()
                if on_success:
                    on_success(result)
                return result
            except Exception as exc:
                if on_error:
                    on_error(exc)
                else:
                    raise


class MainBackendController(QObject):
    notifySignal = Signal(str, str, str)
    saySignal = Signal(str)

    # Public bridge signals used by QML pages.  Keep these at the top-level
    # backend so page lifetime/StackLayout changes cannot disconnect a nested
    # controller while an async import is completing.
    creatorLoaded = Signal(str)
    creatorReady = Signal(str)
    creatorExported = Signal()
    builderExported = Signal()

    def __init__(self, threadpool=None, parent=None):
        super().__init__(parent)
        self.async_runner = AsyncRunner(threadpool)

        self.notify = lambda title, message, level="info": self.notifySignal.emit(
            str(title), str(message), str(level)
        )
        self.say = lambda message: self.saySignal.emit(str(message))
        self.fail = lambda title, message: self.notifySignal.emit(
            str(title), str(message), "error"
        )

        self.validate = ValidateController(self.async_runner, self.notify, self.fail, parent=self)
        self.repair = RepairController(self.async_runner, self.notify, self.fail, parent=self)
        self.review = ReviewController(self.async_runner, self.notify, parent=self)
        self.creator = CreatorController(self.async_runner, self.notify, self.say, parent=self)
        self.health = HealthController(self.async_runner, self.notify, self.say, parent=self)

        # Explicit forwarding lambdas are intentional.  They keep the bridge
        # alive for the entire application lifetime and normalize payloads at
        # the QML boundary instead of relying on signal-to-signal connection
        # behavior across nested QObject ownership.
        self.creator.creatorLoaded.connect(
            lambda payload: self.creatorLoaded.emit(str(payload))
        )
        self.creator.creatorReady.connect(
            lambda payload: self.creatorReady.emit(str(payload))
        )
        self.creator.creatorExported.connect(
            lambda: self.creatorExported.emit()
        )
        self.creator.builderExported.connect(
            lambda: self.builderExported.emit()
        )

        self.validate.masterPreviewReady.connect(
            lambda payload: self.saySignal.emit("__STORELENS_PREVIEW_MASTER__" + str(payload))
        )
        self.validate.uploadPreviewReady.connect(
            lambda payload: self.saySignal.emit("__STORELENS_PREVIEW_UPLOAD__" + str(payload))
        )


__all__ = [
    "MainBackendController",
    "ValidateController",
    "RepairController",
    "ReviewController",
    "CreatorController",
    "HealthController",
    "AsyncRunner",
]
