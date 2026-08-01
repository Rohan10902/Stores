# core/controllers/creator_controller.py
import json
import os
from pathlib import Path
from PySide6.QtCore import QObject, Signal

from core.common import read_table, json_value
from core.file_creator import creator_validate, export_creator
from core.utils.helpers import local_path, free_memory
from core.utils.logger import get_logger

logger = get_logger("CreatorController")


class CreatorController(QObject):
    creatorReady = Signal(str)
    creatorLoaded = Signal(str)
    creatorExported = Signal(str)

    def __init__(self, async_runner, notify_cb, say_cb):
        super().__init__()
        self.async_runner = async_runner
        self.notify = notify_cb
        self.say = say_cb

    def export_creator_file(self, rows_json, dst):
        # 🔴 CRITICAL: Validate external inputs before processing
        if not rows_json:
            return self.notify("Export Failed", "No data provided to export.", "warning")

        self.say("Exporting...")
        l_path = local_path(dst)

        def task():
            try:
                # 🔴 CRITICAL: Verify the target directory exists before writing
                target_dir = os.path.dirname(l_path)
                if target_dir and not os.path.exists(target_dir):
                    raise FileNotFoundError(f"Target directory does not exist: {target_dir}")

                rows = json.loads(rows_json)
                if not isinstance(rows, list):
                    raise ValueError("Data format error. Expected a list of records.")
                    
                return export_creator(rows, l_path)
                
            except json.JSONDecodeError as je:
                logger.error(f"JSON decode error during export: {je}")
                raise ValueError("Invalid data format received from the interface.")
            except Exception as e:
                # 🔴 CRITICAL: Log unexpected errors
                logger.exception("Unexpected error exporting creator file.")
                raise

        def on_complete(saved_path):
            self.creatorExported.emit(saved_path)
            self.notify("Export Complete", f"Saved to {Path(saved_path).name}", "success")

        self.async_runner.run_async("creator_export", task, on_complete)

    def validate_creator(self, rows_json):
        if not rows_json:
            return self.notify("Validation Failed", "No data to validate.", "warning")

        def task():
            try:
                rows = json.loads(rows_json)
                if not isinstance(rows, list):
                    raise ValueError("Expected a list of records for validation.")
                    
                findings = creator_validate(rows)
                
                # 🔴 CRITICAL: Safely handle findings if None is returned
                if findings is None:
                    findings = []
                    
                return json.dumps({"count": len(findings), "findings": findings}), len(findings)
                
            except json.JSONDecodeError as je:
                logger.error(f"JSON decode error during validation: {je}")
                raise ValueError("Invalid data format received from the interface.")
            except Exception as e:
                logger.exception("Unexpected error validating creator rows.")
                raise

        def on_complete(result):
            payload, count = result
            self.creatorReady.emit(payload)
            self.notify("Validation Complete", f"Found {count} item(s) requiring review.", "warning" if count else "success")

        self.async_runner.run_async("creator_validate", task, on_complete)

    def load_creator_file(self, path):
        free_memory()
        l_path = local_path(path)
        
        # 🔴 CRITICAL: Verify file exists before opening
        if not l_path or not os.path.exists(l_path):
            return self.notify("Load Failed", f"File not found at: {l_path}", "error")

        def task():
            try:
                df = read_table(l_path)
                
                # 🔴 CRITICAL: Handle empty datasets gracefully
                if df is None or df.empty:
                    raise ValueError("The loaded dataset is empty or corrupted.")
                    
                headers = [str(c) for c in df.columns]
                rows = [{headers[i]: json_value(v) for i, v in enumerate(row)}
                        for row in df.itertuples(index=False, name=None)]
                        
                return json.dumps({"headers": headers, "rows": rows}, default=str), len(rows), Path(l_path).name
                
            except Exception as e:
                logger.exception("Unexpected error loading creator file.")
                raise

        def on_complete(result):
            payload, count, name = result
            self.creatorLoaded.emit(payload)
            self.notify("File Loaded", f"Imported {count} rows from {name}", "success")

        self.async_runner.run_async("creator_load", task, on_complete)
