# core/controllers/review_controller.py
import json
import os
from PySide6.QtCore import QObject, Signal

from core.common import read_table
from core.file_creator import review_dataframe
from core.utils.helpers import local_path, free_memory
from core.utils.logger import get_logger

logger = get_logger("ReviewController")


class ReviewController(QObject):
    singleReviewReady = Signal(str)

    def __init__(self, async_runner, notify_cb):
        super().__init__()
        self.async_runner = async_runner
        self.notify = notify_cb

    def review_single_file(self, path):
        free_memory()
        l_path = local_path(path)

        # 🔴 CRITICAL: Verify file exists before opening
        if not l_path or not os.path.exists(l_path):
            return self.notify("Load Failed", f"File not found at: {l_path}", "error")

        def task():
            try:
                df = read_table(l_path)
                
                # 🔴 CRITICAL: Handle empty datasets gracefully
                if df is None or df.empty:
                    raise ValueError("The loaded dataset is empty or corrupted.")
                    
                res = review_dataframe(df)
                
                # 🔴 CRITICAL: Check for None and prevent KeyError using dict.get()
                if res is None:
                    res = {}
                    
                rows_list = res.get("rows", [])
                findings = [
                    {"message": f"Row {r.get('row', 'Unknown')}: {'; '.join(r.get('issues', []))}"} 
                    for r in rows_list if r.get("issues")
                ]

                payload = {
                    "totalRecords": res.get("recordCount", len(df)),
                    "attentionCount": res.get("issueCount", 0),
                    "previewColumns": [str(c) for c in df.columns],
                    "previewRows": df.head(100).fillna("").to_dict(orient="records"),
                    "findings": findings
                }
                return json.dumps(payload), len(df)
                
            except Exception as e:
                # 🔴 CRITICAL: Add proper logging for unexpected errors
                logger.exception("Unexpected error analyzing single file.")
                raise

        def on_complete(result):
            payload, count = result
            self.singleReviewReady.emit(payload)
            self.notify("Analysis Ready", f"Reviewed {count:,} store records.", "info")

        self.async_runner.run_async("review_single", task, on_complete)

    def export_single_review(self, src, dst):
        l_src = local_path(src)
        l_dst = local_path(dst)
        
        # 🔴 CRITICAL: Verify source file exists before reading
        if not l_src or not os.path.exists(l_src):
            return self.notify("Export Failed", "Source file not found.", "error")

        def task():
            try:
                # 🔴 CRITICAL: Verify the target directory exists before writing
                target_dir = os.path.dirname(l_dst)
                if target_dir and not os.path.exists(target_dir):
                    raise FileNotFoundError(f"Target directory does not exist: {target_dir}")

                df = read_table(l_src)
                
                # 🔴 CRITICAL: Handle empty datasets gracefully
                if df is None or df.empty:
                    raise ValueError("Source dataset is empty, nothing to export.")
                    
                df.to_csv(l_dst, index=False, encoding="utf-8-sig")
                
            except Exception as e:
                logger.exception("Unexpected error exporting single review file.")
                raise

        self.async_runner.run_async("export_single", task, lambda _: self.notify("Export Complete", "Exported reviewed copy.", "success"))
