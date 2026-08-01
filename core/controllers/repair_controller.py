# core/controllers/repair_controller.py
import json
from PySide6.QtCore import QObject, Signal

from core.csv_repair import (
    inspect_csv, join_shifted_rows, apply_mapping, keep_unresolved,
    keep_issue_as_is, create_record_from_extras, delete_created_record,
    undo_last_created_action, save_repaired
)
from core.utils.helpers import local_path, free_memory
from core.utils.logger import get_logger
from core.exceptions import StoreAppException

logger = get_logger("RepairController")


class RepairController(QObject):
    repairReady = Signal(str)

    def __init__(self, async_runner, notify_cb, fail_cb):
        super().__init__()
        self.async_runner = async_runner
        self.notify = notify_cb
        self.fail = fail_cb
        self._audit = {}

    def inspect_repair(self, path):
        self._audit = {}
        free_memory()

        def task():
            return inspect_csv(local_path(path))

        def on_complete(audit_data):
            # 🔴 CRITICAL: Check for None and empty datasets safely using dict.get()
            self._audit = audit_data or {}
            issues_count = len(self._audit.get('issues', []))
            
            self.repairReady.emit(json.dumps(self._audit))
            self.notify("Repair Scan Ready", f"Detected {issues_count} potential issue(s).", "info")

        self.async_runner.run_async("inspect_repair", task, on_complete)

    def undo_repair_action(self):
        try:
            # 🔴 CRITICAL: Validate data exists before operating
            if not self._audit or not self._audit.get('history'):
                raise ValueError("No repair history available to undo.")
                
            self._audit = undo_last_created_action(self._audit)
            self.repairReady.emit(json.dumps(self._audit))
            self.notify("Action Undone", "Reverted last repair change.", "info")
            
        except ValueError as ve:
            logger.warning(f"Undo action rejected: {ve}")
            self.notify("Undo Unavailable", str(ve), "warning")
        except Exception as e:
            # 🔴 CRITICAL: Add logging.exception() for full traceback of unexpected errors
            logger.exception("Unexpected error during undo_repair_action")
            self.fail(e)

    def join_repair_rows(self, index):
        try:
            # 🔴 CRITICAL: Prevent IndexError by validating the index bounds
            issues = self._audit.get('issues', [])
            if not (0 <= index < len(issues)):
                raise IndexError(f"Invalid issue index: {index}. Total issues: {len(issues)}")
                
            self._audit = join_shifted_rows(self._audit, index)
            self.repairReady.emit(json.dumps(self._audit))
            
        except IndexError as ie:
            logger.error(str(ie))
            self.fail(ie)
        except Exception as e:
            logger.exception("Unexpected error in join_repair_rows")
            self.fail(e)

    def apply_repair_mapping(self, issue_index, col_index, target, remember):
        try:
            self._audit = apply_mapping(self._audit, issue_index, col_index, target)
            self.repairReady.emit(json.dumps(self._audit))
        except (IndexError, KeyError) as e:
            logger.error(f"Invalid mapping boundaries: {e}")
            self.fail(e)
        except Exception as e:
            logger.exception("Unexpected error in apply_repair_mapping")
            self.fail(e)

    def keep_repair_unresolved(self, issue_index, col_index):
        try:
            self._audit = keep_unresolved(self._audit, issue_index, col_index)
            self.repairReady.emit(json.dumps(self._audit))
        except Exception as e:
            logger.exception("Unexpected error in keep_repair_unresolved")
            self.fail(e)

    def keep_repair_issue(self, issue_index):
        try:
            self._audit = keep_issue_as_is(self._audit, issue_index)
            self.repairReady.emit(json.dumps(self._audit))
        except Exception as e:
            logger.exception("Unexpected error in keep_repair_issue")
            self.fail(e)

    def create_repair_record(self, issue_index, mapping_json):
        try:
            # 🔴 CRITICAL: Validate JSON inputs before parsing
            if not mapping_json:
                raise ValueError("Received empty mapping data from UI.")
                
            mapping = json.loads(mapping_json)
            self._audit = create_record_from_extras(self._audit, issue_index, mapping)
            self.repairReady.emit(json.dumps(self._audit))
            
        except json.JSONDecodeError as je:
            logger.error(f"Failed to parse mapping JSON: {je}")
            self.fail("Invalid mapping format received from the interface.")
        except Exception as e:
            logger.exception("Unexpected error in create_repair_record")
            self.fail(e)

    def delete_repair_record(self, record_id):
        try:
            self._audit = delete_created_record(self._audit, record_id)
            self.repairReady.emit(json.dumps(self._audit))
        except KeyError as ke:
            logger.error(f"Attempted to delete non-existent record ID: {ke}")
            self.fail("Record not found.")
        except Exception as e:
            logger.exception("Unexpected error in delete_repair_record")
            self.fail(e)

    def repair(self, src, dst):
        if not self._audit:
            return self.notify("Export Failed", "No audit data available to save.", "warning")
            
        def task():
            save_repaired(self._audit, local_path(dst))

        self.async_runner.run_async("save_repair", task, lambda _: self.notify("Repaired File Saved", "Exported copy successfully.", "success"))
