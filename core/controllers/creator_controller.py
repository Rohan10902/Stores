import csv
import json
import os
import tempfile

from PySide6.QtCore import QObject, QUrl, Signal, Slot

from ..common import STORE_FIELDS, clean_value, read_table
from ..file_creator import creator_validate, export_creator


def _to_local_file(value):
    value = str(value or "")
    url = QUrl(value)
    if url.isLocalFile():
        return url.toLocalFile()
    return value


def _atomic_csv(rows, headers, destination):
    destination = str(destination)
    parent = os.path.dirname(os.path.abspath(destination)) or "."
    os.makedirs(parent, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".storelens-export-", suffix=".tmp", dir=parent)
    try:
        with os.fdopen(fd, "w", newline="", encoding="utf-8-sig") as file:
            writer = csv.writer(file)
            writer.writerow(headers)
            for row in rows:
                values = list(row) if isinstance(row, (list, tuple)) else []
                writer.writerow(values[:len(headers)] + [""] * max(0, len(headers) - len(values)))
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp_name, destination)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


class CreatorController(QObject):
    creatorLoaded = Signal(str)
    creatorReady = Signal(str)
    creatorExported = Signal()
    builderExported = Signal()

    def __init__(self, async_runner, notify, say, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify
        self.say = say
        self.current_headers = []
        self.current_rows = []

    @Slot(str)
    def load_creator_file(self, path):
        local_path = _to_local_file(path)

        def task():
            frame = read_table(local_path)
            headers = [str(column) for column in frame.columns]
            rows = frame.fillna("").astype(str).values.tolist()
            return headers, rows

        def success(result):
            self.current_headers, self.current_rows = result
            self.creatorLoaded.emit(json.dumps({
                "headers": self.current_headers,
                "rows": self.current_rows,
                "total": len(self.current_rows),
            }))
            if self.notify:
                self.notify("File Imported", f"Loaded {len(self.current_rows)} records and {len(self.current_headers)} columns.", "success")

        def error(exc):
            self.current_headers = []
            self.current_rows = []
            if self.notify:
                self.notify("Import Failed", str(exc), "error")
            self.creatorLoaded.emit(json.dumps({
                "headers": [],
                "rows": [],
                "total": 0,
                "error": str(exc),
            }))

        self.async_runner.run(task, success, error)

    @Slot(str)
    def validate_creator(self, rows_json):
        def task():
            rows = json.loads(rows_json or "[]")
            if not isinstance(rows, list):
                raise ValueError("Creator rows must be a JSON array.")
            normalized = []
            for row in rows:
                if not isinstance(row, dict):
                    normalized.append(row)
                    continue
                normalized.append({field: clean_value(row.get(field, "")) for field in STORE_FIELDS})
            findings = creator_validate(normalized)
            return len(normalized), findings

        def success(result):
            count, findings = result
            self.creatorReady.emit(json.dumps({"count": len(findings), "rows": count, "findings": findings}))

        def error(exc):
            if self.notify:
                self.notify("Validation Error", str(exc), "error")
            self.creatorReady.emit(json.dumps({"count": 1, "rows": 0, "findings": [{"row": 0, "field": "SYSTEM", "message": str(exc), "severity": "ERROR"}]}))

        self.async_runner.run(task, success, error)

    @Slot(str, str)
    def export_creator_file(self, rows_json, dst):
        try:
            rows = json.loads(rows_json or "[]")
            if not isinstance(rows, list):
                raise ValueError("Creator rows must be a JSON array.")
        except Exception as exc:
            if self.notify:
                self.notify("Export Error", str(exc), "error")
            return

        local_dst = _to_local_file(dst)
        headers = list(self.current_headers) or list(STORE_FIELDS)

        def task():
            _atomic_csv(rows, headers, local_dst)

        def success(_result):
            self.creatorExported.emit()
            if self.notify:
                self.notify("Success", "Store records exported successfully.", "success")

        def error(exc):
            if self.notify:
                self.notify("Export Error", str(exc), "error")

        self.async_runner.run(task, success, error)

    @Slot(str, str, str)
    def export_builder_file(self, rows_json, dst, headers_json):
        try:
            rows = json.loads(rows_json or "[]")
            headers = json.loads(headers_json or "[]")
            if not isinstance(rows, list) or not isinstance(headers, list) or headers != STORE_FIELDS:
                raise ValueError("Store Builder must export the canonical StoreLens schema.")
        except Exception as exc:
            if self.notify:
                self.notify("Export Error", str(exc), "error")
            return

        local_dst = _to_local_file(dst)

        def task():
            dict_rows = []
            for row in rows:
                values = list(row) if isinstance(row, list) else []
                dict_rows.append({headers[i]: clean_value(values[i]) if i < len(values) else "" for i in range(len(headers))})
            findings = creator_validate(dict_rows)
            if findings:
                raise ValueError(f"Export blocked: {len(findings)} validation finding(s) remain. Validate and fix the rows first.")
            return export_creator(dict_rows, local_dst)

        def success(_result):
            self.builderExported.emit()
            if self.notify:
                self.notify("Success", "Store Builder CSV exported successfully.", "success")

        def error(exc):
            if self.notify:
                self.notify("Export Error", str(exc), "error")

        self.async_runner.run(task, success, error)
