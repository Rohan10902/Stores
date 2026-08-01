# core/controllers/review_controller.py
import json
from PySide6.QtCore import QObject, Signal

from core.common import read_table
from core.file_creator import review_dataframe
from core.utils.helpers import local_path, free_memory


class ReviewController(QObject):
    singleReviewReady = Signal(str)

    def __init__(self, async_runner, notify_cb):
        super().__init__()
        self.async_runner = async_runner
        self.notify = notify_cb

    def review_single_file(self, path):
        free_memory()

        def task():
            df = read_table(local_path(path))
            res = review_dataframe(df)
            payload = {
                "totalRecords": res.get("recordCount", len(df)),
                "attentionCount": res.get("issueCount", 0),
                "previewColumns": [str(c) for c in df.columns],
                "previewRows": df.head(100).fillna("").to_dict(orient="records"),
                "findings": [{"message": f"Row {r['row']}: {'; '.join(r['issues'])}"} for r in res.get("rows", []) if r.get("issues")]
            }
            return json.dumps(payload), len(df)

        def on_complete(result):
            payload, count = result
            self.singleReviewReady.emit(payload)
            self.notify("Analysis Ready", f"Reviewed {count:,} store records.", "info")

        self.async_runner.run_async("review_single", task, on_complete)

    def export_single_review(self, src, dst):
        def task():
            df = read_table(local_path(src))
            df.to_csv(local_path(dst), index=False, encoding="utf-8-sig")

        self.async_runner.run_async("export_single", task, lambda _: self.notify("Export Complete", "Exported reviewed copy.", "success"))
