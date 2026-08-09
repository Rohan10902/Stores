import json
import csv
import shutil
from PySide6.QtCore import QObject, Slot, Signal, QUrl

def _to_local_file(url_str):
    url = QUrl(url_str)
    if url.isLocalFile():
        return url.toLocalFile()
    return url_str

class ReviewController(QObject):
    singleReviewReady = Signal(str)

    def __init__(self, async_runner, notify_cb, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify_cb
        
    @Slot(str)
    def review_single_file(self, path):
        local_path = _to_local_file(path)
        findings = []
        preview_cols = []
        preview_rows = []
        total = 0
        attn = 0
        
        try:
            with open(local_path, 'r', encoding='utf-8', errors='replace') as f:
                reader = csv.reader(f)
                try:
                    preview_cols = next(reader)
                except StopIteration:
                    pass
                
                for row in reader:
                    total += 1
                    if total <= 50:
                        preview_rows.append(row)
                    
                    if len(row) != len(preview_cols):
                        findings.append({"message": f"Row {total}: Column count mismatch.", "severity": "ERROR"})
                        attn += 1
                    elif not any(row):
                        findings.append({"message": f"Row {total}: Completely empty.", "severity": "WARNING"})
                        attn += 1
                        
        except Exception as e:
            findings.append({"message": f"Failed to read file: {str(e)}", "severity": "ERROR"})
            attn += 1

        payload = {
            "totalRecords": total,
            "attentionCount": attn,
            "previewColumns": preview_cols,
            "previewRows": preview_rows,
            "findings": findings
        }
        self.singleReviewReady.emit(json.dumps(payload))
        
    @Slot(str, str)
    def export_single_review(self, src, dst):
        try:
            shutil.copy2(_to_local_file(src), _to_local_file(dst))
            if self.notify:
                self.notify("Success", "Review exported successfully.", "success")
        except Exception as e:
            if self.notify:
                self.notify("Export Failed", str(e), "error")
