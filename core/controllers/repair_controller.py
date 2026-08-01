# core/controllers/repair_controller.py
from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot

from core.exceptions import RepairFailedException
from core.utils.logger import get_logger

logger = get_logger("RepairController")


class RepairController(QObject):
    previewUpdated = Signal(list, list)  # headers, preview_rows
    repairCompleted = Signal(int)        # repaired_count
    repairFailed = Signal(str)

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._raw_rows: List[List[Any]] = []
        self._headers: List[str] = []

    @Slot(list, list)
    def load_dataset(self, headers: List[str], rows: List[List[Any]]) -> None:
        """Sets internal working data for repair evaluation."""
        self._headers = list(headers)
        self._raw_rows = list(rows)
        logger.info(f"Loaded dataset for repair: {len(self._raw_rows)} rows.")
        self.generate_preview()

    @Slot()
    def generate_preview(self) -> None:
        """Regenerates preview panel data without blocking UI rendering."""
        preview_sample = self._raw_rows[:50]  # Limit preview window for speed
        self.previewUpdated.emit(self._headers, preview_sample)

    @Slot(result=int)
    def apply_auto_repair(self) -> int:
        """Executes automated cleaning and emits updated model signals."""
        try:
            if not self._raw_rows:
                raise RepairFailedException("No data available to repair.")

            repaired_count = 0
            cleaned_rows = []

            for row in self._raw_rows:
                cleaned_row = []
                row_changed = False
                for cell in row:
                    val = str(cell).strip()
                    if val != str(cell):
                        row_changed = True
                    cleaned_row.append(val)
                
                if row_changed:
                    repaired_count += 1
                cleaned_rows.append(cleaned_row)

            self._raw_rows = cleaned_rows
            logger.info(f"Auto-repair complete. Repaired {repaired_count} records.")
            
            self.generate_preview()
            self.repairCompleted.emit(repaired_count)
            return repaired_count

        except Exception as e:
            logger.error(f"Auto-repair failed: {e}", exc_info=True)
            self.repairFailed.emit(str(e))
            return 0
