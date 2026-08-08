from PySide6.QtCore import QObject, Property, Signal, Slot
from .validate_controller import ValidateController
from .repair_controller import RepairController
from .review_controller import ReviewController
from .creator_controller import CreatorController
from .health_controller import HealthController

class MainBackendController(QObject):
    # Global Signals
    notifySignal = Signal(str, str) # e.g., (type, message)
    saySignal = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        # Initialize business logic controllers
        self._validate = ValidateController(self)
        self._repair = RepairController(self)
        self._review = ReviewController(self)
        self._creator = CreatorController(self)
        self._health = HealthController(self)
        # Note: Explorer may be separate or nested here depending on your app setup

    # --- QML EXPOSED PROPERTIES ---
    
    @Property(QObject, constant=True)
    def validate(self):
        return self._validate

    @Property(QObject, constant=True)
    def repair(self):
        return self._repair

    @Property(QObject, constant=True)
    def review(self):
        return self._review

    @Property(QObject, constant=True)
    def creator(self):
        return self._creator

    @Property(QObject, constant=True)
    def health(self):
        return self._health
