import sys
import os
import json
import traceback
from pathlib import Path

import pandas as pd
from PySide6.QtCore import QObject, Signal, Slot, QUrl, Property
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# Import all core logic modules
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
        if not path: return ""
        return QUrl(path).toLocalFile() if path.startswith("file://") else path

    # --- UTILS & CLIPBOARD ---
    @Slot(result=str)
    def clipboardText(self):
        try:
            from PySide6.QtGui import QGuiApplication
            return QGuiApplication.clipboard().text() or ""
        except Exception:
            return ""

    # --- STORE BUILDER (CreateStorePage) ---
    @Slot(str, str)
    def exportCreator(self, rows_json, dst):
        try:
            dst_path = self._local(dst)
            rows = json.loads(rows_json)
            Path(dst_path).write_text(rows_json, encoding="utf-8")
            self.say(f"Exported successfully to {Path(dst_path).name}")
        except Exception as e:
            self.fail(e)

    @Slot(str)
    def validateCreator(self, rows_json):
        try:
            rows = json.loads(rows_json)
            findings = creator_validate(rows)
            payload = json.dumps({"count": len(findings), "findings": findings})
            self.creatorReady.emit(payload)
            self.say(f"Validation complete: {len(findings)} findings.")
        except Exception as e:
            self.fail(e)

    @Slot(str)
    def loadCreatorFile(self, path):
        try:
            local = self._local(path)
            df = read_table(local)
            headers = [str(c) for c in df.columns]
            rows = [{headers[i]: json_value(v) for i, v in enumerate(row)} 
                    for row in df.itertuples(index=False, name=None)]
            payload = json.dumps({"headers": headers, "rows": rows}, default=str)
            self.creatorLoaded.emit(payload)
            self.say(f"Imported {len(rows)} row(s) from {Path(local).name}")
        except Exception as e:
            self.fail(e)

    # --- EXPLORE & HEALTH (ExplorePage, HealthPage) ---
    @Slot(str)
    def loadData(self, path):
        try:
            local = self._local(path)
            self.say("Loading data...")
            self._df = read_table(local)
            
            # Emit Health Profile
            prof = profile(self._df)
            self.healthReady.emit(json.dumps(prof))
            
            # Emit first 1000 rows for preview
            df_view = self._df.head(1000).fillna("")
            table_data = {
                "columns": [str(c) for c in df_view.columns],
                "rows": df_view.values.tolist(),
                "total": len(self._df),
                "displayed": len(df_view),
                "truncated": len(self._df) > 1000
            }
            self.tableReady.emit(json.dumps(table_data))
            self.say(f"Loaded {len(self._df)} rows.")
        except Exception as e:
            self.fail(e)

    @Slot(str, str)
    def search(self, query, col):
        if self._df is None: return
        try:
            if not query:
                res_df = self._df
            else:
                if col and col != "All columns" and col in self._df.columns:
                    res_df = self._df[self._df[col].astype(str).str.contains(query, case=False, na=False)]
                else:
                    mask = self._df.astype(str).apply(lambda x: x.str.contains(query, case=False, na=False)).any(axis=1)
                    res_df = self._df[mask]
            
            view = res_df.head(1000).fillna("")
            self.tableReady.emit(json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.values.tolist(),
                "total": len(res_df),
                "displayed": len(view)
            }))
            self.say(f"Search found {len(res_df)} matches.")
        except Exception as e:
            self.fail(e)

    @Slot(str)
    def sql(self, query):
        if self._df is None: return
        try:
            self.say("Executing SQL...")
            res_df = run_sql(self._df, query)
            view = res_df.head(1000).fillna("")
            self.tableReady.emit(json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.values.tolist(),
                "total": len(res_df),
                "displayed": len(view)
            }))
            self.say("Query completed.")
        except Exception as e:
            self.fail(e)

    @Slot(str, str, str)
    def stats(self, col, op, group):
        if self._df is None: return
        try:
            res = statistic(self._df, col, op, group)
            self.statsReady.emit(json.dumps(res))
            self.say("Statistics generated.")
        except Exception as e:
            self.fail(e)

    # --- RECORD REPAIR (RepairPage) ---
    @Slot(str)
    def inspectRepair(self, path):
        try:
            self._audit = inspect_csv(self._local(path))
            self.repairReady.emit(json.dumps(self._audit))
            self.say(f"Inspection complete: {len(self._audit.get('issues', []))} issues found.")
        except Exception as e:
            self.fail(e)

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
        try:
            save_repaired(self._audit, self._local(dst))
            self.say("Repaired CSV saved successfully.")
        except Exception as e:
            self.fail(e)

    # --- COMPARE & VALIDATE (ComparePage) ---
    @Slot(str)
    def loadMaster(self, path):
        try:
            self._master_df = read_table(self._local(path))
            self.say(f"Master file loaded ({len(self._master_df)} rows)")
        except Exception as e:
            self.fail(e)

    @Slot(str)
    def loadUpload(self, path):
        try:
            self._upload_df = read_table(self._local(path))
            self.say(f"Upload file loaded ({len(self._upload_df)} rows)")
        except Exception as e:
            self.fail(e)

    @Slot()
    def detect(self):
        if self._master_df is None or self._upload_df is None:
            return self.fail("Both Master and Upload files must be loaded.")
        try:
            keys = suggest_keys(self._master_df, self._upload_df)
            self.mappingReady.emit(json.dumps({"suggestedKeys": list(keys)}))
            self.say(f"Auto-detected keys: {', '.join(keys)}")
        except Exception as e:
            self.fail(e)

    @Slot(str)
    def validate(self, keys_json):
        try:
            keys = json.loads(keys_json)
            mm, um, records, k = compare(self._master_df, self._upload_df, keys)
            self._compare_records = records
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
            self.validationReady.emit(json.dumps(payload))
            self.say("Validation comparison complete.")
        except Exception as e:
            self.fail(e)

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
        try:
            df = read_table(self._local(path))
            res = review_dataframe(df)
            
            res["previewRows"] = df.head(100).fillna("").to_dict(orient="records")
            res["previewColumns"] = [str(c) for c in df.columns]
            
            self.singleReviewReady.emit(json.dumps(res))
            self.say(f"Analyzed {len(df)} records.")
        except Exception as e:
            self.fail(e)

    @Slot(str, str)
    def exportSingleReview(self, src, dst):
        try:
            df = read_table(self._local(src))
            df.to_csv(self._local(dst), index=False, encoding="utf-8-sig")
            self.say("Reviewed copy exported.")
        except Exception as e:
            self.fail(e)


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
    # Intercepts the CI test to emit the marker and exit without hanging
    if os.environ.get("STORELENS_CI_STARTUP_TEST") == "1":
        print("STORELENS_STARTUP_OK")
        sys.stdout.flush()
        return 0
    # ------------------------------

    return app.exec()

if __name__ == "__main__":
    sys.exit(main())
