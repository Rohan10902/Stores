# core/csv_repair.py

import copy
import csv
import json
import os
import tempfile
import uuid


def robust_csv_parse(path):
    if not path:
        raise ValueError("CSV path cannot be empty.")
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")
    with open(path, "r", encoding="utf-8", errors="replace", newline="") as file:
        reader = csv.reader(file)
        try:
            headers = next(reader)
        except StopIteration:
            return {"headers": [], "rows": []}
        expected_columns = len(headers)
        rows = []
        for row in reader:
            if len(row) > expected_columns:
                row = row[:expected_columns]
            elif len(row) < expected_columns:
                row = row + [""] * (expected_columns - len(row))
            rows.append(row)
    return {"headers": headers, "rows": rows}


class CSVRepairTool:
    def __init__(self):
        self.headers = []
        self.rows = []
        self.row_ids = []
        self.issues = []
        self.history = []
        self.created_records = {}
        self.record_counter = 10000
        self.current_source = ""

    def _save_state(self):
        self.history.append((copy.deepcopy(self.rows), copy.deepcopy(self.row_ids), copy.deepcopy(self.issues), copy.deepcopy(self.created_records)))

    def inspect_csv(self, path):
        self.headers = []
        self.rows = []
        self.row_ids = []
        self.issues = []
        self.history = []
        self.created_records = {}
        self.current_source = os.path.abspath(path)
        if not os.path.exists(path):
            raise FileNotFoundError(f"File not found: {path}")
        with open(path, "r", encoding="utf-8", errors="replace", newline="") as file:
            reader = csv.reader(file)
            try:
                self.headers = next(reader)
            except StopIteration:
                return self._get_payload()
            for row in reader:
                self.rows.append(row)
                self.row_ids.append(str(uuid.uuid4()))
        self._recalculate_issues()
        return self._get_payload()

    def join_shifted_rows(self, issue_index):
        self._save_state()
        issue = next((item for item in self.issues if item["index"] == issue_index), None)
        if issue is None:
            return self._get_payload()
        row_index = issue["row"] - 1
        if not 0 <= row_index < len(self.rows) - 1:
            return self._get_payload()
        self.rows[row_index] = self.rows[row_index] + self.rows[row_index + 1]
        del self.rows[row_index + 1]
        del self.row_ids[row_index + 1]
        self._recalculate_issues()
        return self._get_payload()

    def apply_mapping(self, issue_index, col_index, target, remember):
        self._save_state()
        issue = next((item for item in self.issues if item["index"] == issue_index), None)
        if issue is None:
            return self._get_payload()
        row_index = issue["row"] - 1
        if not 0 <= row_index < len(self.rows):
            return self._get_payload()
        row = self.rows[row_index]
        if not 0 <= col_index < len(row):
            return self._get_payload()
        if target not in self.headers:
            return self._get_payload()
        target_index = self.headers.index(target)
        value = row[col_index]
        del row[col_index]
        if col_index < target_index:
            target_index -= 1
        if target_index >= len(row):
            row.extend([""] * (target_index - len(row) + 1))
        row.insert(target_index, value)
        self._resolve_by_padding(issue_index)
        return self._get_payload()

    def keep_unresolved(self, issue_index, col_index):
        self._save_state()
        self._resolve_by_padding(issue_index)
        return self._get_payload()

    def keep_issue_as_is(self, issue_index):
        self._save_state()
        self.issues = [issue for issue in self.issues if issue["index"] != issue_index]
        return self._get_payload()

    def create_record_from_extras(self, issue_index, mapping_json):
        self._save_state()
        issue = next((item for item in self.issues if item["index"] == issue_index), None)
        if issue is None:
            return self._get_payload()
        row_index = issue["row"] - 1
        if not 0 <= row_index < len(self.rows):
            return self._get_payload()
        expected = len(self.headers)
        new_row = [""] * expected
        try:
            mapping = json.loads(mapping_json or "{}")
        except (TypeError, ValueError):
            mapping = {}
        if isinstance(mapping, dict):
            for target_column, value in mapping.items():
                if target_column in self.headers:
                    new_row[self.headers.index(target_column)] = "" if value is None else str(value)
        if not mapping:
            source = self.rows[row_index]
            if len(source) > expected:
                for index, value in enumerate(source[expected:expected * 2]):
                    new_row[index] = value
        record_id = self.record_counter
        self.record_counter += 1
        record_uuid = str(uuid.uuid4())
        self.created_records[record_id] = record_uuid
        insert_index = row_index + 1
        self.rows.insert(insert_index, new_row)
        self.row_ids.insert(insert_index, record_uuid)
        self._recalculate_issues()
        self.issues.append({"index": record_id, "row": insert_index + 1, "type": "Created Record", "message": f"Created new record (ID: {record_id})"})
        return self._get_payload()

    def delete_created_record(self, record_id):
        self._save_state()
        try:
            record_id = int(record_id)
        except (TypeError, ValueError):
            return self._get_payload()
        record_uuid = self.created_records.get(record_id)
        if not record_uuid or record_uuid not in self.row_ids:
            return self._get_payload()
        row_index = self.row_ids.index(record_uuid)
        del self.rows[row_index]
        del self.row_ids[row_index]
        del self.created_records[record_id]
        self.issues = [issue for issue in self.issues if issue.get("index") != record_id]
        self._recalculate_issues()
        return self._get_payload()

    def undo_action(self):
        if not self.history:
            return self._get_payload()
        self.rows, self.row_ids, self.issues, self.created_records = self.history.pop()
        return self._get_payload()

    def export_csv(self, dst):
        if not dst:
            raise ValueError("Destination path cannot be empty.")
        destination = os.path.abspath(dst)
        if self.current_source and os.path.abspath(self.current_source) == destination:
            raise ValueError("Export destination cannot overwrite the source file.")
        parent = os.path.dirname(destination) or "."
        os.makedirs(parent, exist_ok=True)
        fd, temp_name = tempfile.mkstemp(prefix=".storelens-repair-", suffix=".tmp", dir=parent)
        try:
            with os.fdopen(fd, "w", newline="", encoding="utf-8-sig") as file:
                writer = csv.writer(file)
                writer.writerow(self.headers)
                writer.writerows(self.rows)
                file.flush()
                os.fsync(file.fileno())
            os.replace(temp_name, destination)
        except Exception:
            try:
                os.unlink(temp_name)
            except OSError:
                pass
            raise

    def _resolve_by_padding(self, issue_index):
        issue = next((item for item in self.issues if item["index"] == issue_index), None)
        if issue is None:
            return
        row_index = issue["row"] - 1
        if not 0 <= row_index < len(self.rows):
            return
        expected = len(self.headers)
        row = self.rows[row_index]
        if len(row) > expected:
            self.rows[row_index] = row[:expected]
        elif len(row) < expected:
            self.rows[row_index] = row + [""] * (expected - len(row))
        self._recalculate_issues()

    def _recalculate_issues(self):
        created = [copy.deepcopy(issue) for issue in self.issues if issue.get("type") == "Created Record"]
        self.issues = []
        expected = len(self.headers)
        for index, row in enumerate(self.rows):
            if len(row) != expected:
                self.issues.append({"index": len(self.issues), "row": index + 1, "type": "Structural Mismatch", "message": f"Expected {expected} columns, found {len(row)}."})
        for created_issue in created:
            record_id = created_issue.get("index")
            record_uuid = self.created_records.get(record_id)
            if record_uuid and record_uuid in self.row_ids:
                created_issue["row"] = self.row_ids.index(record_uuid) + 1
                self.issues.append(created_issue)

    def _get_payload(self):
        blocking = [issue for issue in self.issues if issue.get("type") != "Created Record"]
        return {
            "headers": self.headers,
            "rows": self.rows,
            "issues": self.issues,
            "history": len(self.history),
            "blockingIssues": len(blocking),
            "canExport": len(blocking) == 0 and bool(self.headers),
        }
