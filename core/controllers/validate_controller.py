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
        
        raw_rows = results_dict.get("rows", [])
        self.last_results = raw_rows
        
        # Calculate actual metrics from real validator vocabulary
        err_count = sum(1 for r in raw_rows if r.get("status") == "ERROR")
        rev_count = sum(1 for r in raw_rows if r.get("status") == "REVIEW")
        ok_count = sum(1 for r in raw_rows if r.get("status") == "CORRECT")

        formatted_rows = []
        for i, r in enumerate(raw_rows):
            formatted_rows.append({
                "row": int(r.get("row", i + 1)),
                "key": str(r.get("key", "")),
                "status": str(r.get("status", "UNKNOWN")),
                "message": str(r.get("message", ""))
            })
        
        # Generate ACTUAL validation insights safely from the records
        insights = []
        if err_count > 0:
            insights.append({"key": "err", "title": "Critical Mismatches", "count": str(err_count), "severity": "ERROR", "action": "Review errors immediately"})
        if rev_count > 0:
            insights.append({"key": "rev", "title": "Manual Review Needed", "count": str(rev_count), "severity": "REVIEW", "action": "Check flagged fields"})
        if err_count == 0 and rev_count == 0 and len(raw_rows) > 0:
            insights.append({"key": "ok", "title": "Clean Validation", "count": str(ok_count), "severity": "CORRECT", "action": "Ready for deployment"})

        payload = {
            "total": int(results_dict.get("total", len(raw_rows))),
            "correct": int(results_dict.get("correct", ok_count)),
            "review": int(results_dict.get("review", rev_count)),
            "errors": int(results_dict.get("errors", err_count)),
            "attention": int(err_count + rev_count),
            "rows": formatted_rows,
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
            
            formatted_comps = []
            for c in comps:
                formatted_comps.append({
                    "field": str(c.get("field", "")),
                    "master": str(c.get("master", "")),
                    "uploaded": str(c.get("uploaded", "")),
                    "result": str(c.get("result", "")),
                    "severity": str(c.get("severity", ""))
                })

            payload = {
                "message": str(row.get("message", "")),
                "status": str(row.get("status", "")),
                "master": dict(row.get("master", {})),
                "upload": dict(row.get("upload", {})),
                "diffs": int(row.get("diffs", 0)),
                "comparisons": formatted_comps
            }
            self.detailReady.emit(json.dumps(payload))
