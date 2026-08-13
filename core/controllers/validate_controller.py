import json

from PySide6.QtCore import QObject, Slot, Signal, QUrl

from ..store_validator import StoreValidator


def _to_local_file(value):
    value = str(value or "")
    url = QUrl(value)
    if url.isLocalFile():
        return url.toLocalFile()
    return value


def _preview_payload(frame, limit=50):
    return {
        "columns": [str(column) for column in frame.columns],
        "rows": frame.head(limit).fillna("").astype(str).values.tolist(),
        "total": int(len(frame)),
    }


class ValidateController(QObject):
    mappingReady = Signal(str)
    validationReady = Signal(str)
    detailReady = Signal(str)
    masterPreviewReady = Signal(str)
    uploadPreviewReady = Signal(str)

    def __init__(self, async_runner, notify, fail, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify
        self.fail = fail
        self.validator = StoreValidator()
        self.last_results = []

    @Slot(str)
    def load_master(self, path):
        local_path = _to_local_file(path)
        def task():
            validator = StoreValidator()
            validator.load_master(local_path)
            return validator.master
        def success(frame):
            self.validator.master = frame
            self.masterPreviewReady.emit(json.dumps(_preview_payload(frame), default=str))
            if self.notify:
                self.notify("Master Loaded", "Master dataset loaded successfully.", "success")
        def error(exc):
            self.masterPreviewReady.emit(json.dumps({"columns": [], "rows": [], "total": 0}))
            if self.fail:
                self.fail("Master Load Error", str(exc))
        self.async_runner.run(task, success, error)

    @Slot(str)
    def load_upload(self, path):
        local_path = _to_local_file(path)
        def task():
            validator = StoreValidator()
            validator.load_upload(local_path)
            return validator.upload
        def success(frame):
            self.validator.upload = frame
            self.uploadPreviewReady.emit(json.dumps(_preview_payload(frame), default=str))
            if self.notify:
                self.notify("Upload Loaded", "Uploaded dataset loaded successfully.", "success")
        def error(exc):
            self.uploadPreviewReady.emit(json.dumps({"columns": [], "rows": [], "total": 0}))
            if self.fail:
                self.fail("Upload Load Error", str(exc))
        self.async_runner.run(task, success, error)

    @Slot()
    def detect(self):
        def task():
            return self.validator.detect_keys()
        def success(keys):
            self.mappingReady.emit(json.dumps({"suggestedKeys": keys}))
        def error(exc):
            if self.fail:
                self.fail("Detection Error", str(exc))
        self.async_runner.run(task, success, error)

    @Slot(str)
    def validate(self, keys_json):
        try:
            keys = json.loads(keys_json or "[]")
            if not isinstance(keys, list):
                raise ValueError("Validation keys must be a JSON array.")
        except Exception as exc:
            if self.fail:
                self.fail("Validation Error", str(exc))
            return
        def task():
            return self.validator.validate(keys)
        def success(results):
            raw_rows = results.get("rows", [])
            self.last_results = raw_rows
            correct = sum(1 for row in raw_rows if str(row.get("status", "")).upper() == "CORRECT")
            review = sum(1 for row in raw_rows if str(row.get("status", "")).upper() == "REVIEW")
            errors = sum(1 for row in raw_rows if str(row.get("status", "")).upper() == "ERROR")
            formatted_rows = []
            for index, row in enumerate(raw_rows):
                formatted_rows.append({"row": int(row.get("row", index + 1)), "key": str(row.get("key", "")), "status": str(row.get("status", "UNKNOWN")).upper(), "matchType": str(row.get("matchType", "")), "message": str(row.get("message", ""))})
            insights = []
            if errors:
                insights.append({"key": "ERROR", "title": "Critical Mismatches", "count": str(errors), "severity": "ERROR", "action": "Review errors immediately"})
            if review:
                insights.append({"key": "REVIEW", "title": "Manual Review Needed", "count": str(review), "severity": "REVIEW", "action": "Check flagged fields, including ambiguous identities"})
            if correct:
                insights.append({"key": "CORRECT", "title": "Correct Matches", "count": str(correct), "severity": "CORRECT", "action": "No action required"})
            self.validationReady.emit(json.dumps({"total": len(formatted_rows), "correct": correct, "review": review, "errors": errors, "attention": review + errors, "rows": formatted_rows, "insights": insights, "keys": results.get("keys", keys)}))
        def error(exc):
            if self.fail:
                self.fail("Validation Error", str(exc))
            self.validationReady.emit(json.dumps({"total": 0, "correct": 0, "review": 0, "errors": 1, "attention": 1, "rows": [], "insights": [], "keys": keys}))
        self.async_runner.run(task, success, error)

    @Slot(int, bool)
    def detail(self, index, diff_only):
        try:
            if not 0 <= index < len(self.last_results):
                return
            row = self.last_results[index]
            comparisons = list(row.get("comparisons", []))
            if diff_only:
                comparisons = [item for item in comparisons if str(item.get("severity", "")).upper() not in ("OK", "")]
            formatted = []
            for item in comparisons:
                formatted.append({"field": str(item.get("field", "")), "master": str(item.get("master", "")), "uploaded": str(item.get("uploaded", "")), "result": str(item.get("result", "")), "severity": str(item.get("severity", "")).upper()})
            self.detailReady.emit(json.dumps({"message": str(row.get("message", "")), "status": str(row.get("status", "")).upper(), "matchType": str(row.get("matchType", "")), "master": dict(row.get("master", {})), "upload": dict(row.get("upload", {})), "diffs": sum(1 for item in formatted if item["severity"] != "OK"), "comparisons": formatted}))
        except Exception as exc:
            if self.fail:
                self.fail("Detail Error", str(exc))
