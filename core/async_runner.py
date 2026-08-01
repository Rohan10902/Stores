# core/async_runner.py
from PySide6.QtCore import QThreadPool
from core.utils.worker import Worker
from core.utils.logger import get_logger

logger = get_logger("AsyncRunner")


class AsyncRunner:
    """
    Manages background execution threads safely using QThreadPool and Worker.
    """
    def __init__(self, threadpool: QThreadPool = None):
        self.threadpool = threadpool or QThreadPool.globalInstance()

    def run_async(self, name: str, task_fn, callback_fn=None, error_callback_fn=None):
        worker = Worker(task_fn)
        
        if callback_fn:
            worker.signals.finished.connect(callback_fn)
            
        if error_callback_fn:
            worker.signals.error.connect(error_callback_fn)
        else:
            worker.signals.error.connect(lambda err_tuple: logger.error(f"Task '{name}' failed: {err_tuple[1]}"))
            
        self.threadpool.start(worker)
