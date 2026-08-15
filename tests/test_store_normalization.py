import json

from core.common import STORE_FIELDS, normalize_store_row, read_table
from core.controllers.creator_controller import CreatorController
from core.file_creator import creator_validate, export_creator


class ImmediateRunner:
    def run(self, task, on_success, on_error):
        try:
            on_success(task())
        except Exception as exc:
            on_error(exc)


def valid_row(**overrides):
    row = {field: "" for field in STORE_FIELDS}
    row.update({
        "Store Name": "Test Store",
        "SID": "S100",
        "Nielsen Store Code": "12",
        "Active / Inactive": "Active",
        "Is Census": "Yes",
        "Is Exceptions": "No",
    })
    row.update(overrides)
    return row


def test_backend_normalizes_binary_store_fields_to_zero_or_one():
    row = normalize_store_row(valid_row(), nielsen_width=4)
    assert row["Active / Inactive"] == "1"
    assert row["Is Census"] == "1"
    assert row["Is Exceptions"] == "0"
    assert row["Nielsen Store Code"] == "0012"


def test_store_builder_reports_empty_identity_and_required_flags():
    row = valid_row(
        SID="",
        **{
            "Nielsen Store Code": "",
            "Active / Inactive": "",
            "Is Census": "",
            "Is Exceptions": "",
        },
    )
    findings = creator_validate([row])
    fields = {item["field"] for item in findings}
    assert {"SID", "Nielsen Store Code", "Active / Inactive", "Is Census", "Is Exceptions"} <= fields


def test_creator_rejects_non_binary_values():
    row = valid_row(**{"Is Census": "maybe"})
    findings = creator_validate([row])
    assert any(item["field"] == "Is Census" and "1 or 0" in item["message"] for item in findings)


def test_creator_export_writes_canonical_zero_one_values_and_infers_nielsen_padding_width(tmp_path):
    destination = tmp_path / "normalized.csv"
    rows = [
        valid_row(**{"Nielsen Store Code": "1", "Active / Inactive": "Inactive", "Is Census": "No", "Is Exceptions": "Yes"}),
        valid_row(**{"SID": "S101", "Nielsen Store Code": "002"}),
    ]
    assert creator_validate(rows) == []
    export_creator(rows, str(destination))
    exported = read_table(str(destination))
    assert exported.iloc[0]["Nielsen Store Code"] == "001"
    assert exported.iloc[1]["Nielsen Store Code"] == "002"
    assert exported.iloc[0]["Active / Inactive"] == "0"
    assert exported.iloc[0]["Is Census"] == "0"
    assert exported.iloc[0]["Is Exceptions"] == "1"


def test_controller_paste_normalizes_flags_and_pads_numeric_nielsen_codes():
    loaded = []
    controller = CreatorController(ImmediateRunner(), None, None)
    controller.creatorLoaded.connect(loaded.append)
    controller.load_creator_text(
        "Store Name\tSID\tNielsen Store Code\tActive / Inactive\tIs Census\tIs Exceptions\n"
        "Alpha\tS1\t12\tActive\tYes\tNo\n"
        "Beta\tS2\t7\tInactive\tNo\tYes\n"
    )
    payload = json.loads(loaded[-1])
    assert payload["rows"][0][2] == "12"
    assert payload["rows"][1][2] == "07"
    assert payload["rows"][0][3:] == ["1", "1", "0"]
    assert payload["rows"][1][3:] == ["0", "0", "1"]
