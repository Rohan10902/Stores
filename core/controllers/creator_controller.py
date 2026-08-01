# core/controllers/creator_controller.py
import json
from pathlib import Path
from PySide6.QtCore import QObject, Signal

from core.common import read_table, json_value
from core.file_creator import creator_validate, export_creator
from core.utils.helpers import local_path, free_memory


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
        self.say("Exporting...")

        def task():
            rows = json.loads(rows_json)
            return export_creator(rows, local_path(dst))

        def on_complete(saved_path):
            self.creatorExported.emit(saved_path)
            self.notify("Export Complete", f"Saved to {Path(saved_path).name}", "success")

        self.async_runner.run_async("creator_export", task, on_complete)

    def validate_creator(self, rows_json):
        def task():
            rows = json.loads(rows_json)
            findings = creator_validate(rows)
            return json.dumps({"count": len(findings), "findings": findings}), len(findings)

        def on_complete(result):
            payload, count = result
            self.creatorReady.emit(payload)
            self.notify("Validation Complete", f"Found {count} item(s) requiring review.", "warning" if count else "success")

        self.async_runner.run_async("creator_validate", task, on_complete)

    def load_creator_file(self, path):
        def task():
            free_memory()
            local = local_path(path)
            df = read_table(local)
            headers = [str(c) for c in df.columns]
            rows = [{headers[i]: json_value(v) for i, v in enumerate(row)}
                    for row in df.itertuples(index=False, name=None)]
            return json.dumps({"headers": headers, "rows": rows}, default=str), len(rows), Path(local).name

        def on_complete(result):
            payload, count, name = result
            self.creatorLoaded.emit(payload)
            self.notify("File Loaded", f"Imported {count} rows from {name}", "success")

        self.async_runner.run_async("creator_load", task, on_complete)
