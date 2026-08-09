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

class MainBackendController(QObject):
    notifySignal = Signal(str, str, str)
    saySignal = Signal(str)

    def __init__(self, threadpool=None, parent=None):
        super().__init__(parent)
        self.async_runner = AsyncRunner(threadpool)
        
        self.notify = lambda title, msg, level="info": self.notifySignal.emit(title, msg, level)
        self.say = lambda msg: self.saySignal.emit(msg)
        self.fail = lambda title, msg: self.notifySignal.emit(title, msg, "error")

        # Guaranteed uniform construction utilizing the extracted AsyncRunner
        self.repair = RepairController(self.async_runner, self.notify, self.fail, parent=self)
        self.validate = ValidateController(self.async_runner, self.notify, self.fail, parent=self)
        self.health = HealthController(self.async_runner, self.notify, self.say, parent=self)
        self.creator = CreatorController(self.async_runner, self.notify, self.say, parent=self)
        self.review = ReviewController(self.async_runner, self.notify, parent=self)
