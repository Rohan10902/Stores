import csv
import json

from PySide6.QtCore import QObject, QUrl, Signal, Slot


def _to_local_file(value):
    value = str(value or "")
    url = QUrl(value)
    if url.isLocalFile():
        return url.toLocalFile()
    return value


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
            headers = []
            rows = []
            with open(local_path, "r", encoding="utf-8", errors="replace", newline="") as file:
                reader = csv.reader(file)
                try:
                    headers = next(reader)
                except StopIteration:
                    return headers, rows
                rows = list(reader)
            return headers, rows

        def success(result):
            self.current_headers, self.current_rows = result
            self.creatorLoaded.emit(json.dumps({"headers": self.current_headers, "rows": self.current_rows}))
            if self.notify:
                self.notify("Template Loaded", "Store template loaded successfully.", "success")

        def error(exc):
            self.current_headers = []
            self.current_rows = []
            if self.notify:
                self.notify("Load Failed", str(exc), "error")
            self.creatorLoaded.emit(json.dumps({"headers": [], "rows": []}))

        self.async_runner.run(task, success, error)

    @Slot(str)
    def validate_creator(self, rows_json):
        def task():
            rows = json.loads(rows_json or "[]")
            if not isinstance(rows, list):
                raise ValueError("Creator rows must be a JSON array.")
            findings = []
            for index, row in enumerate(rows):
                if not isinstance(row, list):
                    findings.append({"message": f"Row {index + 1}: Invalid row structure.", "severity": "ERROR"})
                    continue
                if not any(str(value).strip() for value in row):
                    continue
                if not row or not str(row[0]).strip():
                    findings.append({"message": f"Row {index + 1}: Primary ID is empty", "severity": "ERROR"})
            return len(rows), findings

        def success(result):
            count, findings = result
            self.creatorReady.emit(json.dumps({"count": count, "findings": findings}))

        def error(exc):
            if self.notify:
                self.notify("Validation Error", str(exc), "error")
            self.creatorReady.emit(json.dumps({"count": 0, "findings": [{"message": str(exc), "severity": "ERROR"}]}))

        self.async_runner.run(task, success, error)

    @Slot(str, str)
    def export_creator_file(self, rows_json, dst):
        rows = json.loads(rows_json or "[]")
        if not isinstance(rows, list):
            if self.notify:
                self.notify("Export Error", "Creator rows must be a JSON array.", "error")
            return

        local_dst = _to_local_file(dst)
        headers = list(self.current_headers)

        def task():
            with open(local_dst, "w", newline="", encoding="utf-8") as file:
                writer = csv.writer(file)
                writer.writerow(headers)
                writer.writerows(rows)

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
        except Exception as exc:
            if self.notify:
                self.notify("Export Error", str(exc), "error")
            return

        if not isinstance(rows, list) or not isinstance(headers, list) or not headers:
            if self.notify:
                self.notify("Export Error", "Invalid Store Builder data.", "error")
            return

        local_dst = _to_local_file(dst)

        def task():
            with open(local_dst, "w", newline="", encoding="utf-8-sig") as file:
                writer = csv.writer(file)
                writer.writerow(headers)
                for row in rows:
                    writer.writerow(list(row)[:len(headers)] + [""] * max(0, len(headers) - len(row)))

        def success(_result):
            self.builderExported.emit()
            if self.notify:
                self.notify("Success", "Store Builder CSV exported successfully.", "success")

        def error(exc):
            if self.notify:
                self.notify("Export Error", str(exc), "error")

        self.async_runner.run(task, success, error)
