import sys
import os
import json
import traceback
from pathlib import Path
import pandas as pd

from PySide6.QtWidgets import QApplication
from PySide6.QtCore import QObject, Signal, Slot, QUrl, Property, QRunnable, QThreadPool, Qt
from PySide6.QtQml import QQmlApplicationEngine

from core.common import read_table, json_value
from core.explorer import run_sql
from core.health import profile, statistic, export_html_report
from core.csv_repair import (
    inspect_csv, join_shifted_rows, apply_mapping, keep_unresolved,
    keep_issue_as_is, create_record_from_extras, delete_created_record,
    undo_last_created_action, save_repaired
)
from core.store_validator import suggest_keys, compare, validation_insights
from core.file_creator import review_dataframe, creator_validate

BASE = Path(__file__).resolve().parent

class WorkerSignals(QObject):
    finished = Signal(object)
    error = Signal(object)


class Worker(QRunnable):
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


class Backend(QObject):
    messageChanged = Signal()
    toastSignal = Signal(str, str, str)
    
    creatorReady = Signal(str)
    creatorLoaded = Signal(str)
    healthReady = Signal(str)
    tableReady = Signal(str)
    statsReady = Signal(str)
    repairReady = Signal(str)
    mappingReady = Signal(str)
    validationReady = Signal(str)
    detailReady = Signal(str)
    singleReviewReady = Signal(str)

    def __init__(self):
        super().__init__()
        self._message = "Ready"
        self.threadpool = QThreadPool.globalInstance()
        self._df = None
        self._master_df = None
        self._upload_df = None
        self._compare_records = []
        self._audit = {}

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

    @Slot(str, str, str)
    def notify(self, title, msg, ntype="info"):
        self.toastSignal.emit(title, msg, ntype)

    @Slot(object)
    def fail(self, e):
        err = f"Error: {str(e)}"
        self.message = err
        self.notify("Error Encountered", str(e), "error")
        traceback.print_exc()

    def _local(self, path):
        if not path: return ""
        p = str(path).strip()
        if p.startswith("file:///"): return p[8:]
        elif p.startswith("file://"): return p[7:]
        return p

    def _run_async(self, func, callback_success, *args):
        worker = Worker(func, *args)
        worker.signals.finished.connect(callback_success, Qt.QueuedConnection)
        worker.signals.error.connect(self.fail, Qt.QueuedConnection)
        self.threadpool.start(worker)

    @Slot(result=str)
    def clipboardText(self):
        try:
            return QApplication.clipboard().text() or ""
        except Exception:
            return ""

    @Slot(str, str)
    def exportCreator(self, rows_json, dst):
        self.say("Exporting...")
        def task():
            dst_path = self._local(dst)
            Path(dst_path).write_text(rows_json, encoding="utf-8")
            return Path(dst_path).name
        self._run_async(task, lambda name: self.notify("Export Complete", f"Saved to {name}", "success"))

    @Slot(str)
    def validateCreator(self, rows_json):
        def task():
            rows = json.loads(rows_json)
            findings = creator_validate(rows)
            return json.dumps({"count": len(findings), "findings": findings}), len(findings)
            
        def on_complete(result):
            payload, count = result
            self.creatorReady.emit(payload)
            self.notify("Validation Complete", f"Found {count} item(s) requiring review.", "warning" if count else "success")
            
        self._run_async(task, on_complete)

    @Slot(str)
    def loadCreatorFile(self, path):
        def task():
            local = self._local(path)
            df = read_table(local)
            headers = [str(c) for c in df.columns]
            rows = [{headers[i]: json_value(v) for i, v in enumerate(row)}
                    for row in df.itertuples(index=False, name=None)]
            return json.dumps({"headers": headers, "rows": rows}, default=str), len(rows), Path(local).name
            
        def on_complete(result):
            payload, count, name = result
            self.creatorLoaded.emit(payload)
            self.notify("File Loaded", f"Imported {count} rows from {name}", "success")
            
        self._run_async(task, on_complete)

    @Slot(str)
    def loadData(self, path):
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
            self.notify("Dataset Active", f"Loaded {len(self._df)} rows into workspace.", "info")

        self._run_async(task, on_complete)

    @Slot(str)
    def exportHealthReport(self, dst_path):
        if self._df is None:
            return self.notify("Export Failed", "No dataset active.", "warning")
        def task():
            return export_html_report(self._df, self._local(dst_path))
        self._run_async(task, lambda path: self.notify("Report Generated", f"Executive HTML report saved to {Path(path).name}", "success"))

    @Slot(str, str)
    def search(self, query, col):
        if self._df is None: return
        def task():
            df = self._df
            if query:
                if col and col != "All columns" and col in df.columns:
                    df = df[df[col].astype(str).str.contains(query, case=False, na=False)]
                else:
                    mask = df.astype(str).apply(lambda x: x.str.contains(query, case=False, na=False)).any(axis=1)
                    df = df[mask]
            view = df.head(1000).fillna("")
            return json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.head(100).to_dict(orient="records"),
                "total": len(df)
            }), len(df)

        def on_complete(result):
            table_json, count = result
            self.tableReady.emit(table_json)
            self.say(f"Search found {count} matches.")

        self._run_async(task, on_complete)

    @Slot(str)
    def sql(self, query):
        if self._df is None: return
        def task():
            res_df = run_sql(self._df, query)
            view = res_df.head(1000).fillna("")
            return json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.head(100).to_dict(orient="records"),
                "total": len(res_df)
            })
        self._run_async(task, lambda payload: self.tableReady.emit(payload))

    @Slot(str, str, str)
    def stats(self, col, op, group):
        if self._df is None: return
        def task():
            return json.dumps(statistic(self._df, col, op, group))
        self._run_async(task, lambda payload: self.statsReady.emit(payload))

    @Slot(str)
    def inspectRepair(self, path):
        def task():
            return inspect_csv(self._local(path))
        def on_complete(audit_data):
            self._audit = audit_data
            self.repairReady.emit(json.dumps(self._audit))
            self.notify("Repair Scan Ready", f"Detected {len(self._audit.get('issues', []))} potential issue(s).", "info")
        self._run_async(task, on_complete)

    @Slot()
    def undoRepairAction(self):
        try:
            self._audit = undo_last_created_action(self._audit)
            self.repairReady.emit(json.dumps(self._audit))
            self.notify("Action Undone", "Reverted last repair change.", "info")
        except Exception as e:
            self.fail(e)

    @Slot(int)
    def joinRepairRows(self, index):
        try:
            self._audit = join_shifted_rows(self._audit, index)
            self.repairReady.emit(json.dumps(self._audit))
        except Exception as e:
            self.fail(e)

    @Slot(int, int, str, bool)
    def applyRepairMapping(self, issue_index, col_index, target, remember):
        try:
            self._audit = apply_mapping(self._audit, issue_index, col_index, target)
            self.repairReady.emit(json.dumps(self._audit))
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
        except Exception as e:
            self.fail(e)

    @Slot(int)
    def deleteRepairRecord(self, record_id):
        try:
            self._audit = delete_created_record(self._audit, record_id)
            self.repairReady.emit(json.dumps(self._audit))
        except Exception as e:
            self.fail(e)

    @Slot(str, str)
    def repair(self, src, dst):
        def task():
            save_repaired(self._audit, self._local(dst))
        self._run_async(task, lambda _: self.notify("Repaired File Saved", "Exported copy successfully.", "success"))

    @Slot(str)
    def loadMaster(self, path):
        def task(): return read_table(self._local(path))
        def on_complete(df):
            self._master_df = df
            self.notify("Master Active", f"Loaded {len(df)} master stores.", "info")
        self._run_async(task, on_complete)

    @Slot(str)
    def loadUpload(self, path):
        def task(): return read_table(self._local(path))
        def on_complete(df):
            self._upload_df = df
            self.notify("Upload Active", f"Loaded {len(df)} uploaded stores.", "info")
        self._run_async(task, on_complete)

    @Slot()
    def detect(self):
        if self._master_df is None or self._upload_df is None:
            return self.fail("Both Master and Upload files must be loaded.")
        def task(): return suggest_keys(self._master_df, self._upload_df)
        def on_complete(keys):
            self.mappingReady.emit(json.dumps({"suggestedKeys": list(keys)}))
            self.notify("Auto-Detection Complete", f"Identified matching key(s): {', '.join(keys)}", "info")
        self._run_async(task, on_complete)

    @Slot(str)
    def validate(self, keys_json):
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
                "rows": records
            }
            return records, json.dumps(payload)
            
        def on_complete(result):
            records, payload = result
            self._compare_records = records
            self.validationReady.emit(payload)
            self.notify("Comparison Complete", "Validation inspection ready.", "success")
            
        self._run_async(task, on_complete)

    @Slot(int, bool)
    def detail(self, index, diff_only):
        try:
            if 0 <= index < len(self._compare_records):
                self.detailReady.emit(json.dumps(self._compare_records[index]))
        except Exception as e:
            self.fail(e)

    @Slot(str)
    def reviewSingleFile(self, path):
        def task():
            df = read_table(self._local(path))
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
            self.notify("Analysis Ready", f"Reviewed {count} store records.", "info")

        self._run_async(task, on_complete)

    @Slot(str, str)
    def exportSingleReview(self, src, dst):
        def task():
            df = read_table(self._local(src))
            df.to_csv(self._local(dst), index=False, encoding="utf-8-sig")
        self._run_async(task, lambda _: self.notify("Export Complete", "Exported reviewed copy.", "success"))


def main():
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(BASE / "qml" / "Main.qml")))
    
    if not engine.rootObjects(): return 1
    if os.environ.get("STORELENS_CI_STARTUP_TEST") == "1": return 0
    
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
