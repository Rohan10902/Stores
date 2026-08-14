from PySide6.QtCore import QObject, Property, Signal

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

    creatorLoaded = Signal(str)
    creatorReady = Signal(str)
    creatorExported = Signal()
    builderExported = Signal()

    def __init__(self, threadpool=None, parent=None):
        super().__init__(parent)
        self.async_runner = AsyncRunner(threadpool, parent=self)

        self.notify = lambda title, message, level="info": self.notifySignal.emit(
            str(title), str(message), str(level)
        )
        self.say = lambda message: self.saySignal.emit(str(message))
        self.fail = lambda title, message: self.notifySignal.emit(
            str(title), str(message), "error"
        )

        self._validate = ValidateController(self.async_runner, self.notify, self.fail, parent=self)
        self._repair = RepairController(self.async_runner, self.notify, self.fail, parent=self)
        self._review = ReviewController(self.async_runner, self.notify, parent=self)
        self._creator = CreatorController(self.async_runner, self.notify, self.say, parent=self)
        self._health = HealthController(self.async_runner, self.notify, self.say, parent=self)

        self._creator.creatorLoaded.connect(
            lambda payload: self.creatorLoaded.emit(str(payload))
        )
        self._creator.creatorReady.connect(
            lambda payload: self.creatorReady.emit(str(payload))
        )
        self._creator.creatorExported.connect(
            lambda: self.creatorExported.emit()
        )
        self._creator.builderExported.connect(
            lambda: self.builderExported.emit()
        )

        self._validate.masterPreviewReady.connect(
            lambda payload: self.saySignal.emit("__STORELENS_PREVIEW_MASTER__" + str(payload))
        )
        self._validate.uploadPreviewReady.connect(
            lambda payload: self.saySignal.emit("__STORELENS_PREVIEW_UPLOAD__" + str(payload))
        )

    # These controllers are intentionally exposed as real Qt properties.
    # Plain Python QObject attributes are not a reliable QML object contract;
    # without these properties, calls such as backend.creator.load_creator_file()
    # can resolve as undefined even though the backend itself exists.
    validate = Property(QObject, lambda self: self._validate, constant=True)
    repair = Property(QObject, lambda self: self._repair, constant=True)
    review = Property(QObject, lambda self: self._review, constant=True)
    creator = Property(QObject, lambda self: self._creator, constant=True)
    health = Property(QObject, lambda self: self._health, constant=True)


__all__ = [
    "MainBackendController",
    "ValidateController",
    "RepairController",
    "ReviewController",
    "CreatorController",
    "HealthController",
    "AsyncRunner",
]
