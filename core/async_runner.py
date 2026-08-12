from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal, Slot


class _WorkerSignals(QObject):
    finished = Signal(object)
    failed = Signal(object)


class _Worker(QRunnable):
    def __init__(self, fn, args, kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = _WorkerSignals()

    def run(self):
        try:
            result = self.fn(*self.args, **self.kwargs)
        except Exception as exc:
            self.signals.failed.emit(exc)
            return

        self.signals.finished.emit(result)


class _RunnerBridge(QObject):
    """Main-thread callback bridge for worker completion signals."""

    def __init__(self, on_success, on_error, cleanup, parent=None):
        super().__init__(parent)
        self.on_success = on_success
        self.on_error = on_error
        self.cleanup = cleanup

    @Slot(object)
    def handle_success(self, result):
        try:
            if self.on_success is not None:
                self.on_success(result)
        finally:
            self.cleanup(self)

    @Slot(object)
    def handle_error(self, error):
        try:
            if self.on_error is not None:
                self.on_error(error)
        finally:
            self.cleanup(self)


class AsyncRunner(QObject):
    """Execute controller tasks off the Qt GUI thread.

    Controllers use the contract::
        run(task, on_success, on_error)

    The task executes on a QThreadPool worker. Completion and error callbacks
    are deliberately routed through a QObject living on the AsyncRunner's
    thread so controller state changes and Qt signals return to the GUI thread.
    """

    def __init__(self, threadpool=None, parent=None):
        super().__init__(parent)
        self.threadpool = threadpool or QThreadPool.globalInstance()
        self._bridges = set()

    def _cleanup_bridge(self, bridge):
        self._bridges.discard(bridge)
        bridge.deleteLater()

    def run(self, fn, on_success=None, on_error=None, *args, **kwargs):
        bridge = _RunnerBridge(
            on_success,
            on_error,
            self._cleanup_bridge,
            parent=self,
        )
        self._bridges.add(bridge)

        worker = _Worker(fn, args, kwargs)
        worker.signals.finished.connect(bridge.handle_success)
        worker.signals.failed.connect(bridge.handle_error)

        self.threadpool.start(worker)
        return worker
