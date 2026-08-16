"""High-value production gates for data lifecycle, export safety and schema-aware SQL."""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import pandas as pd

from core.common import STORE_FIELDS, normalize_store_dataframe
from core.file_creator import creator_validate, export_creator


def _row(number: int) -> dict[str, str]:
    return {
        "Store Name": f"Stress Store {number}",
        "SID": f"S{number:08d}",
        "Banner": "Stress",
        "Nielsen Store Code": str(number),
        "Trip Received": "2026-01-01",
        "Last Trip": "2026-02-01",
        "Address 1": f"{number} Main Road",
        "Address 2": "",
        "Address 3": "",
        "ZIP": "411001",
        "Active / Inactive": "1" if number % 2 else "0",
        "Is Census": "1" if number % 3 else "0",
        "Is Exceptions": "1" if number % 11 == 0 else "0",
        "Updated By": "production-gate",
    }


def test_large_dataset_model_input_contract_10000_rows():
    rows = [_row(i) for i in range(1, 10_001)]
    frame = pd.DataFrame(rows, columns=STORE_FIELDS)
    normalized = normalize_store_dataframe(frame)
    assert len(normalized) == 10_000
    assert list(normalized.columns) == STORE_FIELDS
    assert normalized.iloc[0]["SID"] == "S00000001"
    assert normalized.iloc[-1]["SID"] == "S00010000"
    assert set(normalized["Active / Inactive"].unique()) <= {"0", "1"}
    assert set(normalized["Is Census"].unique()) <= {"0", "1"}
    assert set(normalized["Is Exceptions"].unique()) <= {"0", "1"}


def test_repeated_dataset_lifecycle_does_not_accumulate_state():
    baseline = _row(1)
    for iteration in range(1, 201):
        current = dict(baseline)
        current["SID"] = f"S{iteration:08d}"
        current["Store Name"] = f"Dataset {iteration}"
        frame = normalize_store_dataframe(pd.DataFrame([current], columns=STORE_FIELDS))
        assert len(frame) == 1
        assert frame.iloc[0]["SID"] == f"S{iteration:08d}"
        assert frame.iloc[0]["Store Name"] == f"Dataset {iteration}"


def test_export_never_mutates_source_file():
    rows = [_row(1), _row(2), _row(3)]
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "source.csv"
        output = root / "export.csv"
        pd.DataFrame(rows, columns=STORE_FIELDS).to_csv(source, index=False)
        before = hashlib.sha256(source.read_bytes()).hexdigest()
        export_creator(rows, str(output))
        after = hashlib.sha256(source.read_bytes()).hexdigest()
        assert before == after
        assert output.exists()
        exported = pd.read_csv(output, dtype=str).fillna("")
        assert len(exported) == 3
        assert list(exported.columns) == STORE_FIELDS
        assert set(exported["Active / Inactive"]) <= {"0", "1"}
        assert set(exported["Is Census"]) <= {"0", "1"}
        assert set(exported["Is Exceptions"]) <= {"0", "1"}


def test_export_is_not_created_on_invalid_store_data():
    invalid = _row(1)
    invalid["SID"] = ""
    assert creator_validate([invalid])


def test_schema_aware_sql_suggestions_have_no_stale_columns():
    frame = pd.DataFrame({"StoreCode": ["S1", "S2"], "StoreName": ["A", "B"], "Region": ["West", "East"]})
    columns = {str(column) for column in frame.columns}
    suggestions = [
        f'SELECT "{column}" FROM data LIMIT 100'
        for column in frame.columns
    ]
    for query in suggestions:
        assert any(f'"{column}"' in query for column in columns)
    assert '"SID"' not in " ".join(suggestions)


def test_store_builder_required_fields_are_explicit():
    row = _row(1)
    for field in ("SID", "Nielsen Store Code", "Active / Inactive", "Is Census", "Is Exceptions"):
        candidate = dict(row)
        candidate[field] = ""
        findings = creator_validate([candidate])
        assert any(item["field"] == field for item in findings), field
