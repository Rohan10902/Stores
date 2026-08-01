# core/worker_manager.py
import logging
import uuid
from typing import Optional
from PySide6.QtCore import QObject, QThread, Signal, Slot

logger = logging.getLogger(__name__)


class BaseWorker(QObject):
    """Base worker class with built-in task tracking."""
    finished = Signal(str, object)  # task_id, result
    failed = Signal(str, Exception)  # task_id, exception

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self.task_id: str = ""
        self._is_cancelled: bool = False

    def cancel(self):
        self._is_cancelled = True

    @property
    def is_cancelled(self) -> bool:
        return self._is_cancelled


class WorkerManager(QObject):
    """
    Guarantees thread-safe single-worker execution.
    Cleans up resources and invalidates stale background results.
    """
    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._current_thread: Optional[QThread] = None
        self._current_worker: Optional[BaseWorker] = None
        self._active_task_id: Optional[str] = None

    @property
    def active_task_id(self) -> Optional[str]:
        return self._active_task_id

    def is_current_task(self, task_id: str) -> bool:
        return self._active_task_id is not None and self._active_task_id == task_id

    def cancel_active_worker(self) -> None:
        """Stops and disconnects any currently executing worker thread."""
        if self._current_worker:
            logger.info(f"Canceling active worker task ID: {self._active_task_id}")
            self._current_worker.cancel()
            # Block signals immediately so pending emissions are ignored
            self._current_worker.blockSignals(True)

        if self._current_thread and self._current_thread.isRunning():
            self._current_thread.quit()
            if not self._current_thread.wait(1500):
                logger.warning("Thread did not quit gracefully. Terminating.")
                self._current_thread.terminate()
                self._current_thread.wait()

        self._cleanup_references()

    def start_worker(self, worker: BaseWorker) -> str:
        """
        Cancels any existing worker, wraps the new worker in a QThread,
        assigns a unique task_id, and manages resource cleanup.
        """
        self.cancel_active_worker()

        task_id = str(uuid.uuid4())
        worker.task_id = task_id
        self._active_task_id = task_id

        thread = QThread()
        worker.moveToThread(thread)

        # Wire thread lifecycle and garbage collection
        thread.started.connect(worker.run if hasattr(worker, 'run') else lambda: None)
        worker.finished.connect(lambda tid, _: self._on_worker_done(thread))
        worker.failed.connect(lambda tid, _: self._on_worker_done(thread))

        thread.finished.connect(thread.deleteLater)
        worker.destroyed.connect(lambda: logger.debug("Worker object destroyed."))

        self._current_worker = worker
        self._current_thread = thread

        thread.start()
        return task_id

    @Slot()
    def _on_worker_done(self, thread: QThread) -> None:
        if thread and thread.isRunning():
            thread.quit()

    def _cleanup_references(self) -> None:
        if self._current_worker:
            self._current_worker.deleteLater()
        self._current_worker = None
        self._current_thread = None
        self._active_task_id = None
