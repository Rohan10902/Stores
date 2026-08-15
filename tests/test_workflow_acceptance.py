import csv
import json
import tempfile
from pathlib import Path

import pandas as pd

from core.common import STORE_FIELDS, read_table
from core.controllers.creator_controller import CreatorController
from core.controllers.repair_controller import RepairController
from core.controllers.review_controller import ReviewController
from core.controllers.validate_controller import ValidateController
from core.csv_repair import CSVRepairTool, robust_csv_parse
from core.explorer import run_sql
from core.file_creator import creator_validate, export_creator, review_dataframe
from core.health import check_dataframe_health, profile, statistic
from core.store_validator import compare, suggest_keys


class ImmediateRunner:
    """Run controller tasks synchronously so controller contracts can be tested deterministically."""

    def run(self, task, on_success, on_error):
        try:
            on_success(task())
        except Exception as exc:
            on_error(exc)


def _store_row(sid, nielsen, name):
    row = {field: "" for field in STORE_FIELDS}
    row.update({
        "Store Name": name, "SID": sid, "Banner": "Test Banner",
        "Nielsen Store Code": nielsen, "Trip Received": "2026-01-10",
        "Last Trip": "2026-02-10", "Address 1": "1 Test Street",
        "Address 2": "", "Address 3": "", "ZIP": "411001",
        "Active / Inactive": "Active", "Is Census": "Yes",
        "Is Exceptions": "No", "Updated By": "StoreLens",
    })
    return row


def _write_csv(path, rows, headers=None):
    headers = headers or list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)


def test_store_builder_import_validate_and_export_preserves_real_values():
    rows = [_store_row("S100", "N100", "Alpha Store"), _store_row("S200", "N200", "Beta Store")]
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "stores.csv"
        output = Path(directory) / "export.csv"
        _write_csv(source, rows)
        dataframe = read_table(str(source))
        assert list(dataframe.columns) == STORE_FIELDS
        assert dataframe.iloc[0]["SID"] == "S100"
        assert dataframe.iloc[0]["Store Name"] == "Alpha Store"
        builder_rows = dataframe.fillna("").to_dict(orient="records")
        assert creator_validate(builder_rows) == []
        export_creator(builder_rows, str(output))
        exported = read_table(str(output))
        assert exported.iloc[1]["SID"] == "S200"
        assert exported.iloc[1]["Store Name"] == "Beta Store"
        assert len(exported) == 2


def test_store_builder_clipboard_style_csv_with_quoted_values_round_trips():
    text = 'Store Name,SID,Nielsen Store Code,Address 1\n"North, Store",S1,N1,"12, Main Street"\n'
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "quoted.csv"
        source.write_text(text, encoding="utf-8")
        dataframe = read_table(str(source))
        assert dataframe.iloc[0]["Store Name"] == "North, Store"
        assert dataframe.iloc[0]["Address 1"] == "12, Main Street"


def test_store_builder_controller_import_and_paste_emit_actual_rows():
    runner = ImmediateRunner()
    loaded = []
    controller = CreatorController(runner, None, None)
    controller.creatorLoaded.connect(loaded.append)
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "stores.csv"
        _write_csv(source, [_store_row("S100", "N100", "Alpha Store")])
        controller.load_creator_file(str(source))
    payload = json.loads(loaded[-1])
    assert payload["total"] == 1
    assert payload["rows"][0][1] == "S100"
    assert payload["rows"][0][0] == "Alpha Store"
    controller.load_creator_text('Store Name\tSID\tNielsen Store Code\nBeta Store\tS200\tN200\n')
    payload = json.loads(loaded[-1])
    assert payload["rows"] == [["Beta Store", "S200", "N200"]]


def test_store_builder_controller_validation_and_export_contract():
    runner = ImmediateRunner()
    ready = []
    exported = []
    controller = CreatorController(runner, None, None)
    controller.creatorReady.connect(ready.append)
    controller.builderExported.connect(lambda: exported.append(True))
    row = _store_row("S100", "N100", "Alpha Store")
    controller.validate_creator(json.dumps([row]))
    payload = json.loads(ready[-1])
    assert payload["rows"] == 1
    assert payload["findings"] == []
    with tempfile.TemporaryDirectory() as directory:
        destination = Path(directory) / "builder.csv"
        controller.export_builder_file(json.dumps([[row[field] for field in STORE_FIELDS]]), str(destination), json.dumps(STORE_FIELDS))
        assert exported == [True]
        assert read_table(str(destination)).iloc[0]["SID"] == "S100"


def test_compare_validate_controller_emits_real_master_upload_and_result_values():
    runner = ImmediateRunner()
    validation = []
    controller = ValidateController(runner, None, None)
    controller.validationReady.connect(validation.append)
    with tempfile.TemporaryDirectory() as directory:
        master = Path(directory) / "master.csv"
        upload = Path(directory) / "upload.csv"
        _write_csv(master, [_store_row("S100", "N100", "Alpha Store")])
        _write_csv(upload, [_store_row("S100", "N100", "Alpha Store Updated")])
        controller.load_master(str(master))
        controller.load_upload(str(upload))
        controller.validate(json.dumps(["SID", "Nielsen Store Code"]))
    payload = json.loads(validation[-1])
    assert payload["total"] == 1
    assert payload["rows"][0]["key"] == "s100 | n100"
    assert payload["rows"][0]["status"] == "REVIEW"
    controller.detail(0, False)


def test_repair_controller_emits_actual_inspected_rows():
    runner = ImmediateRunner()
    states = []
    controller = RepairController(runner, None, None)
    controller.repairReady.connect(states.append)
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "repair.csv"
        source.write_text("SID,Store Name,City\nS1,Alpha,Pune\nS2,Beta\nS3,Gamma,Pune,EXTRA\n", encoding="utf-8")
        controller.inspect_repair(str(source))
    payload = json.loads(states[-1])
    assert payload["rows"][0][0] == "S1"
    assert payload["rows"][1][1] == "Beta"
    assert payload["issues"]


def test_repair_controller_map_column_translates_qml_index_to_header_name():
    runner = ImmediateRunner()
    states = []
    controller = RepairController(runner, None, None)
    controller.repairReady.connect(states.append)
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "repair.csv"
        source.write_text("SID,Store Name,City\nS1,Alpha,Pune\nS2,Beta\n", encoding="utf-8")
        controller.inspect_repair(str(source))
        initial = json.loads(states[-1])
        issue_index = initial["issues"][0]["index"]
        controller.map_repair_column(issue_index, 1, 2)
    payload = json.loads(states[-1])
    assert payload["issues"] == []
    assert payload["rows"][1] == ["S2", "", "Beta"]


def test_review_controller_emits_preview_columns_rows_and_malformed_findings():
    runner = ImmediateRunner()
    ready = []
    controller = ReviewController(runner, None)
    controller.singleReviewReady.connect(ready.append)
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "review.csv"
        source.write_text("SID,Store Name\nS1,Alpha\nS2\nS3,Gamma,EXTRA\n", encoding="utf-8")
        controller.review_single_file(str(source))
    payload = json.loads(ready[-1])
    assert payload["totalRecords"] == 3
    assert payload["previewColumns"] == ["SID", "Store Name"]
    assert payload["previewRows"][0] == ["S1", "Alpha"]
    assert payload["previewRows"][1] == ["S2", ""]
    assert payload["attentionCount"] >= 2
    assert any("expected 2 fields, found 3" in item["message"] for item in payload["findings"])


def test_compare_validate_loads_both_datasets_and_returns_actual_detail_values():
    master = pd.DataFrame([
        {"SID": "S100", "Nielsen Store Code": "N100", "Store Name": "Alpha Store", "City": "Pune"},
        {"SID": "S200", "Nielsen Store Code": "N200", "Store Name": "Beta Store", "City": "Mumbai"},
    ])
    uploaded = pd.DataFrame([
        {"SID": "S100", "Nielsen Store Code": "N100", "Store Name": "Alpha Store", "City": "Pune"},
        {"SID": "S200", "Nielsen Store Code": "N200", "Store Name": "Beta Store Updated", "City": "Mumbai"},
    ])
    keys = suggest_keys(master, uploaded)
    assert keys in (["SID"], ["SID", "Nielsen Store Code"])
    results, _ = compare(master, uploaded, keys)
    assert len(results) == 2
    assert results[0]["master"]["Store Name"] == "Alpha Store"
    assert results[0]["upload"]["Store Name"] == "Alpha Store"
    assert results[1]["upload"]["Store Name"] == "Beta Store Updated"
    assert results[1]["status"] == "REVIEW"


def test_compare_never_silently_selects_ambiguous_master_record():
    master = pd.DataFrame([
        {"SID": "S100", "Nielsen Store Code": "N100", "Store Name": "Alpha A"},
        {"SID": "S100", "Nielsen Store Code": "N100", "Store Name": "Alpha B"},
    ])
    uploaded = pd.DataFrame([{"SID": "S100", "Nielsen Store Code": "N100", "Store Name": "Alpha"}])
    results, _ = compare(master, uploaded, ["SID", "Nielsen Store Code"])
    assert results[0]["status"] == "REVIEW"
    assert results[0]["matchType"] == "AMBIGUOUS"
    assert "Ambiguous identity" in results[0]["message"]


def test_record_repair_inspection_keeps_actual_rows_and_issue_state():
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "repair.csv"
        source.write_text(
            "SID,Store Name,City,State,Pincode\n"
            "S1,Alpha,Pune,MH,411001\n"
            "S2,Beta,Pune\n"
            "S3,Gamma,Pune,MH,411003,EXTRA\n",
            encoding="utf-8",
        )
        tool = CSVRepairTool()
        payload = tool.inspect_csv(str(source))
        assert payload["headers"] == ["SID", "Store Name", "City", "State", "Pincode"]
        assert payload["rows"][0][0] == "S1"
        assert payload["rows"][1][0] == "S2"
        assert payload["rows"][2][0] == "S3"
        assert payload["issues"]
        assert payload["canExport"] is False
        assert payload["blockingIssues"] == len(payload["issues"])


def test_record_repair_parser_normalizes_shifted_rows_without_losing_source_values():
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "repair.csv"
        source.write_text("SID,Store Name,City\nS1,Alpha,Pune\nS2,Beta\nS3,Gamma,Pune,EXTRA\n", encoding="utf-8")
        parsed = robust_csv_parse(str(source))
        assert parsed["headers"] == ["SID", "Store Name", "City"]
        assert parsed["rows"][0] == ["S1", "Alpha", "Pune"]
        assert parsed["rows"][1] == ["S2", "Beta", ""]
        assert parsed["rows"][2] == ["S3", "Gamma", "Pune"]


def test_single_file_review_profile_contains_real_preview_values():
    dataframe = pd.DataFrame([
        {"SID": "S1", "Store Name": "Alpha", "City": "Pune"},
        {"SID": "S2", "Store Name": "Beta", "City": "Mumbai"},
    ])
    review = review_dataframe(dataframe)
    assert review["recordCount"] == 2
    assert review["columns"] == ["SID", "Store Name", "City"]
    assert review["rows"][0]["severity"] == "OK"
    assert review["rows"][0]["issues"] == []


def test_explore_sql_returns_actual_rows_and_identifier_values():
    dataframe = pd.DataFrame([
        {"SID": "100", "Store Name": "Alpha", "City": "Pune"},
        {"SID": "200", "Store Name": "Beta", "City": "Mumbai"},
        {"SID": "300", "Store Name": "Gamma", "City": "Pune"},
    ])
    result = run_sql(dataframe, 'SELECT SID, "Store Name" FROM data WHERE SID = \'100\'')
    assert len(result) == 1
    assert str(result.iloc[0]["SID"]) == "100"
    assert result.iloc[0]["Store Name"] == "Alpha"


def test_health_profile_and_statistics_return_structured_data_not_display_strings():
    dataframe = pd.DataFrame([
        {"SID": "S1", "Store Name": "Alpha", "City": "Pune"},
        {"SID": "S2", "Store Name": "Beta", "City": "Pune"},
        {"SID": "S3", "Store Name": "Gamma", "City": "Mumbai"},
    ])
    health = check_dataframe_health(dataframe)
    assert health["rows"] == 3
    assert health["columns"] == 3
    assert health["missingCells"] == 0
    profiled = profile(dataframe)
    assert profiled["rowCount"] == 3
    assert profiled["columnCount"] == 3
    assert profiled["columns"]["SID"]["uniqueCount"] == 3
    stats = statistic(dataframe, "City", "count")
    assert stats["column"] == "City"
    assert stats["value"] == 3
    unique_stats = statistic(dataframe, "City", "unique")
    assert unique_stats["value"] == 2
    grouped = statistic(dataframe, "SID", "count", "City")
    assert grouped["columns"] == ["City", "count"]
    assert {row["City"] for row in grouped["rows"]} == {"Pune", "Mumbai"}
