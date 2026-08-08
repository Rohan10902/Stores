import json
from PySide6.QtCore import QObject, Slot, Signal
from ..store_validator import StoreValidator

class ValidateController(QObject):
    mappingReady = Signal(str)
    validationReady = Signal(str)
    detailReady = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.validator = StoreValidator()
        self.last_results = []

    @Slot(str)
    def load_master(self, path):
        if hasattr(self.validator, 'load_master'):
            self.validator.load_master(path)

    @Slot(str)
    def load_upload(self, path):
        if hasattr(self.validator, 'load_upload'):
            self.validator.load_upload(path)

    @Slot()
    def detect(self):
        keys = ["SID", "Nielsen Store Code"]
        if hasattr(self.validator, 'detect_keys'):
            keys = self.validator.detect_keys()
        self.mappingReady.emit(json.dumps({"suggestedKeys": keys}))

    @Slot(str)
    def validate(self, keys_json):
        keys = json.loads(keys_json)
        results_dict = {}
        if hasattr(self.validator, 'validate'):
            results_dict = self.validator.validate(keys)
        
        self.last_results = results_dict.get("rows", [])
        
        # Calculate derived insights accurately based on actual result list
        insights = []
        err_count = sum(1 for r in self.last_results if r.get("status") == "ERROR")
        rev_count = sum(1 for r in self.last_results if r.get("status") == "REVIEW")
        ok_count = sum(1 for r in self.last_results if r.get("status") == "OK")
        
        if err_count > 0:
            insights.append({"key": "err", "title": "Critical Mismatches", "count": str(err_count), "severity": "ERROR", "action": "Review errors immediately"})
        if rev_count > 0:
            insights.append({"key": "rev", "title": "Manual Review Needed", "count": str(rev_count), "severity": "WARNING", "action": "Check flagged fields"})
        if err_count == 0 and rev_count == 0 and len(self.last_results) > 0:
            insights.append({"key": "ok", "title": "Clean Validation", "count": str(ok_count), "severity": "INFO", "action": "Ready for deployment"})

        payload = {
            "total": results_dict.get("total", len(self.last_results)),
            "correct": results_dict.get("correct", ok_count),
            "review": results_dict.get("review", rev_count),
            "errors": results_dict.get("errors", err_count),
            "attention": err_count + rev_count,
            "rows": self.last_results,
            "insights": insights
        }
        self.validationReady.emit(json.dumps(payload))

    @Slot(int, bool)
    def detail(self, index, diff_only):
        if 0 <= index < len(self.last_results):
            row = self.last_results[index]
            comps = row.get("comparisons", [])
            if diff_only:
                comps = [c for c in comps if c.get("severity") in ["ERROR", "WARNING", "REVIEW"]]
            
            payload = {
                "message": row.get("message", ""),
                "status": row.get("status", ""),
                "master": row.get("master", {}),
                "upload": row.get("upload", {}),
                "diffs": row.get("diffs", 0),
                "comparisons": comps
            }
            self.detailReady.emit(json.dumps(payload))
