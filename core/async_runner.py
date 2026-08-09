from PySide6.QtCore import QObject


class AsyncRunner(QObject):
    """
    Lightweight async runner wrapper.

    This class keeps the controller API consistent while allowing
    a QThreadPool to be supplied by the application.
    """

    def __init__(self, threadpool=None, parent=None):
        super().__init__(parent)
        self.threadpool = threadpool

    def run(self, fn, *args, **kwargs):
        """
        Execute a callable.

        This fallback implementation executes synchronously.
        A production async implementation can replace this later
        without changing the controller construction API.
        """
        return fn(*args, **kwargs)
