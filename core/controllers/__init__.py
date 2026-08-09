from PySide6.QtCore import QObject, Signal
from .validate_controller import ValidateController
from .repair_controller import RepairController
from .review_controller import ReviewController
from .creator_controller import CreatorController
from .health_controller import HealthController

class MainBackendController(QObject):
    notifySignal = Signal(str, str, str)
    saySignal = Signal(str)

    def __init__(self, async_runner, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        
        # Consistent callback references for child controllers
        self.notify = lambda title, msg, level="info": self.notifySignal.emit(title, msg, level)
        self.say = lambda msg: self.saySignal.emit(msg)
        self.fail = lambda title, msg: self.notifySignal.emit(title, msg, "error")

        # Properly construct all children guaranteeing identical signature architecture
        self.repair = RepairController(self.async_runner, self.notify, self.fail, parent=self)
        self.validate = ValidateController(self.async_runner, self.notify, self.fail, parent=self)
        self.health = HealthController(self.async_runner, self.notify, self.say, parent=self)
        self.creator = CreatorController(self.async_runner, self.notify, self.say, parent=self)
        self.review = ReviewController(self.async_runner, self.notify, parent=self)
