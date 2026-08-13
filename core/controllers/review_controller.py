import csv
import json
import shutil

from PySide6.QtCore import QObject, QUrl, Signal, Slot

from core.common import read_table


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
            dataframe = read_table(local_path)

            preview_cols = [str(column) for column in dataframe.columns]
            preview_rows = (
                dataframe.head(50)
                .fillna("")
                .astype(str)
                .values
                .tolist()
            )
            total = int(len(dataframe))
            attention = 0
            findings = []

            expected_columns = len(preview_cols)
            for index, row in enumerate(preview_rows, start=2):
                if len(row) != expected_columns:
                    findings.append({
                        "message": f"Row {index}: Column count mismatch.",
                        "severity": "ERROR",
                    })
                    attention += 1
                elif not any(str(value).strip() for value in row):
                    findings.append({
                        "message": f"Row {index}: Completely empty.",
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
                }, default=str)
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
