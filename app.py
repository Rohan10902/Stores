import sys
import os
import json
import traceback
from pathlib import Path
import pandas as pd

from PySide6.QtCore import QObject, Signal, Slot, QUrl, Property, QRunnable, QThreadPool
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# Import core modules
from core.common import read_table, json_value
from core.explorer import run_sql
from core.health import profile, statistic
from core.csv_repair import (
    inspect_csv, join_shifted_rows, apply_mapping, keep_unresolved,
    keep_issue_as_is, create_record_from_extras, delete_created_record,
    undo_last_created_action, save_repaired
)
from core.store_validator import suggest_keys, compare, validation_insights
from core.file_creator import review_dataframe, creator_validate

BASE = Path(__file__).resolve().parent

# --- THREADING CLASSES ---
class WorkerSignals(QObject):
    """Defines the signals available from a running worker thread."""
    finished = Signal(object)
    error = Signal(Exception)


class Worker(QRunnable):
    """Worker thread to run long-running Python functions without freezing the UI."""
    def __init__(self, fn, *args, **kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()

    @Slot()
    def run(self):
        try:
            result = self.fn(*self.args, **self.kwargs)
            self.signals.finished.emit(result)
        except Exception as e:
            self.signals.error.emit(e)


# --- BACKEND CLASS ---
class Backend(QObject):
    # --- SIGNALS ---
    messageChanged = Signal()
    
    # Store Builder Signals
    creatorReady = Signal(str)
    creatorLoaded = Signal(str)
    
    # Explore & Health Signals
    healthReady = Signal(str)
    tableReady = Signal(str)
    statsReady = Signal(str)
    
    # Repair Signals
    repairReady = Signal(str)
    
    # Compare & Validate Signals
    mappingReady = Signal(str)
    validationReady = Signal(str)
    detailReady = Signal(str)
    
    # Single Review Signals
    singleReviewReady = Signal(str)

    def __init__(self):
        super().__init__()
        self._message = "Ready"
        self.threadpool = QThreadPool.globalInstance()
        
        # State containers
        self._df = None
        self._master_df = None
        self._upload_df = None
        self._compare_records = []
        self._audit = {}

    # --- UI MESSAGE PROPERTY ---
    @Property(str, notify=messageChanged)
    def message(self):
        return self._message

    @message.setter
    def message(self, val):
        self._message = val
        self.messageChanged.emit()

    @Slot(str)
    def say(self, text):
        self.message = str(text)
        print(text)

    def fail(self, e):
        err = f"Error: {str(e)}"
        self.message = err
        print("Backend error:", e)
        traceback.print_exc()

    def _local(self, path):
        if not path:
            return ""
        p = str(path).strip()
        if p.startswith("file:///"):
            return p[8:]
        elif p.startswith("file://"):
            return p[7:]
        return p

    # --- ASYNC HELPER ---
    def _run_async(self, func, callback_success, *args):
        """Helper to run a function in the background and call a success function when done."""
        worker = Worker(func, *args)
        worker.signals.finished.connect(callback_success)
        worker.signals.error.connect(self.fail)
        self.threadpool.start(worker)

    # --- UTILS & CLIPBOARD ---
    @Slot(result=str)
    def clipboardText(self):
        try:
            return QGuiApplication.clipboard().text() or ""
        except Exception:
            return ""

    # --- STORE BUILDER (CreateStorePage) ---
    @Slot(str, str)
    def exportCreator(self, rows_json, dst):
        self.say("Exporting...")
        def task():
            dst_path = self._local(dst)
            Path(dst_path).write_text(rows_json, encoding="utf-8")
            return Path(dst_path).name
        self._run_async(task, lambda name: self.say(f"Exported successfully to {name}"))

    @Slot(str)
    def validateCreator(self, rows_json):
        self.say("Validating rows...")
        def task():
            rows = json.loads(rows_json)
            findings = creator_validate(rows)
            return json.dumps({"count": len(findings), "findings": findings}), len(findings)
            
        def on_complete(result):
            payload, count = result
            self.creatorReady.emit(payload)
            self.say(f"Validation complete: {count} findings.")
            
        self._run_async(task, on_complete)

    @Slot(str)
    def loadCreatorFile(self, path):
        self.say("Importing file...")
        def task():
            local = self._local(path)
            df = read_table(local)
            headers = [str(c) for c in df.columns]
            rows = [{headers[i]: json_value(v) for i, v in enumerate(row)}
                    for row in df.itertuples(index=False, name=None)]
            payload = json.dumps({"headers": headers, "rows": rows}, default=str)
            return payload, len(rows), Path(local).name
            
        def on_complete(result):
            payload, count, name = result
            self.creatorLoaded.emit(payload)
            self.say(f"Imported {count} row(s) from {name}")
            
        self._run_async(task, on_complete)

    # --- EXPLORE & HEALTH (ExplorePage, HealthPage) ---
    @Slot(str)
    def loadData(self, path):
        self.say("Loading dataset (this may take a moment)...")
        def task():
            local = self._local(path)
            df = read_table(local)
            prof = profile(df)
            df_view = df.head(1000).fillna("")
            table_data = {
                "columns": [str(c) for c in df_view.columns],
                "rows": df_view.head(100).to_dict(orient="records"),
                "total": len(df),
                "displayed": len(df_view),
                "truncated": len(df) > 1000
            }
            return df, json.dumps(prof), json.dumps(table_data)

        def on_complete(result):
            self._df, prof_json, table_json = result
            self.healthReady.emit(prof_json)
            self.tableReady.emit(table_json)
            self.say(f"Loaded {len(self._df)} rows.")

        self._run_async(task, on_complete)

    @Slot(str, str)
    def search(self, query, col):
        if self._df is None:
            return
        self.say("Searching...")
        def task():
            if not query:
                res_df = self._df
            else:
                if col and col != "All columns" and col in self._df.columns:
                    res_df = self._df[self._df[col].astype(str).str.contains(query, case=False, na=False)]
                else:
                    mask = self._df.astype(str).apply(lambda x: x.str.contains(query, case=False, na=False)).any(axis=1)
                    res_df = self._df[mask]
                    
            view = res_df.head(1000).fillna("")
            return json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.head(100).to_dict(orient="records"),
                "total": len(res_df),
                "displayed": len(view)
            }), len(res_df)

        def on_complete(result):
            table_json, count = result
            self.tableReady.emit(table_json)
            self.say(f"Search found {count} matches.")

        self._run_async(task, on_complete)

    @Slot(str)
    def sql(self, query):
        if self._df is None:
            return
        self.say("Executing SQL...")
        def task():
            res_df = run_sql(self._df, query)
            view = res_df.head(1000).fillna("")
            return json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.head(100).to_dict(orient="records"),
                "total": len(res_df),
                "displayed": len(view)
            })
            
        def on_complete(payload):
            self.tableReady.emit(payload)
            self.say("Query completed.")
            
        self._run_async(task, on_complete)

    @Slot(str, str, str)
    def stats(self, col, op, group):
        if self._df is None:
            return
        self.say("Generating statistics...")
        def task():
            return json.dumps(statistic(self._df, col, op, group))
            
        def on_complete(payload):
            self.statsReady.emit(payload)
            self.say("Statistics generated.")
            
        self._run_async(task, on_complete)

    # --- RECORD REPAIR (RepairPage) ---
    @Slot(str)
    def inspectRepair(self, path):
        self.say("Inspecting CSV...")
        def task():
            return inspect_csv(self._local(path))
            
        def on_complete(audit_data):
            self._audit = audit_data
            self.repairReady.emit(json.dumps(self._audit))
            self.say(f"Inspection complete: {len(self._audit.get('issues', []))} issues found.")
            
        self._run_async(task, on_complete)

    @Slot()
    def undoRepairAction(self):
        try:
            self._audit = undo_last_created_action(self._audit)
            self.repairReady.emit(json.dumps(self._audit))
            self.say("Undid last repair action.")
        except Exception as e:
            self.fail(e)

    @Slot(int)
    def joinRepairRows(self, index):
        try:
            self._audit = join_shifted_rows(self._audit, index)
            self.repairReady.emit(json.dumps(self._audit))
            self.say("Rows joined successfully.")
        except Exception as e:
            self.fail(e)

    @Slot(int, int, str, bool)
    def applyRepairMapping(self, issue_index, col_index, target, remember):
        try:
            self._audit = apply_mapping(self._audit, issue_index, col_index, target)
            self.repairReady.emit(json.dumps(self._audit))
            self.say("Mapping applied.")
        except Exception as e:
            self.fail(e)

    @Slot(int, int)
    def keepRepairUnresolved(self, issue_index, col_index):
        try:
            self._audit = keep_unresolved(self._audit, issue_index, col_index)
            self.repairReady.emit(json.dumps(self._audit))
        except Exception as e:
            self.fail(e)

    @Slot(int)
    def keepRepairIssue(self, issue_index):
        try:
            self._audit = keep_issue_as_is(self._audit, issue_index)
            self.repairReady.emit(json.dumps(self._audit))
        except Exception as e:
            self.fail(e)

    @Slot(int, str)
    def createRepairRecord(self, issue_index, mapping_json):
        try:
            mapping = json.loads(mapping_json)
            self._audit = create_record_from_extras(self._audit, issue_index, mapping)
            self.repairReady.emit(json.dumps(self._audit))
            self.say("New record created from overflow.")
        except Exception as e:
            self.fail(e)

    @Slot(int)
    def deleteRepairRecord(self, record_id):
        try:
            self._audit = delete_created_record(self._audit, record_id)
            self.repairReady.emit(json.dumps(self._audit))
            self.say("Record deleted.")
        except Exception as e:
            self.fail(e)

    @Slot(str, str)
    def repair(self, src, dst):
        self.say("Saving repaired file...")
        def task():
            save_repaired(self._audit, self._local(dst))
        self._run_async(task, lambda _: self.say("Repaired CSV saved successfully."))

    # --- COMPARE & VALIDATE (ComparePage) ---
    @Slot(str)
    def loadMaster(self, path):
        self.say("Loading Master file...")
        def task():
            return read_table(self._local(path))
        def on_complete(df):
            self._master_df = df
            self.say(f"Master file loaded ({len(df)} rows)")
        self._run_async(task, on_complete)

    @Slot(str)
    def loadUpload(self, path):
        self.say("Loading Upload file...")
        def task():
            return read_table(self._local(path))
        def on_complete(df):
            self._upload_df = df
            self.say(f"Upload file loaded ({len(df)} rows)")
        self._run_async(task, on_complete)

    @Slot()
    def detect(self):
        if self._master_df is None or self._upload_df is None:
            return self.fail("Both Master and Upload files must be loaded.")
        self.say("Auto-detecting matching keys...")
        def task():
            return suggest_keys(self._master_df, self._upload_df)
        def on_complete(keys):
            self.mappingReady.emit(json.dumps({"suggestedKeys": list(keys)}))
            self.say(f"Auto-detected keys: {', '.join(keys)}")
        self._run_async(task, on_complete)

    @Slot(str)
    def validate(self, keys_json):
        self.say("Comparing datasets...")
        def task():
            keys = json.loads(keys_json)
            mm, um, records, k = compare(self._master_df, self._upload_df, keys)
            insights = validation_insights(records)
            payload = {
                "total": len(self._upload_df),
                "correct": sum(1 for r in records if r["status"] == "CORRECT"),
                "review": sum(1 for r in records if r["status"] == "REVIEW"),
                "errors": sum(1 for r in records if r["status"] == "ERROR"),
                "attention": insights.get("attention", 0),
                "rows": records,
                "insights": insights.get("groups", [])
            }
            return records, json.dumps(payload)
            
        def on_complete(result):
            records, payload = result
            self._compare_records = records
            self.validationReady.emit(payload)
            self.say("Validation comparison complete.")
            
        self._run_async(task, on_complete)

    @Slot(int, bool)
    def detail(self, index, diff_only):
        try:
            rec = self._compare_records[index]
            self.detailReady.emit(json.dumps(rec))
        except Exception as e:
            self.fail(e)

    # --- SINGLE REVIEW (SingleReviewPage) ---
    @Slot(str)
    def reviewSingleFile(self, path):
        self.say("Analyzing file...")
        def task():
            df = read_table(self._local(path))
            res = review_dataframe(df)
            
            # Map keys cleanly to match SingleReviewPage.qml model bindings
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
            self.say(f"Analyzed {count} records.")

        self._run_async(task, on_complete)

    @Slot(str, str)
    def exportSingleReview(self, src, dst):
        self.say("Exporting copy...")
        def task():
            df = read_table(self._local(src))
            df.to_csv(self._local(dst), index=False, encoding="utf-8-sig")
        self._run_async(task, lambda _: self.say("Reviewed copy exported."))


def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(BASE / "qml" / "Main.qml")))
    
    if not engine.rootObjects():
        print("Failed to load QML root objects")
        return 1
        
    # --- CI STARTUP PROBE CHECK ---
    if os.environ.get("STORELENS_CI_STARTUP_TEST") == "1":
        print("STORELENS_STARTUP_OK")
        sys.stdout.flush()
        return 0
    # ------------------------------
    
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
