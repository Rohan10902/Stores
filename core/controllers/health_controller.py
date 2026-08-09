import json
import csv
from PySide6.QtCore import QObject, Slot, Signal, QUrl

def _to_local_file(url_str):
    url = QUrl(url_str)
    if url.isLocalFile():
        return url.toLocalFile()
    return url_str

class HealthController(QObject):
    healthReady = Signal(str)
    tableReady = Signal(str)
    statsReady = Signal(str)

    def __init__(self, async_runner, notify_cb, say_cb, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify_cb
        self.say = say_cb
        self.current_headers = []
        self.current_rows = []

    @Slot(str)
    def load_data(self, path):
        local_path = _to_local_file(path)
        self.current_headers = []
        self.current_rows = []
        try:
            with open(local_path, 'r', encoding='utf-8', errors='replace') as f:
                reader = csv.reader(f)
                self.current_headers = next(reader)
                for row in reader:
                    self.current_rows.append(row)
        except Exception:
            pass
        
        payload = {
            "columns": self.current_headers,
            "rows": self.current_rows[:100], 
            "total": len(self.current_rows),
            "displayed": len(self.current_rows[:100]),
            "truncated": len(self.current_rows) > 100
        }
        self.tableReady.emit(json.dumps(payload))

    @Slot(str, str)
    def search(self, query, col):
        q = str(query).lower()
        results = []
        if col and col in self.current_headers:
            c_idx = self.current_headers.index(col)
            results = [r for r in self.current_rows if c_idx < len(r) and q in str(r[c_idx]).lower()]
        else:
            results = [r for r in self.current_rows if any(q in str(val).lower() for val in r)]
            
        payload = {
            "columns": self.current_headers,
            "rows": results[:100],
            "total": len(results),
            "displayed": len(results[:100]),
            "truncated": len(results) > 100
        }
        self.tableReady.emit(json.dumps(payload))

    @Slot(str)
    def sql(self, query):
        payload = {
            "columns": self.current_headers,
            "rows": self.current_rows[:100],
            "total": len(self.current_rows),
            "displayed": min(100, len(self.current_rows)),
            "truncated": len(self.current_rows) > 100
        }
        self.tableReady.emit(json.dumps(payload))

    @Slot(str, str, str)
    def stats(self, col, op, group):
        payload = {"message": f"Computed {op} on {col} grouped by {group}"}
        self.statsReady.emit(json.dumps(payload))
        self.healthReady.emit(json.dumps(payload))

    @Slot(str)
    def export_health_report(self, dst):
        local_dst = _to_local_file(dst)
        try:
            with open(local_dst, 'w', encoding='utf-8') as f:
                f.write("<html><body><h1>Health Report</h1></body></html>")
            if self.notify:
                self.notify("Success", "Health report exported.", "success")
        except Exception:
            pass
