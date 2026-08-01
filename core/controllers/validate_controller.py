# core/controllers/validate_controller.py
import json
from PySide6.QtCore import QObject, Signal

from core.common import read_table
from core.store_validator import suggest_keys, compare, validation_insights
from core.utils.helpers import local_path, free_memory
from core.utils.logger import get_logger

logger = get_logger("ValidateController")


class ValidateController(QObject):
    mappingReady = Signal(str)
    validationReady = Signal(str)
    detailReady = Signal(str)

    def __init__(self, async_runner, notify_cb, fail_cb):
        super().__init__()
        self.async_runner = async_runner
        self.notify = notify_cb
        self.fail = fail_cb
        self._master_df = None
        self._upload_df = None
        self._compare_records = []

    def load_master(self, path):
        self._master_df = None
        free_memory()

        def task():
            return read_table(local_path(path))

        def on_complete(df):
            self._master_df = df
            self.notify("Master Active", f"Loaded {len(df):,} master stores.", "info")

        self.async_runner.run_async("load_master", task, on_complete)

    def load_upload(self, path):
        self._upload_df = None
        free_memory()

        def task():
            return read_table(local_path(path))

        def on_complete(df):
            self._upload_df = df
            self.notify("Upload Active", f"Loaded {len(df):,} uploaded stores.", "info")

        self.async_runner.run_async("load_upload", task, on_complete)

    def detect(self):
        if self._master_df is None or self._upload_df is None:
            return self.fail("Both Master and Upload files must be loaded.")

        def task():
            return suggest_keys(self._master_df, self._upload_df)

        def on_complete(keys):
            self.mappingReady.emit(json.dumps({"suggestedKeys": list(keys)}))
            self.notify("Auto-Detection Complete", f"Identified matching key(s): {', '.join(keys)}", "info")

        self.async_runner.run_async("detect_keys", task, on_complete)

    def validate(self, keys_json):
        if self._master_df is None or self._upload_df is None:
            return self.fail("Cannot run validation without active Master and Upload datasets.")

        def task():
            keys = json.loads(keys_json)
            mm, um, records, k = compare(self._master_df, self._upload_df, keys)
            insights = validation_insights(records)
            payload = {
                "total": len(self._upload_df),
                "correct": sum(1 for r in records if r["status"] == "CORRECT"),
                "review": sum(1 for r in records if r["status"] == "REVIEW"),
                "errors": sum(1 for r in records if r["status"] == "ERROR"),
                "attention": insights.get("attention", 0),
                "rows": records
            }
            return records, json.dumps(payload)

        def on_complete(result):
            records, payload = result
            self._compare_records = records
            self.validationReady.emit(payload)
            self.notify("Comparison Complete", "Validation inspection ready.", "success")

        self.async_runner.run_async("validate_compare", task, on_complete)

    def detail(self, index, diff_only):
        try:
            if 0 <= index < len(self._compare_records):
                self.detailReady.emit(json.dumps(self._compare_records[index]))
            else:
                logger.warning(f"Out-of-bounds detail index requested: {index}")
        except Exception as e:
            self.fail(e)
