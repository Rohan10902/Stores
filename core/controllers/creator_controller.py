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
        if not rows_json:
            return self.notify("Export Failed", "No data provided to export.", "warning")

        self.say("Exporting...")
        l_path = local_path(dst)

        def task():
            try:
                target_dir = os.path.dirname(l_path)
                if target_dir and not os.path.exists(target_dir):
                    os.makedirs(target_dir, exist_ok=True)

                rows = json.loads(rows_json)
                if not isinstance(rows, list):
                    raise ValueError("Data format error. Expected a list of records.")
                    
                return export_creator(rows, l_path)
                
            except json.JSONDecodeError as je:
                logger.error(f"JSON decode error during export: {je}")
                raise ValueError("Invalid data format received from the interface.")
            except (OSError, PermissionError) as oe:
                logger.error(f"Filesystem error writing creator file: {oe}")
                raise OSError("Could not write file due to permission or disk error.")

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
                if findings is None:
                    findings = []
                    
                return json.dumps({"count": len(findings), "findings": findings}), len(findings)
                
            except json.JSONDecodeError as je:
                logger.error(f"JSON decode error during validation: {je}")
                raise ValueError("Invalid data format received from the interface.")
            except (KeyError, TypeError) as ke:
                logger.error(f"Data schema error during validation: {ke}")
                raise ValueError("Data structure mismatch during validation.")

        def on_complete(result):
            payload, count = result
            self.creatorReady.emit(payload)
            self.notify("Validation Complete", f"Found {count} item(s) requiring review.", "warning" if count else "success")

        self.async_runner.run_async("creator_validate", task, on_complete)

    def load_creator_file(self, path):
        free_memory()
        l_path = local_path(path)
        
        if not l_path or not os.path.exists(l_path):
            return self.notify("Load Failed", f"File not found at: {l_path}", "error")

        def task():
            try:
                df = read_table(l_path)
                if df is None or df.empty:
                    raise ValueError("The loaded dataset is empty or corrupted.")
                    
                headers = [str(c) for c in df.columns]
                rows = [{headers[i]: json_value(v) for i, v in enumerate(row)}
                        for row in df.itertuples(index=False, name=None)]
                        
                return json.dumps({"headers": headers, "rows": rows}, default=str), len(rows), Path(l_path).name
                
            except (ValueError, FileNotFoundError, PermissionError) as err:
                logger.error(f"Error loading creator file: {err}")
                raise

        def on_complete(result):
            payload, count, name = result
            self.creatorLoaded.emit(payload)
            self.notify("File Loaded", f"Imported {count} rows from {name}", "success")

        self.async_runner.run_async("creator_load", task, on_complete)
