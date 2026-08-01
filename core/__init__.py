# core/controllers/__init__.py
import sys
import traceback
from PySide6.QtCore import QObject, Signal, Slot, QRunnable, QThreadPool, Property

# You can import your other controllers here to aggregate them later
# from .health_controller import HealthController
# from .repair_controller import RepairController
# from .creator_controller import CreatorController

class WorkerSignals(QObject):
    """Defines the signals available from a running worker thread."""
    finished = Signal(object)
    error = Signal(str, str) # title, details

class SafeWorker(QRunnable):
    """
    A worker thread that wraps execution in a try-catch block.
    Guarantees the main thread will never crash from background exceptions.
    """
    def __init__(self, fn, *args, **kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()

    @Slot()
    def run(self):
        try:
            # Execute the potentially dangerous background task
            result = self.fn(*self.args, **self.kwargs)
            self.signals.finished.emit(result)
        except Exception as e:
            # Trap the error and extract the traceback
            error_msg = str(e)
            trace = traceback.format_exc()
            self.signals.error.emit(error_msg, trace)

class MainBackendController(QObject):
    """
    The main bridge between QML and Python. 
    Handles task routing, global states, and safe error propagation.
    """
    # Signals to communicate with QML
    errorOccurred = Signal(str, str)
    statusChanged = Signal(str)

    def __init__(self, threadpool=None, parent=None):
        super().__init__(parent)
        self.threadpool = threadpool or QThreadPool.globalInstance()
        self._current_status = "System Ready"
        
        # Initialize your sub-controllers here if needed
        # self.health = HealthController()
        # self.repair = RepairController()

    @Property(str, notify=statusChanged)
    def currentStatus(self):
        return self._current_status

    def setStatus(self, status):
        self._current_status = status
        self.statusChanged.emit(self._current_status)

    @Slot(str)
    def loadDataSafely(self, filepath):
        """Example of triggering a safe background task from QML"""
        self.setStatus(f"Loading {filepath}...")
        
        # Define the heavy operation (simulated here)
        def heavy_operation():
            if not filepath:
                raise ValueError("Filepath provided is empty.")
            # Simulate a crash if a specific string is passed
            if "crash" in filepath:
                raise RuntimeError("Simulated corruption in data parsing.")
            return {"success": True, "data": "Parsed Data..."}

        # Create the safe worker
        worker = SafeWorker(heavy_operation)
        
        # Connect signals to handle success and failure gracefully
        worker.signals.finished.connect(self._on_task_success)
        worker.signals.error.connect(self._on_task_error)
        
        # Dispatch to the hardware-aware threadpool
        self.threadpool.start(worker)

    def _on_task_success(self, result):
        self.setStatus("Ready")
        print(f"Task completed successfully: {result}")

    def _on_task_error(self, error_msg, trace):
        self.setStatus("Error occurred")
        # Emit the error directly to the QML UI for the Toast notification
        self.errorOccurred.emit("Operation Failed", error_msg)
        # Log the detailed trace to the console/file for debugging
        print(f"[BACKGROUND ERROR]: {error_msg}\n{trace}")
