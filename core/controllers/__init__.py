# core/controllers/__init__.py
from PySide6.QtCore import QObject, Slot, Signal

from core.utils.logger import get_logger
from core.async_runner import AsyncRunner
from core.controllers.repair_controller import RepairController
from core.controllers.validate_controller import ValidateController
from core.controllers.health_controller import HealthController
from core.controllers.creator_controller import CreatorController
from core.controllers.review_controller import ReviewController

logger = get_logger("MainBackendController")


class MainBackendController(QObject):
    notifySignal = Signal(str, str, str)  # title, message, type
    saySignal = Signal(str)

    def __init__(self, threadpool=None):
        super().__init__()
        self.async_runner = AsyncRunner(threadpool)
        
        # Instantiate child controllers
        self.repair = RepairController(self.async_runner, self.notify, self.fail)
        self.validate = ValidateController(self.async_runner, self.notify, self.fail)
        self.health = HealthController(self.async_runner, self.notify, self.say)
        self.creator = CreatorController(self.async_runner, self.notify, self.say)
        self.review = ReviewController(self.async_runner, self.notify)

    @Slot(str, str, str)
    def notify(self, title, message, level="info"):
        try:
            self.notifySignal.emit(title, message, level)
        except (AttributeError, TypeError) as err:
            logger.error(f"Failed to emit notification signal: {err}")

    @Slot(str)
    def say(self, message):
        try:
            self.saySignal.emit(message)
        except (AttributeError, TypeError) as err:
            logger.error(f"Failed to emit say signal: {err}")

    @Slot(object)
    def fail(self, error):
        try:
            err_msg = str(error) if error else "An unknown error occurred."
            logger.error(f"Controller error dispatched: {err_msg}")
            self.notifySignal.emit("Operation Failed", err_msg, "error")
        except (AttributeError, TypeError) as err:
            logger.error(f"Failed to handle failure dispatch: {err}")

    def handle_worker_error(self, err_type, err_value):
        try:
            logger.error(f"Background task failed: {err_type} - {err_value}")
            self.fail(str(err_value))
        except (AttributeError, TypeError) as cb_err:
            logger.error(f"Error executing worker error handler: {cb_err}")
