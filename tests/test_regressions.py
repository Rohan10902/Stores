# tests/test_regressions.py
import pytest
from core.utils.text_processing import clean_cell_text
from core.csv_repair import robust_csv_parse

def test_clean_cell_text_removes_unprintable_characters():
    dirty_string = "Store\x00Name\x1F"
    clean_string = clean_cell_text(dirty_string)
    assert clean_string == "StoreName", "Failed to strip non-printable null bytes."

def test_clean_cell_text_normalizes_whitespace():
    spaced_string = "   Store    Location   "
    assert clean_cell_text(spaced_string) == "Store Location", "Failed to trim and normalize spaces."

def test_robust_csv_parse_truncates_extra_columns(tmp_path):
    csv_file = tmp_path / "malformed_truncate.csv"
    # Row 1 has 3 columns, but Header only has 2
    csv_file.write_text("StoreID,StoreName\n101,Branch A,ExtraData\n102,Branch B", encoding="utf-8")
    
    result = robust_csv_parse(str(csv_file))
    
    assert len(result["headers"]) == 2
    assert len(result["rows"][0]) == 2
    assert result["rows"][0] == ["101", "Branch A"], "Parser failed to truncate orphaned column data."

def test_robust_csv_parse_pads_missing_columns(tmp_path):
    csv_file = tmp_path / "malformed_pad.csv"
    # Row 2 is missing the second column
    csv_file.write_text("StoreID,StoreName\n101,Branch A\n102", encoding="utf-8")
    
    result = robust_csv_parse(str(csv_file))
    
    assert len(result["rows"][1]) == 2
    assert result["rows"][1] == ["102", ""], "Parser failed to pad missing columns with empty strings."
