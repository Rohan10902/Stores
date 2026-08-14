import csv
import tempfile
import unittest
from pathlib import Path

import pandas as pd

from core.common import STORE_FIELDS, canonical_field, parse_delimited_text
from core.file_creator import creator_validate, export_creator
from core.store_validator import compare, suggest_keys


class ProductionHardeningTests(unittest.TestCase):
    def test_canonical_schema_is_single_store_builder_schema(self):
        self.assertEqual(len(STORE_FIELDS), 14)
        self.assertEqual(
            STORE_FIELDS,
            [
                "Store Name", "SID", "Banner", "Nielsen Store Code",
                "Trip Received", "Last Trip", "Address 1", "Address 2",
                "Address 3", "ZIP", "Active / Inactive", "Is Census",
                "Is Exceptions", "Updated By",
            ],
        )

    def test_store_builder_aliases_cover_new_schema(self):
        self.assertEqual(canonical_field("pincode"), "ZIP")
        self.assertEqual(canonical_field("zip code"), "ZIP")
        self.assertEqual(canonical_field("address line 3"), "Address 3")
        self.assertEqual(canonical_field("active"), "Active / Inactive")
        self.assertEqual(canonical_field("updated_by"), "Updated By")

    def test_clipboard_parser_preserves_quoted_commas(self):
        rows = parse_delimited_text(
            'Store Name,SID,Address 1\n"North, Store",S1,"12, Main Street"\n'
        )
        self.assertEqual(rows[1][0], "North, Store")
        self.assertEqual(rows[1][2], "12, Main Street")

    def test_creator_rejects_duplicate_identity_and_invalid_values(self):
        rows = [
            {field: "" for field in STORE_FIELDS},
            {field: "" for field in STORE_FIELDS},
        ]
        for row in rows:
            row.update({
                "Store Name": "Example",
                "SID": "S1",
                "Nielsen Store Code": "N1",
                "ZIP": "abc",
                "Active / Inactive": "UNKNOWN",
                "Is Census": "maybe",
                "Trip Received": "not-a-date",
            })
        findings = creator_validate(rows)
        messages = [item["message"] for item in findings]
        self.assertTrue(any("Duplicate Nielsen Store Code" in message for message in messages))
        self.assertTrue(any("Duplicate composite identity" in message for message in messages))
        self.assertTrue(any("ZIP" in message for message in messages))
        self.assertTrue(any("Allowed values" in message for message in messages))
        self.assertTrue(any("Use Yes/No" in message for message in messages))
        self.assertTrue(any("Invalid date" in message for message in messages))

    def test_repeated_sid_is_allowed_when_nielsen_code_differs(self):
        rows = []
        for code in ("N1", "N2"):
            row = {field: "" for field in STORE_FIELDS}
            row.update({
                "Store Name": "Example",
                "SID": "S1",
                "Nielsen Store Code": code,
            })
            rows.append(row)
        self.assertEqual(creator_validate(rows), [])

    def test_ambiguous_master_match_is_never_silently_selected(self):
        master = pd.DataFrame([
            {"SID": "S1", "Nielsen Store Code": "N1", "Store Name": "A"},
            {"SID": "S1", "Nielsen Store Code": "N1", "Store Name": "B"},
        ])
        upload = pd.DataFrame([
            {"SID": "S1", "Nielsen Store Code": "N1", "Store Name": "A"},
        ])
        keys = suggest_keys(master, upload)
        records, _ = compare(master, upload, keys)
        self.assertEqual(records[0]["status"], "REVIEW")
        self.assertEqual(records[0]["matchType"], "AMBIGUOUS")
        self.assertIn("Ambiguous identity", records[0]["message"])

    def test_export_is_atomic_and_uses_canonical_headers(self):
        row = {field: "" for field in STORE_FIELDS}
        row.update({
            "Store Name": "Example",
            "SID": "S1",
            "Nielsen Store Code": "N1",
            "Address 3": "Suite 4",
            "ZIP": "411001",
            "Active / Inactive": "Active",
            "Is Census": "Yes",
            "Is Exceptions": "No",
            "Updated By": "StoreLens",
        })
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "stores.csv"
            export_creator([row], str(destination))
            with destination.open("r", encoding="utf-8-sig", newline="") as file:
                reader = csv.reader(file)
                self.assertEqual(next(reader), STORE_FIELDS)
                exported = next(reader)
                self.assertEqual(exported[1], "S1")
                self.assertEqual(exported[8], "Suite 4")
                self.assertEqual(exported[9], "411001")


if __name__ == "__main__":
    unittest.main()
