from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal


class _WorkerSignals(QObject):
    finished = Signal(object)
    failed = Signal(object)


class _Worker(QRunnable):
    def __init__(self, fn, args, kwargs, on_success, on_error):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.on_success = on_success
        self.on_error = on_error
        self.signals = _WorkerSignals()

    def run(self):
        try:
            result = self.fn(*self.args, **self.kwargs)
        except Exception as exc:
            self.signals.failed.emit(exc)
            return

        self.signals.finished.emit(result)


class AsyncRunner(QObject):
    """Execute controller tasks off the Qt GUI thread.

    Controllers use the contract::
        run(task, on_success, on_error)

    A supplied QThreadPool is reused when available; otherwise Qt's global
    thread pool is used. Completion/error callbacks are connected through
    Qt signals so controller signals can safely cross back to the GUI thread.
    """

    def __init__(self, threadpool=None, parent=None):
        super().__init__(parent)
        self.threadpool = threadpool or QThreadPool.globalInstance()

    def run(self, fn, on_success=None, on_error=None, *args, **kwargs):
        worker = _Worker(
            fn,
            args,
            kwargs,
            on_success,
            on_error,
        )

        if on_success is not None:
            worker.signals.finished.connect(on_success)

        if on_error is not None:
            worker.signals.failed.connect(on_error)

        self.threadpool.start(worker)
        return worker
