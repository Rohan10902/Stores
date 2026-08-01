# core/models/store_table_model.py
import pandas as pd
from PySide6.QtCore import Qt, QAbstractTableModel, QModelIndex
from core.utils.logger import get_logger

logger = get_logger("StoreTableModel")


class StoreTableModel(QAbstractTableModel):
    """
    High-performance QAbstractTableModel adapter for Pandas DataFrames,
    optimized for smooth virtualization and rendering inside QML TableViews.
    """
    def __init__(self, df: pd.DataFrame = None, parent=None):
        super().__init__(parent)
        self._df = df if df is not None else pd.DataFrame()

    def setDataFrame(self, df: pd.DataFrame):
        """
        Safely replaces the underlying DataFrame and signals the view to update.
        """
        self.beginResetModel()
        self._df = df if df is not None else pd.DataFrame()
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._df)

    def columnCount(self, parent=QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._df.columns)

    def data(self, index: QModelIndex, role=Qt.DisplayRole):
        """
        Fast O(1) cell data lookup using pandas .iat[] to prevent UI lag.
        """
        if not index.isValid():
            return None

        if role == Qt.DisplayRole or role == Qt.EditRole:
            try:
                val = self._df.iat[index.row(), index.column()]
                if pd.isna(val):
                    return ""
                return str(val)
            except (IndexError, TypeError, ValueError) as err:
                logger.error(f"Error accessing cell at row {index.row()}, col {index.column()}: {err}")
                return ""
        return None

    def headerData(self, section: int, orientation: Qt.Orientation, role=Qt.DisplayRole):
        """
        Provides column and row header data for the table view.
        """
        if role != Qt.DisplayRole:
            return None

        if orientation == Qt.Orientation.Horizontal:
            if 0 <= section < len(self._df.columns):
                return str(self._df.columns[section])
        elif orientation == Qt.Orientation.Vertical:
            return str(section + 1)
        return None

    def roleNames(self) -> dict:
        """
        Maps column names to custom QML roles for flexible view binding.
        """
        roles = super().roleNames()
        for i, col in enumerate(self._df.columns):
            roles[Qt.UserRole + i + 1] = str(col).encode('utf-8')
        return roles
