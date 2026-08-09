import csv
import json
import shutil

from PySide6.QtCore import QObject, QUrl, Signal, Slot


def _to_local_file(value):
    value = str(value or "")
    url = QUrl(value)
    if url.isLocalFile():
        return url.toLocalFile()
    return value


class ReviewController(QObject):
    singleReviewReady = Signal(str)

    def __init__(self, async_runner, notify_cb, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify_cb

    @Slot(str)
    def review_single_file(self, path):
        try:
            local_path = _to_local_file(path)
            findings = []
            preview_cols = []
            preview_rows = []
            total = 0
            attention = 0

            with open(
                local_path,
                "r",
                encoding="utf-8",
                errors="replace",
                newline="",
            ) as file:
                reader = csv.reader(file)

                try:
                    preview_cols = next(reader)
                except StopIteration:
                    preview_cols = []

                for row in reader:
                    total += 1

                    if total <= 50:
                        preview_rows.append(row)

                    if len(row) != len(preview_cols):
                        findings.append({
                            "message": (
                                f"Row {total}: Column count mismatch."
                            ),
                            "severity": "ERROR",
                        })
                        attention += 1

                    elif not any(str(value).strip() for value in row):
                        findings.append({
                            "message": (
                                f"Row {total}: Completely empty."
                            ),
                            "severity": "WARNING",
                        })
                        attention += 1

            self.singleReviewReady.emit(
                json.dumps({
                    "totalRecords": total,
                    "attentionCount": attention,
                    "previewColumns": preview_cols,
                    "previewRows": preview_rows,
                    "findings": findings,
                })
            )

            if self.notify:
                self.notify(
                    "Review Complete",
                    f"Reviewed {total} records.",
                    "success",
                )

        except Exception as exc:
            if self.notify:
                self.notify(
                    "Review Failed",
                    str(exc),
                    "error",
                )

            self.singleReviewReady.emit(
                json.dumps({
                    "totalRecords": 0,
                    "attentionCount": 1,
                    "previewColumns": [],
                    "previewRows": [],
                    "findings": [{
                        "message": str(exc),
                        "severity": "ERROR",
                    }],
                })
            )

    @Slot(str, str)
    def export_single_review(self, src, dst):
        try:
            shutil.copy2(
                _to_local_file(src),
                _to_local_file(dst),
            )

            if self.notify:
                self.notify(
                    "Success",
                    "Review exported successfully.",
                    "success",
                )

        except Exception as exc:
            if self.notify:
                self.notify(
                    "Export Failed",
                    str(exc),
                    "error",
                )
