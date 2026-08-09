import json
from PySide6.QtCore import QObject, Slot, Signal, QUrl
from ..csv_repair import CSVRepairTool

def _to_local_file(url_str):
    url = QUrl(url_str)
    if url.isLocalFile():
        return url.toLocalFile()
    return url_str

class RepairController(QObject):
    repairReady = Signal(str)

    def __init__(self, async_runner, notify, fail, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify
        self.fail = fail
        self.tool = CSVRepairTool()
        self.current_file = ""

    def _emit_state(self, payload):
        self.repairReady.emit(json.dumps(payload))

    @Slot(str)
    def inspect_repair(self, path):
        self.current_file = _to_local_file(path)
        self._emit_state(self.tool.inspect_csv(self.current_file))

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
        self._emit_state(self.tool.delete_created_record(record_id))

    @Slot()
    def undo_repair_action(self):
        self._emit_state(self.tool.undo_action())

    @Slot(str, str)
    def repair(self, src, dst):
        src_path = _to_local_file(src)
        dst_path = _to_local_file(dst)
        
        # Load implicitly if saving a path that wasn't proactively inspected
        if not self.tool.rows or self.current_file != src_path:
            self.inspect_repair(src_path)
            
        self.tool.export_csv(dst_path)
        if self.notify:
            self.notify("Success", "Repaired CSV exported successfully.", "success")
