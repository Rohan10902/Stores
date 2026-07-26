import tempfile
import unittest
from pathlib import Path

import pandas as pd

from core.common import STORE_FIELDS, binary_ok, date_ok, map_columns, read_table
from core.file_creator import creator_validate, export_creator, normalize_nielsen, parse_clipboard, review_dataframe


class ProductionCoreTests(unittest.TestCase):
    def test_store_schema_is_fixed_to_14_columns(self):
        self.assertEqual(len(STORE_FIELDS), 14)
        self.assertEqual(STORE_FIELDS[0], "Store Name")
        self.assertEqual(STORE_FIELDS[-1], "Updated By")

    def test_excel_clipboard_tabs_and_empty_cells_are_preserved(self):
        rows = parse_clipboard("Alpha\t1001\tFresh Mart\t00123\nBeta\t1002\tValue Store\t\t")
        self.assertEqual(rows[0][3], "00123")
        self.assertEqual(rows[1][3], "")

    def test_empty_clipboard_is_safe(self):
        self.assertEqual(parse_clipboard(""), [])
        self.assertEqual(parse_clipboard(None), [])

    def test_nielsen_padding_only_changes_numeric_codes(self):
        self.assertEqual(normalize_nielsen("123", 6), "000123")
        self.assertEqual(normalize_nielsen("00123", 6), "000123")
        self.assertEqual(normalize_nielsen("NSC123", 6), "NSC123")
        self.assertEqual(normalize_nielsen("", 6), "")

    def test_review_flags_short_nielsen_codes(self):
        df = pd.DataFrame({"Nielsen Store Code": ["001234", "123"], "Store Name": ["A", "B"]})
        result = review_dataframe(df)
        self.assertEqual(result["suggestedNielsenWidth"], 6)
        self.assertEqual(result["issueCount"], 1)
        self.assertIn("shorter than suggested width 6", result["rows"][1]["issues"][0])

    def test_creator_validation_reports_bad_boolean_and_date(self):
        row = {field: "" for field in STORE_FIELDS}
        row.update({"Store Name": "A", "Active / Inactive": "maybe", "Trip Received": "not-a-date"})
        findings = creator_validate([row])
        fields = {item["field"] for item in findings}
        self.assertIn("Active / Inactive", fields)
        self.assertIn("Trip Received", fields)

    def test_valid_boolean_variants(self):
        for value in ("", "0", "1", "true", "false", "yes", "no", "TRUE", "Yes", "active", "inactive", "Active", "Inactive"):
            self.assertTrue(binary_ok(value), value)
        self.assertFalse(binary_ok("maybe"))

    def test_dates_accept_blank_and_real_dates(self):
        self.assertTrue(date_ok(""))
        self.assertTrue(date_ok("2026-07-26"))
        self.assertFalse(date_ok("definitely-not-a-date"))

    def test_column_mapping_recognizes_common_aliases(self):
        mapping = map_columns(["Outlet Name", "Store ID", "Nielsen Code", "Postal Code"])
        self.assertEqual(mapping["Store Name"]["column"], "Outlet Name")
        self.assertEqual(mapping["SID"]["column"], "Store ID")
        self.assertEqual(mapping["Nielsen Store Code"]["column"], "Nielsen Code")
        self.assertEqual(mapping["ZIP"]["column"], "Postal Code")

    def test_csv_export_has_exact_schema_and_does_not_mutate_input(self):
        row = {field: "" for field in STORE_FIELDS}
        row.update({"Store Name": "Alpha", "SID": "1001", "Nielsen Store Code": "00123"})
        original = dict(row)
        with tempfile.TemporaryDirectory() as tmp:
            path = export_creator([row], str(Path(tmp) / "stores"))
            exported = pd.read_csv(path, dtype=str, keep_default_na=False)
            self.assertEqual(list(exported.columns), STORE_FIELDS)
            self.assertEqual(exported.loc[0, "Nielsen Store Code"], "00123")
        self.assertEqual(row, original)

    def test_read_table_rejects_unsupported_extension(self):
        with self.assertRaises(ValueError):
            read_table("data.exe")


if __name__ == "__main__":
    unittest.main()
