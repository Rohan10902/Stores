# core/controllers/import_controller.py
import logging
from typing import List, Any
from PySide6.QtCore import QObject, Signal, Slot

from core.worker_manager import WorkerManager, BaseWorker
from core.models.store_table_model import StoreTableModel

logger = logging.getLogger(__name__)


class CSVImportWorker(BaseWorker):
    def __init__(self, file_path: str, parent=None):
        super().__init__(parent)
        self.file_path = file_path

    def run(self):
        try:
            # Simulated heavy CSV parse/repair logic
            import time
            time.sleep(0.5)
            
            if self.is_cancelled:
                return

            # Dummy parsed output
            headers = ["Store ID", "Store Name", "Status"]
            rows = [
                ["101", "Vadodara Branch", "Active"],
                ["102", "Eva Mall Kiosk", "Pending"]
            ]
            self.finished.emit(self.task_id, (headers, rows))
        except Exception as e:
            self.failed.emit(self.task_id, e)


class ImportController(QObject):
    importStarted = Signal()
    importCompleted = Signal()
    importFailed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.worker_manager = WorkerManager(self)
        self.table_model = StoreTableModel(self)

    @Slot(str)
    def start_csv_import(self, file_path: str) -> None:
        """Prepares state, clears old data, and launches worker safely."""
        logger.info(f"Initiating new import for: {file_path}")
        
        # 1. Reset state completely to prevent stale QML access
        self.table_model.clear()
        self.importStarted.emit()

        # 2. Spawn worker
        worker = CSVImportWorker(file_path)
        worker.finished.connect(self._on_import_finished)
        worker.failed.connect(self._on_import_failed)

        self.worker_manager.start_worker(worker)

    @Slot(str, object)
    def _on_import_finished(self, task_id: str, result: Any) -> None:
        # Ignore stale background worker results
        if not self.worker_manager.is_current_task(task_id):
            logger.warning(f"Ignored stale import completion signal for task {task_id}")
            return

        headers, rows = result
        self.table_model.set_data(headers, rows)
        self.importCompleted.emit()
        logger.info("Import completed successfully and UI updated.")

    @Slot(str, Exception)
    def _on_import_failed(self, task_id: str, error: Exception) -> None:
        if not self.worker_manager.is_current_task(task_id):
            return

        logger.error(f"Import task {task_id} failed: {error}")
        self.importFailed.emit(str(error))
