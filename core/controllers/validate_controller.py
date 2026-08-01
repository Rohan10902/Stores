# core/controllers/validate_controller.py
import json
import os
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
        
        l_path = local_path(path)
        # 🔴 CRITICAL: Verify files exist before opening them
        if not l_path or not os.path.exists(l_path):
            return self.fail(f"Master file not found at: {l_path}")

        def task():
            df = read_table(l_path)
            # 🔴 CRITICAL: Handle empty datasets gracefully
            if df is None or df.empty:
                raise ValueError("The loaded Master dataset is empty or corrupted.")
            return df

        def on_complete(df):
            self._master_df = df
            self.notify("Master Active", f"Loaded {len(df):,} master stores.", "info")

        self.async_runner.run_async("load_master", task, on_complete)

    def load_upload(self, path):
        self._upload_df = None
        free_memory()
        
        l_path = local_path(path)
        # 🔴 CRITICAL: Verify files exist before opening them
        if not l_path or not os.path.exists(l_path):
            return self.fail(f"Upload file not found at: {l_path}")

        def task():
            df = read_table(l_path)
            # 🔴 CRITICAL: Handle empty datasets gracefully
            if df is None or df.empty:
                raise ValueError("The loaded Upload dataset is empty or corrupted.")
            return df

        def on_complete(df):
            self._upload_df = df
            self.notify("Upload Active", f"Loaded {len(df):,} uploaded stores.", "info")

        self.async_runner.run_async("load_upload", task, on_complete)

    def detect(self):
        # 🔴 CRITICAL: Check for None before accessing attributes
        if self._master_df is None or self._upload_df is None:
            return self.fail("Both Master and Upload files must be loaded before running detection.")
            
        if self._master_df.empty or self._upload_df.empty:
            return self.fail("One or both loaded datasets are empty.")

        def task():
            try:
                return suggest_keys(self._master_df, self._upload_df)
            except Exception as e:
                # 🔴 CRITICAL: Proper logging for unexpected worker errors
                logger.exception("Unexpected error during key detection.")
                raise

        def on_complete(keys):
            if not keys:
                self.notify("Detection Failed", "Could not automatically identify matching keys.", "warning")
                return
                
            self.mappingReady.emit(json.dumps({"suggestedKeys": list(keys)}))
            self.notify("Auto-Detection Complete", f"Identified matching key(s): {', '.join(keys)}", "info")

        self.async_runner.run_async("detect_keys", task, on_complete)

    def validate(self, keys_json):
        if self._master_df is None or self._upload_df is None:
            return self.fail("Cannot run validation without active Master and Upload datasets.")

        # 🔴 CRITICAL: Validate external inputs before processing
        if not keys_json:
            return self.fail("No mapping keys provided for validation.")

        try:
            keys = json.loads(keys_json)
            if not isinstance(keys, list) or len(keys) == 0:
                raise ValueError("Keys must be a non-empty list.")
        except json.JSONDecodeError as je:
            logger.error(f"Failed to parse keys JSON: {je}")
            return self.fail("Invalid mapping format received from the interface.")
        except ValueError as ve:
            logger.error(str(ve))
            return self.fail(str(ve))

        def task():
            try:
                mm, um, records, k = compare(self._master_df, self._upload_df, keys)
                
                if records is None:
                    records = []
                    
                insights = validation_insights(records) or {}
                
                payload = {
                    "total": len(self._upload_df),
                    # 🔴 CRITICAL: Use dict.get() safely to prevent KeyErrors
                    "correct": sum(1 for r in records if r.get("status") == "CORRECT"),
                    "review": sum(1 for r in records if r.get("status") == "REVIEW"),
                    "errors": sum(1 for r in records if r.get("status") == "ERROR"),
                    "attention": insights.get("attention", 0),
                    "rows": records
                }
                return records, json.dumps(payload)
                
            except KeyError as ke:
                logger.exception(f"Missing expected column during comparison: {ke}")
                raise ValueError(f"Data format error. Missing expected column: {ke}")
            except Exception as e:
                logger.exception("Unexpected error during validation comparison.")
                raise

        def on_complete(result):
            records, payload = result
            self._compare_records = records
            self.validationReady.emit(payload)
            self.notify("Comparison Complete", "Validation inspection ready.", "success")

        self.async_runner.run_async("validate_compare", task, on_complete)

    def detail(self, index, diff_only):
        try:
            # 🔴 CRITICAL: Prevent IndexError and validate data existence
            if not self._compare_records:
                raise ValueError("No comparison records available to detail.")
                
            if not (0 <= index < len(self._compare_records)):
                raise IndexError(f"Out-of-bounds detail index requested: {index}")
                
            self.detailReady.emit(json.dumps(self._compare_records[index]))
            
        except IndexError as ie:
            logger.error(str(ie))
            self.fail("Invalid record index requested.")
        except ValueError as ve:
            logger.warning(str(ve))
            self.fail(str(ve))
        except Exception as e:
            logger.exception("Unexpected error extracting detail view.")
            self.fail(e)
