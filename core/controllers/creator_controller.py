import json
import csv
from PySide6.QtCore import QObject, Slot, Signal, QUrl

def _to_local_file(url_str):
    url = QUrl(url_str)
    if url.isLocalFile():
        return url.toLocalFile()
    return url_str

class CreatorController(QObject):
    creatorLoaded = Signal(str) 
    creatorReady = Signal(str)  
    creatorExported = Signal()

    def __init__(self, async_runner, notify, say, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify
        self.say = say
        self.current_headers = []
        self.current_rows = []

    @Slot(str)
    def load_creator_file(self, path):
        self.current_headers = []
        self.current_rows = []
        local_path = _to_local_file(path)
        try:
            with open(local_path, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                self.current_headers = next(reader)
                self.current_rows = [row for row in reader]
        except Exception:
            self.current_headers = ["Column 1", "Column 2", "Column 3"]
            self.current_rows = [["", "", ""]]

        payload = {
            "headers": self.current_headers, 
            "rows": self.current_rows
        }
        self.creatorLoaded.emit(json.dumps(payload))

    @Slot(str)
    def validate_creator(self, rows_json):
        rows = json.loads(rows_json)
        findings = []
        for i, row in enumerate(rows):
            if not any(row): continue 
            if len(row) > 0 and not str(row[0]).strip(): 
                findings.append({"message": f"Row {i+1}: Primary ID is empty", "severity": "ERROR"})
        
        payload = {
            "count": len(rows), 
            "findings": findings
        }
        self.creatorReady.emit(json.dumps(payload))

    @Slot(str, str)
    def export_creator_file(self, rows_json, dst):
        rows = json.loads(rows_json)
        local_dst = _to_local_file(dst)
        with open(local_dst, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(self.current_headers)
            writer.writerows(rows)
        
        self.creatorExported.emit()
        if self.notify:
            self.notify("Success", "Store records exported successfully.", "success")
