import csv
import json
import os
import tempfile

from PySide6.QtCore import QObject, QUrl, Signal, Slot

from core.common import read_table


def _to_local_file(value):
    value = str(value or "")
    url = QUrl(value)
    if url.isLocalFile():
        return url.toLocalFile()
    return value


def _atomic_csv(dataframe, destination):
    destination = os.path.abspath(destination)
    if not destination.lower().endswith(".csv"):
        destination += ".csv"
    parent = os.path.dirname(destination) or "."
    os.makedirs(parent, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".storelens-review-", suffix=".tmp", dir=parent)
    try:
        with os.fdopen(fd, "w", newline="", encoding="utf-8-sig") as file:
            writer = csv.writer(file)
            writer.writerow([str(column) for column in dataframe.columns])
            for row in dataframe.fillna("").astype(str).itertuples(index=False, name=None):
                writer.writerow(row)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp_name, destination)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise
    return destination


class ReviewController(QObject):
    singleReviewReady = Signal(str)

    def __init__(self, async_runner, notify_cb, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify_cb
        self.current_dataframe = None
        self.current_file = ""

    @Slot(str)
    def review_single_file(self, path):
        local_path = _to_local_file(path)

        def task():
            dataframe = read_table(local_path)
            preview_cols = [str(column) for column in dataframe.columns]
            preview_rows = dataframe.head(50).fillna("").astype(str).values.tolist()
            total = int(len(dataframe))
            attention = 0
            findings = []
            expected_columns = len(preview_cols)
            for index, row in enumerate(preview_rows, start=2):
                if len(row) != expected_columns:
                    findings.append({"message": f"Row {index}: Column count mismatch.", "severity": "ERROR"})
                    attention += 1
                elif not any(str(value).strip() for value in row):
                    findings.append({"message": f"Row {index}: Completely empty.", "severity": "WARNING"})
                    attention += 1
            return dataframe, {
                "totalRecords": total,
                "attentionCount": attention,
                "previewColumns": preview_cols,
                "previewRows": preview_rows,
                "findings": findings,
            }

        def success(result):
            self.current_dataframe, payload = result
            self.current_file = os.path.abspath(local_path)
            self.singleReviewReady.emit(json.dumps(payload, default=str))
            if self.notify:
                self.notify("Review Complete", f"Reviewed {payload['totalRecords']:,} records.", "success")

        def error(exc):
            self.current_dataframe = None
            self.current_file = ""
            if self.notify:
                self.notify("Review Failed", str(exc), "error")
            self.singleReviewReady.emit(json.dumps({
                "totalRecords": 0,
                "attentionCount": 1,
                "previewColumns": [],
                "previewRows": [],
                "findings": [{"message": str(exc), "severity": "ERROR"}],
            }))

        self.async_runner.run(task, success, error)

    @Slot(str, str)
    def export_single_review(self, src, dst):
        source = os.path.abspath(_to_local_file(src))
        destination = os.path.abspath(_to_local_file(dst))

        def task():
            if source == destination:
                raise ValueError("Review export destination cannot overwrite the source file.")
            dataframe = self.current_dataframe
            if dataframe is None or self.current_file != source:
                dataframe = read_table(source)
            return _atomic_csv(dataframe, destination)

        def success(output_path):
            if self.notify:
                self.notify("Success", f"Review exported successfully to {output_path}.", "success")

        def error(exc):
            if self.notify:
                self.notify("Export Failed", str(exc), "error")

        self.async_runner.run(task, success, error)
