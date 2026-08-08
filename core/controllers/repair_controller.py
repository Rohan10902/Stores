import json
from PySide6.QtCore import QObject, Slot, Signal
from ..csv_repair import CSVRepairTool

class RepairController(QObject):
    repairReady = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.tool = CSVRepairTool()
        self.current_file = ""

    def _emit_state(self, payload):
        self.repairReady.emit(json.dumps(payload))

    @Slot(str)
    def inspect_repair(self, path):
        self.current_file = path
        self._emit_state(self.tool.inspect_csv(path))

    @Slot(int)
    def join_repair_rows(self, issue_index):
        self._emit_state(self.tool.join_shifted_rows(issue_index))

    @Slot(int, int, str, bool)
    def apply_repair_mapping(self, issue_index, col_index, target, remember):
        self._emit_state(self.tool.apply_mapping(issue_index, col_index, target, remember))

    @Slot(int, int)
    def keep_repair_unresolved(self, issue_index, col_index):
        self._emit_state(self.tool.keep_unresolved(issue_index, col_index))

    @Slot(int)
    def keep_repair_issue(self, issue_index):
        self._emit_state(self.tool.keep_issue_as_is(issue_index))

    @Slot(int, str)
    def create_repair_record(self, issue_index, mapping_json):
        self._emit_state(self.tool.create_record_from_extras(issue_index, mapping_json))

    @Slot(str)
    def delete_repair_record(self, record_id):
        try:
            idx = int(record_id)
        except ValueError:
            idx = -1
        self._emit_state(self.tool.delete_created_record(idx))

    @Slot()
    def undo_repair_action(self):
        self._emit_state(self.tool.undo_action())

    @Slot(str, str)
    def repair(self, src, dst):
        self.tool.export_csv(dst)
        if self.parent() and hasattr(self.parent(), 'notifySignal'):
            self.parent().notifySignal.emit("Success", "Repaired CSV exported successfully.", "success")
