import json
from PySide6.QtCore import QObject, Slot, Signal, QUrl
try:
    from ..store_validator import StoreValidator
except ImportError:
    StoreValidator = None

def _to_local_file(url_str):
    url = QUrl(url_str)
    if url.isLocalFile():
        return url.toLocalFile()
    return url_str

class ValidateController(QObject):
    mappingReady = Signal(str)
    validationReady = Signal(str)
    detailReady = Signal(str)

    def __init__(self, async_runner, notify, fail, parent=None):
        super().__init__(parent)
        self.async_runner = async_runner
        self.notify = notify
        self.fail = fail
        self.validator = StoreValidator() if StoreValidator else None
        self.last_results = []

    @Slot(str)
    def load_master(self, path):
        if self.validator and hasattr(self.validator, 'load_master'):
            self.validator.load_master(_to_local_file(path))

    @Slot(str)
    def load_upload(self, path):
        if self.validator and hasattr(self.validator, 'load_upload'):
            self.validator.load_upload(_to_local_file(path))

    @Slot()
    def detect(self):
        keys = ["SID", "Nielsen Store Code"]
        if self.validator and hasattr(self.validator, 'detect_keys'):
            keys = self.validator.detect_keys()
        self.mappingReady.emit(json.dumps({"suggestedKeys": keys}))

    @Slot(str)
    def validate(self, keys_json):
        keys = json.loads(keys_json)
        results_dict = {}
        if self.validator and hasattr(self.validator, 'validate'):
            results_dict = self.validator.validate(keys)
        
        raw_rows = results_dict.get("rows", [])
        self.last_results = raw_rows
        
        # Derived insights generated in Python based strictly on payload contract
        err_count = sum(1 for r in raw_rows if str(r.get("status", "")).upper() == "ERROR")
        rev_count = sum(1 for r in raw_rows if str(r.get("status", "")).upper() == "REVIEW")
        ok_count = sum(1 for r in raw_rows if str(r.get("status", "")).upper() == "CORRECT")

        formatted_rows = []
        for i, r in enumerate(raw_rows):
            formatted_rows.append({
                "row": int(r.get("row", i + 1)),
                "key": str(r.get("key", "")),
                "status": str(r.get("status", "UNKNOWN")).upper(),
                "message": str(r.get("message", ""))
            })
        
        insights = []
        if err_count > 0:
            insights.append({"key": "ERROR", "title": "Critical Mismatches", "count": str(err_count), "severity": "ERROR", "action": "Review errors immediately"})
        if rev_count > 0:
            insights.append({"key": "REVIEW", "title": "Manual Review Needed", "count": str(rev_count), "severity": "REVIEW", "action": "Check flagged fields"})
        if err_count == 0 and rev_count == 0 and len(formatted_rows) > 0:
            insights.append({"key": "CORRECT", "title": "Clean Validation", "count": str(ok_count), "severity": "CORRECT", "action": "Ready for deployment"})

        payload = {
            "total": int(results_dict.get("total", len(formatted_rows))),
            "correct": ok_count,
            "review": rev_count,
            "errors": err_count,
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
                comps = [c for c in comps if str(c.get("severity", "")).upper() in ["ERROR", "WARNING", "REVIEW"]]
            
            formatted_comps = []
            for c in comps:
                formatted_comps.append({
                    "field": str(c.get("field", "")),
                    "master": str(c.get("master", "")),
                    "uploaded": str(c.get("uploaded", "")),
                    "result": str(c.get("result", "")),
                    "severity": str(c.get("severity", "")).upper()
                })

            payload = {
                "message": str(row.get("message", "")),
                "status": str(row.get("status", "")).upper(),
                "master": dict(row.get("master", {})),
                "upload": dict(row.get("upload", {})),
                "diffs": int(row.get("diffs", 0)),
                "comparisons": formatted_comps
            }
            self.detailReady.emit(json.dumps(payload))
