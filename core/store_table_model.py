# core/models/store_table_model.py
import logging
from typing import List, Any, Optional
from PySide6.QtCore import QAbstractTableModel, QModelIndex, Qt, Slot

logger = logging.getLogger(__name__)


class StoreTableModel(QAbstractTableModel):
    """
    Thread-safe, index-guarded TableModel for CSV store data.
    Prevents crash on repeated reloads and model replacements.
    """
    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._headers: List[str] = []
        self._rows: List[List[Any]] = []

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._rows)

    def columnCount(self, parent: QModelIndex = QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._headers)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> Any:
        if not index.isValid():
            return None

        row, col = index.row(), index.column()
        if not (0 <= row < len(self._rows)) or not (0 <= col < len(self._headers)):
            return None

        if role in (Qt.DisplayRole, Qt.EditRole):
            return str(self._rows[row][col])

        return None

    def headerData(self, section: int, orientation: Qt.Orientation, role: int = Qt.DisplayRole) -> Any:
        if role == Qt.DisplayRole and orientation == Qt.Horizontal:
            if 0 <= section < len(self._headers):
                return self._headers[section]
        return None

    @Slot()
    def clear(self) -> None:
        """Completely resets model state and notifies bound QML views."""
        self.beginResetModel()
        self._headers.clear()
        self._rows.clear()
        self.endResetModel()

    def set_data(self, headers: List[str], rows: List[List[Any]]) -> None:
        """Safely replaces data set with proper reset signals."""
        self.beginResetModel()
        self._headers = list(headers)
        self._rows = list(rows)
        self.endResetModel()

    @Slot(int, int, result=str)
    def get_cell_value(self, row: int, col: int) -> str:
        """Safely queried by QML views without throwing index exceptions."""
        if 0 <= row < len(self._rows) and 0 <= col < len(self._headers):
            return str(self._rows[row][col])
        return ""
