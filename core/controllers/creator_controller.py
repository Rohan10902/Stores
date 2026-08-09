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

    def __init__(self, async_runner, notify, say, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify
        self.say = say
        self.current_headers = []
        self.current_rows = []

    @Slot(str)
    def load_creator_file(self, path):
        self.current_headers = []
        self.current_rows = []

        try:
            local_path = _to_local_file(path)

            with open(
                local_path,
                "r",
                encoding="utf-8",
                errors="replace",
                newline="",
            ) as file:
                reader = csv.reader(file)
                try:
                    self.current_headers = next(reader)
                except StopIteration:
                    self.current_headers = []
                    self.current_rows = []
                else:
                    self.current_rows = list(reader)

            self.creatorLoaded.emit(
                json.dumps({
                    "headers": self.current_headers,
                    "rows": self.current_rows,
                })
            )

            if self.notify:
                self.notify(
                    "Template Loaded",
                    "Store template loaded successfully.",
                    "success",
                )

        except Exception as exc:
            if self.notify:
                self.notify(
                    "Load Failed",
                    str(exc),
                    "error",
                )

            self.creatorLoaded.emit(
                json.dumps({
                    "headers": [],
                    "rows": [],
                })
            )

    @Slot(str)
    def validate_creator(self, rows_json):
        try:
            rows = json.loads(rows_json or "[]")

            if not isinstance(rows, list):
                raise ValueError(
                    "Creator rows must be a JSON array."
                )

            findings = []

            for index, row in enumerate(rows):
                if not isinstance(row, list):
                    findings.append({
                        "message": (
                            f"Row {index + 1}: Invalid row structure."
                        ),
                        "severity": "ERROR",
                    })
                    continue

                if not any(str(value).strip() for value in row):
                    continue

                if not row or not str(row[0]).strip():
                    findings.append({
                        "message": (
                            f"Row {index + 1}: Primary ID is empty"
                        ),
                        "severity": "ERROR",
                    })

            self.creatorReady.emit(
                json.dumps({
                    "count": len(rows),
                    "findings": findings,
                })
            )

        except Exception as exc:
            if self.notify:
                self.notify(
                    "Validation Error",
                    str(exc),
                    "error",
                )

            self.creatorReady.emit(
                json.dumps({
                    "count": 0,
                    "findings": [{
                        "message": str(exc),
                        "severity": "ERROR",
                    }],
                })
            )

    @Slot(str, str)
    def export_creator_file(self, rows_json, dst):
        try:
            rows = json.loads(rows_json or "[]")

            if not isinstance(rows, list):
                raise ValueError(
                    "Creator rows must be a JSON array."
                )

            local_dst = _to_local_file(dst)

            with open(
                local_dst,
                "w",
                newline="",
                encoding="utf-8",
            ) as file:
                writer = csv.writer(file)
                writer.writerow(self.current_headers)
                writer.writerows(rows)

            self.creatorExported.emit()

            if self.notify:
                self.notify(
                    "Success",
                    "Store records exported successfully.",
                    "success",
                )

        except Exception as exc:
            if self.notify:
                self.notify(
                    "Export Error",
                    str(exc),
                    "error",
                )
