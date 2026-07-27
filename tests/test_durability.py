import csv
import json
import tempfile
import unittest
from pathlib import Path

import pandas as pd

from core.common import read_table
from core.csv_repair import (
    inspect_csv,
    create_record_from_extras,
    delete_created_record,
    undo_last_created_action,
    save_repaired,
)
from core.explorer import run_sql


class StoreLensDurabilityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, text):
        p = self.root / name
        p.write_text(text, encoding="utf-8-sig")
        return p

    def test_empty_delimited_file_is_safe(self):
        p = self.write("empty.csv", "")
        df = read_table(p)
        self.assertEqual(df.shape, (0, 0))

    def test_ragged_csv_preserves_every_row_and_extra_value(self):
        p = self.write("ragged.csv", "A,B,C\n1,2,3\n4,5,6,EXTRA\n7,8\n")
        df = read_table(p)
        self.assertEqual(len(df), 3)
        self.assertEqual(list(df.columns), ["A", "B", "C", "EXTRA 1"])
        self.assertEqual(df.iloc[1]["EXTRA 1"], "EXTRA")
        self.assertEqual(df.iloc[2]["C"], "")

    def test_quoted_multiline_record_is_reconstructed(self):
        p = self.write("quoted.csv", 'SID,Store Name,Notes\nS1,Alpha,"line one\nline two"\nS2,Beta,ok\n')
        audit = inspect_csv(p)
        self.assertEqual(audit["records"], 2)
        split = [i for i in audit["issues"] if i["kind"] == "PHYSICAL_LINE_SPLIT"]
        self.assertEqual(len(split), 1)
        self.assertEqual(split[0]["status"], "AUTO FIXED")

    def test_unclosed_quote_is_reported_not_silently_dropped(self):
        p = self.write("broken_quote.csv", 'A,B\n1,"unfinished\n2,value\n')
        audit = inspect_csv(p)
        self.assertEqual(audit["unrecoverable"], 1)
        self.assertTrue(any(i["kind"] == "UNCLOSED_QUOTE" for i in audit["issues"]))

    def test_semicolon_and_tsv_inputs(self):
        semi = self.write("semi.csv", "A;B\n1;2\n")
        tab = self.write("tab.tsv", "A\tB\n1\t2\n")
        self.assertEqual(read_table(semi).iloc[0].tolist(), ["1", "2"])
        self.assertEqual(read_table(tab).iloc[0].tolist(), ["1", "2"])

    def test_utf8_unicode_survives_load(self):
        p = self.write("unicode.csv", "Store,City\nCafé पुणे,東京\n")
        df = read_table(p)
        self.assertEqual(df.iloc[0]["Store"], "Café पुणे")
        self.assertEqual(df.iloc[0]["City"], "東京")

    def test_large_ragged_file_keeps_all_records(self):
        rows = ["A,B,C"]
        for i in range(10000):
            rows.append(f"{i},name-{i},{i % 7}" + (",overflow" if i % 997 == 0 else ""))
        p = self.write("large.csv", "\n".join(rows) + "\n")
        df = read_table(p)
        self.assertEqual(len(df), 10000)
        self.assertIn("EXTRA 1", df.columns)

    def test_repair_create_delete_undo_round_trip(self):
        p = self.write("repair.csv", "SID,Store Name,ZIP\nS1,Alpha,11111\nS2,Beta,22222,S3,Gamma,33333\n")
        audit = inspect_csv(p)
        issue_index = next(i for i, x in enumerate(audit["issues"]) if x["kind"] == "EXTRA_FIELDS")
        issue = audit["issues"][issue_index]
        extras = [i for i, c in enumerate(issue["columns"]) if c["field"].startswith("PRESERVED EXTRA")]
        mapping = {str(extras[0]): "SID", str(extras[1]): "Store Name", str(extras[2]): "ZIP"}
        create_record_from_extras(audit, issue_index, mapping)
        self.assertEqual(len(audit["createdRecords"]), 1)
        self.assertTrue(audit["createdRecords"][0]["active"])
        rid = audit["createdRecords"][0]["id"]
        delete_created_record(audit, rid)
        self.assertFalse(audit["createdRecords"][0]["active"])
        undo_last_created_action(audit)
        self.assertTrue(audit["createdRecords"][0]["active"])
        values = audit["createdRecords"][0]["values"]
        self.assertEqual(values["SID"], "S3")
        self.assertEqual(values["Store Name"], "Gamma")
        self.assertEqual(values["ZIP"], "33333")

    def test_repair_export_never_writes_overflow_columns(self):
        p = self.write("overflow.csv", "A,B\n1,2,EXTRA\n")
        audit = inspect_csv(p)
        for issue in audit["issues"]:
            for col in issue.get("columns", []):
                if col["field"].startswith("PRESERVED EXTRA"):
                    col["state"] = "UNRESOLVED"
        out = self.root / "out.csv"
        save_repaired(audit, out)
        with out.open(encoding="utf-8-sig", newline="") as f:
            rows = list(csv.reader(f))
        self.assertTrue(all(len(r) == 2 for r in rows))

    def test_sql_read_only_queries_work(self):
        df = pd.DataFrame({"Region": ["West", "West", "East"], "Amount": [10, 20, 5]})
        out = run_sql(df, 'SELECT "Region", SUM("Amount") AS total FROM data GROUP BY "Region" ORDER BY total DESC')
        self.assertEqual(out.iloc[0]["Region"], "West")
        self.assertEqual(int(out.iloc[0]["total"]), 30)

    def test_sql_mutating_or_non_query_statements_are_blocked(self):
        df = pd.DataFrame({"A": [1, 2]})
        bad = [
            "DELETE FROM data",
            "DROP TABLE data",
            "UPDATE data SET A=9",
            "COPY data TO 'x.csv'",
            "PRAGMA version",
        ]
        for q in bad:
            with self.subTest(q=q):
                with self.assertRaises(ValueError):
                    run_sql(df, q)

    def test_sql_handles_blanks_numbers_booleans_and_dates(self):
        df = pd.DataFrame({
            "N": ["1", "2", ""],
            "Flag": ["yes", "no", ""],
            "Date": ["2026-01-01", "2026-01-02", ""],
        })
        out = run_sql(df, 'SELECT SUM("N") AS s, COUNT(*) AS n FROM data')
        self.assertEqual(int(out.iloc[0]["s"]), 3)
        self.assertEqual(int(out.iloc[0]["n"]), 3)

    def test_json_shapes_load(self):
        p1 = self.write("list.json", json.dumps([{"A": 1}, {"A": 2}]))
        p2 = self.write("wrapped.json", json.dumps({"records": [{"A": 1}, {"A": 2}]}))
        self.assertEqual(len(read_table(p1)), 2)
        self.assertEqual(len(read_table(p2)), 2)

    def test_unsupported_extension_fails_explicitly(self):
        p = self.write("bad.bin", "abc")
        with self.assertRaisesRegex(ValueError, "Unsupported file type"):
            read_table(p)


if __name__ == "__main__":
    unittest.main()
