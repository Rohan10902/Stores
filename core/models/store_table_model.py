from __future__ import annotations

import json

from PySide6.QtCore import QAbstractTableModel, QModelIndex, Qt, Signal, Slot

from core.common import STORE_FIELDS


class StoreTableModel(QAbstractTableModel):
    """Qt model for the complete Store Builder dataset.

    The model owns the records; QML TableView owns only the visible delegates.
    This is the scalable boundary for large datasets.
    """

    valueRole = Qt.UserRole + 1
    selectedRole = Qt.UserRole + 2
    rowNumberRole = Qt.UserRole + 3

    modelChangedExternally = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._headers = list(STORE_FIELDS)
        self._rows: list[list[str]] = []
        self._selected: list[bool] = []

    def roleNames(self):
        return {
            self.valueRole: b"value",
            self.selectedRole: b"selected",
            self.rowNumberRole: b"rowNumber",
        }

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._rows)

    def columnCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._headers) + 1

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role not in (Qt.DisplayRole, self.valueRole):
            return None
        if orientation == Qt.Horizontal:
            if section == 0:
                return "USE / ROW"
            if 0 < section <= len(self._headers):
                return self._headers[section - 1]
        if orientation == Qt.Vertical:
            return section + 1
        return None

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()
        column = index.column()
        if row < 0 or row >= len(self._rows):
            return None
        if role in (Qt.DisplayRole, Qt.EditRole, self.valueRole):
            if column == 0:
                return "1" if self._selected[row] else "0"
            return self._rows[row][column - 1]
        if role == self.selectedRole:
            return self._selected[row]
        if role == self.rowNumberRole:
            return row + 1
        return None

    def flags(self, index):
        if not index.isValid():
            return Qt.NoItemFlags
        flags = Qt.ItemIsEnabled | Qt.ItemIsSelectable
        if index.column() > 0:
            flags |= Qt.ItemIsEditable
        return flags

    def setData(self, index, value, role=Qt.EditRole):
        if not index.isValid():
            return False
        row = index.row()
        column = index.column()
        if row < 0 or row >= len(self._rows):
            return False
        if column == 0:
            selected = bool(value)
            if selected == self._selected[row]:
                return True
            self._selected[row] = selected
        elif role in (Qt.EditRole, self.valueRole):
            target = column - 1
            if target < 0 or target >= len(self._headers):
                return False
            self._rows[row][target] = "" if value is None else str(value)
        else:
            return False
        self.dataChanged.emit(index, index, [Qt.DisplayRole, Qt.EditRole, self.valueRole, self.selectedRole])
        self.modelChangedExternally.emit()
        return True

    @Slot(str)
    def setRowsJson(self, payload):
        rows = json.loads(str(payload or "[]"))
        if not isinstance(rows, list):
            raise ValueError("Store Builder rows must be a JSON array.")
        normalized = []
        for row in rows:
            values = list(row) if isinstance(row, (list, tuple)) else []
            values = ["" if value is None else str(value) for value in values[:len(self._headers)]]
            values.extend([""] * (len(self._headers) - len(values)))
            normalized.append(values)
        self.beginResetModel()
        self._rows = normalized
        self._selected = [True] * len(normalized)
        self.endResetModel()
        self.modelChangedExternally.emit()

    @Slot(int, str)
    def setCell(self, row, column, value):
        self.setData(self.index(int(row), int(column) + 1), value, Qt.EditRole)

    @Slot(int, bool)
    def setRowSelected(self, row, selected):
        self.setData(self.index(int(row), 0), bool(selected), self.selectedRole)

    @Slot(bool)
    def selectAll(self, selected):
        if not self._rows:
            return
        self._selected = [bool(selected)] * len(self._rows)
        self.dataChanged.emit(
            self.index(0, 0),
            self.index(len(self._rows) - 1, 0),
            [self.selectedRole, self.valueRole],
        )
        self.modelChangedExternally.emit()

    @Slot()
    def reset(self):
        self.beginResetModel()
        self._rows = []
        self._selected = []
        self.endResetModel()
        self.modelChangedExternally.emit()

    @Slot(result=str)
    def rowsJson(self):
        return json.dumps(self._rows, ensure_ascii=False)

    @Slot(result=str)
    def selectedRowsJson(self):
        return json.dumps(
            [row for row, selected in zip(self._rows, self._selected) if selected],
            ensure_ascii=False,
        )

    @Slot(result=int)
    def totalRows(self):
        return len(self._rows)

    @Slot(result=int)
    def selectedRowCount(self):
        return sum(1 for selected in self._selected if selected)
