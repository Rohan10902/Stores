import csv
import json
import os
import tempfile

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot

from ..common import (
    STORE_FIELDS,
    clean_value,
    canonical_field,
    normalize_binary_value,
    normalize_nielsen_code,
    parse_delimited_text,
    read_table,
    suggested_numeric_width,
)
from ..file_creator import creator_validate, export_creator
from ..models.store_table_model import StoreTableModel


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


def _normalize_import_rows(headers, rows):
    """Normalize Store Builder values before QML receives them."""
    headers = [clean_value(value) for value in headers]
    field_by_index = [canonical_field(header) for header in headers]
    nielsen_values = []
    for row in rows:
        for index, field in enumerate(field_by_index):
            if field == "Nielsen Store Code" and index < len(row):
                nielsen_values.append(clean_value(row[index]))
    nielsen_width = suggested_numeric_width(nielsen_values)

    normalized_rows = []
    for row in rows:
        values = list(row)
        if len(values) < len(headers):
            values.extend([""] * (len(headers) - len(values)))
        for index, field in enumerate(field_by_index):
            if index >= len(values):
                continue
            value = clean_value(values[index])
            if field in {"Active / Inactive", "Is Census", "Is Exceptions"}:
                value = normalize_binary_value(value)
            elif field == "Nielsen Store Code":
                value = normalize_nielsen_code(value, nielsen_width)
            values[index] = value
        normalized_rows.append(values[:len(headers)])
    return headers, normalized_rows


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
        self._store_model = StoreTableModel(self)

    storeModel = Property(QObject, lambda self: self._store_model, constant=True)

    def _emit_loaded(self, headers, rows):
        headers, rows = _normalize_import_rows(headers, rows)
        self.current_headers = list(headers)
        self.current_rows = list(rows)
        self.creatorLoaded.emit(json.dumps({
            "headers": self.current_headers,
            "rows": self.current_rows,
            "total": len(self.current_rows),
        }))

    @Slot(str)
    def load_creator_file(self, path):
        local_path = _to_local_file(path)

        def task():
            frame = read_table(local_path)
            headers = [str(column) for column in frame.columns]
            rows = frame.fillna("").astype(str).values.tolist()
            return headers, rows

        def success(result):
            self._emit_loaded(*result)
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
    def load_creator_text(self, text):
        def task():
            parsed = parse_delimited_text(text)
            if len(parsed) < 2:
                raise ValueError("Paste at least one header row and one store row.")
            headers = [clean_value(value) for value in parsed[0]]
            rows = [list(row) for row in parsed[1:] if any(clean_value(value) for value in row)]
            if not any(headers):
                raise ValueError("The pasted data does not contain usable headers.")
            return headers, rows

        def success(result):
            self._emit_loaded(*result)
            if self.notify:
                self.notify("Stores Pasted", f"Parsed {len(self.current_rows)} records and {len(self.current_headers)} columns.", "success")

        def error(exc):
            if self.notify:
                self.notify("Paste Failed", str(exc), "error")
            self.creatorLoaded.emit(json.dumps({
                "headers": [],
                "rows": [],
                "total": 0,
                "error": str(exc),
            }))

        self.async_runner.run(task, success, error)

    @Slot(str)
    def set_builder_rows(self, rows_json):
        self._store_model.setRowsJson(rows_json)

    @Slot()
    def reset_builder_rows(self):
        self._store_model.reset()

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
            self.creatorReady.emit(json.dumps({
                "count": 1,
                "rows": 0,
                "findings": [{"row": 0, "field": "SYSTEM", "message": str(exc), "severity": "ERROR"}],
            }))

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
