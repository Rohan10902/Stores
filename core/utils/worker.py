# core/utils/worker.py
import uuid
from PySide6.QtCore import QObject, Signal, Slot, QRunnable, Qt, QThreadPool
from core.utils.logger import get_logger

logger = get_logger("Worker")


class WorkerSignals(QObject):
    finished = Signal(object)
    error = Signal(object)


class Worker(QRunnable):
    def __init__(self, fn, *args, **kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()

    @Slot()
    def run(self):
        try:
            result = self.fn(*self.args, **self.kwargs)
            self.signals.finished.emit(result)
        except Exception as e:
            self.signals.error.emit(e)


class AsyncRunner:
    """Manages thread executions and discards stale result callbacks using category tokens."""

    def __init__(self, threadpool: QThreadPool, fail_callback):
        self.threadpool = threadpool
        self.fail_callback = fail_callback
        self._active_tasks = {}

    def run_async(self, category: str, func, callback_success, *args):
        task_id = str(uuid.uuid4())
        self._active_tasks[category] = task_id

        def task_wrapper():
            res = func(*args)
            return task_id, res

        def on_finished(payload):
            tid, result = payload
            if self._active_tasks.get(category) == tid:
                callback_success(result)
            else:
                logger.info(f"Discarded stale result for category '{category}' (Task ID: {tid})")

        def on_error(err):
            if self._active_tasks.get(category) == task_id:
                self.fail_callback(err)

        worker = Worker(task_wrapper)
        worker.signals.finished.connect(on_finished, Qt.QueuedConnection)
        worker.signals.error.connect(on_error, Qt.QueuedConnection)
        self.threadpool.start(worker)
