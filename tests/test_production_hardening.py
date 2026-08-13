import csv
import tempfile
import unittest
from pathlib import Path

import pandas as pd

from core.common import STORE_FIELDS, parse_delimited_text
from core.file_creator import creator_validate, export_creator
from core.store_validator import compare, suggest_keys


class ProductionHardeningTests(unittest.TestCase):
    def test_canonical_schema_is_single_builder_schema(self):
        self.assertEqual(len(STORE_FIELDS), 12)
        self.assertEqual(
            STORE_FIELDS,
            [
                "Store Name", "SID", "Banner", "Nielsen Store Code",
                "Trip Received", "Last Trip", "Address 1", "Address 2",
                "City", "State", "Pincode", "Phone",
            ],
        )

    def test_clipboard_parser_preserves_quoted_commas(self):
        rows = parse_delimited_text('Store Name,SID,Address 1\n"North, Store",S1,"12, Main Street"\n')
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
                "Pincode": "abc",
                "Phone": "12",
            })
        findings = creator_validate(rows)
        messages = [item["message"] for item in findings]
        self.assertTrue(any("Duplicate SID" in message for message in messages))
        self.assertTrue(any("Pincode" in message for message in messages))
        self.assertTrue(any("Phone" in message for message in messages))

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
        row.update({"Store Name": "Example", "SID": "S1", "Nielsen Store Code": "N1"})
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "stores.csv"
            export_creator([row], str(destination))
            with destination.open("r", encoding="utf-8-sig", newline="") as file:
                reader = csv.reader(file)
                self.assertEqual(next(reader), STORE_FIELDS)
                self.assertEqual(next(reader)[1], "S1")


if __name__ == "__main__":
    unittest.main()
