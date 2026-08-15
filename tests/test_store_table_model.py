import json

from PySide6.QtCore import Qt

from core.common import STORE_FIELDS
from core.models.store_table_model import StoreTableModel


def rows():
    return [
        [f"Store {i}", f"S{i}", "Banner", f"N{i}", "2026-01-01", "2026-01-02", "A1", "A2", "A3", "411001", "1", "0", "1", "Tester"]
        for i in range(1, 4)
    ]


def test_model_exposes_canonical_table_dimensions_and_headers():
    model = StoreTableModel()
    model.setRowsJson(json.dumps(rows()))
    assert model.rowCount() == 3
    assert model.columnCount() == 15
    assert model.headerData(0, Qt.Horizontal) == "USE / ROW"
    assert model.headerData(1, Qt.Horizontal) == STORE_FIELDS[0]
    assert model.headerData(14, Qt.Horizontal) == STORE_FIELDS[-1]


def test_model_edits_a_single_cell_without_rebuilding_the_dataset():
    model = StoreTableModel()
    model.setRowsJson(json.dumps(rows()))
    assert model.data(model.index(1, 2), Qt.DisplayRole) == "S2"
    assert model.setData(model.index(1, 2), "S200", Qt.EditRole)
    assert model.data(model.index(1, 2), Qt.DisplayRole) == "S200"
    assert model.totalRows() == 3


def test_model_selection_and_selected_records_are_backend_owned():
    model = StoreTableModel()
    model.setRowsJson(json.dumps(rows()))
    model.setRowSelected(1, False)
    assert model.selectedRowCount() == 2
    records = json.loads(model.selectedRecordsJson())
    assert len(records) == 2
    assert all(set(record) == set(STORE_FIELDS) for record in records)
    assert all(record["SID"] != "S2" for record in records)


def test_model_handles_ten_thousand_rows_without_creating_qml_objects():
    model = StoreTableModel()
    dataset = [
        [
            f"Store {i}",
            f"S{i}",
            "Banner",
            f"N{i}",
            "2026-01-01",
            "2026-01-02",
            "A1",
            "A2",
            "A3",
            "411001",
            "1",
            "0",
            "1",
            "Tester",
        ]
        for i in range(10000)
    ]
    model.setRowsJson(json.dumps(dataset))
    assert model.rowCount() == 10000
    assert model.columnCount() == 15
    assert model.data(model.index(9999, 2), Qt.DisplayRole) == "S9999"
    assert model.data(model.index(9999, 3), Qt.DisplayRole) == "N9999"
