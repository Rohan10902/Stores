import sys, os, json, logging
from pathlib import Path
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from core.common import read_table, map_columns, json_value
from core.store_validator import compare, suggest_keys, validation_insights
from core.csv_repair import inspect_csv, apply_mapping, keep_unresolved, save_repaired, unresolved_extras, keep_issue_as_is, create_record_from_extras
from core.mapping_store import MappingStore
from core.health import profile, statistic
from core.explorer import run_sql
from core.file_creator import review_dataframe, creator_validate, export_creator, normalize_nielsen

BASE=Path(sys._MEIPASS) if getattr(sys,"frozen",False) else Path(__file__).resolve().parent
LOG_DIR=Path(os.getenv("LOCALAPPDATA",str(Path.home())))/"StoreDataAssistant"/"logs"
LOG_DIR.mkdir(parents=True,exist_ok=True)
logging.basicConfig(filename=LOG_DIR/"StoreDataAssistant.log",level=logging.INFO,format="%(asctime)s %(levelname)s %(message)s")

class Backend(QObject):
    messageChanged=Signal();errorRaised=Signal(str);mappingReady=Signal(str);validationReady=Signal(str)
    detailReady=Signal(str);repairReady=Signal(str);healthReady=Signal(str);statsReady=Signal(str);tableReady=Signal(str);singleReviewReady=Signal(str);creatorReady=Signal(str)
    def __init__(self):
        super().__init__();self._message="Ready";self.master=self.upload=self.data=self.result=None
        self.records=[];self.repair_audit=None;self.mapping_store=MappingStore();self.key_fields=[];self.single_df=None
    @Property(str,notify=messageChanged)
    def message(self):return self._message
    def say(self,s):self._message=str(s);self.messageChanged.emit()
    def fail(self,e):logging.exception(str(e));self.say(str(e));self.errorRaised.emit(str(e))
    def _local(self,p):
        u=QUrl(p);return u.toLocalFile() if u.isLocalFile() else p

    @Slot(str)
    def loadMaster(self,p):
        try:self.master=read_table(self._local(p));self.say(f"Master loaded: {len(self.master):,} rows")
        except Exception as e:self.fail(e)
    @Slot(str)
    def loadUpload(self,p):
        try:self.upload=read_table(self._local(p));self.say(f"Uploaded file loaded: {len(self.upload):,} rows")
        except Exception as e:self.fail(e)
    @Slot()
    def detect(self):
        try:
            if self.master is None or self.upload is None:raise ValueError("Load both files first.")
            suggested=suggest_keys(self.master,self.upload)
            self.mappingReady.emit(json.dumps({"master":map_columns(self.master.columns),"upload":map_columns(self.upload.columns),
                                               "suggestedKeys":suggested}))
            self.say("Column mapping complete")
        except Exception as e:self.fail(e)
    @Slot(str)
    def validate(self,key_json=""):
        try:
            if self.master is None or self.upload is None:raise ValueError("Load both files first.")
            keys=json.loads(key_json) if key_json else suggest_keys(self.master,self.upload)
            _,_,self.records,self.key_fields=compare(self.master,self.upload,keys)
            rows=[{**{k:r[k] for k in ("row","sid","storeName","status","problem")},
                   "categories":r.get("categories",[])} for r in self.records]
            intel=validation_insights(self.records)
            self.validationReady.emit(json.dumps({"total":len(rows),"correct":sum(r["status"]=="CORRECT" for r in rows),
                "review":sum(r["status"]=="REVIEW" for r in rows),"errors":sum(r["status"]=="ERROR" for r in rows),
                "rows":rows,"keyFields":self.key_fields,"insights":intel["groups"],"attention":intel["attention"]}))
            self.say("Validation complete — matching is key-based, not row-position-based")
        except Exception as e:self.fail(e)
    @Slot(int,bool)
    def detail(self,i,diff):
        try:
            if not(0<=i<len(self.records)):return
            rec=self.records[i];x=rec["comparisons"]
            if diff:x=[r for r in x if r["severity"]!="OK"]
            self.detailReady.emit(json.dumps({"missingMaster":"not found in Master" in rec["problem"],
                "sid":rec["sid"],"rows":x,"problem":rec["problem"],"status":rec["status"],"context":rec["context"]}))
        except Exception as e:self.fail(e)

    def _emit_repair(self):
        d={k:v for k,v in self.repair_audit.items() if k!="logical"}
        self.repairReady.emit(json.dumps(d,default=str))
    @Slot(str)
    def inspectRepair(self,p):
        try:
            self.repair_audit=inspect_csv(self._local(p));self._emit_repair()
            self.say(f"Inspection complete: {self.repair_audit['unresolved']} issue(s) need review")
        except Exception as e:self.fail(e)
    @Slot(int,int,str,bool)
    def applyRepairMapping(self,issue_idx,col_idx,target,remember):
        try:
            if self.repair_audit is None:raise ValueError("Inspect a file first.")
            value=self.repair_audit["issues"][issue_idx]["columns"][col_idx]["detected"]
            apply_mapping(self.repair_audit,issue_idx,col_idx,target)
            if remember:self.mapping_store.remember(value,target)
            self._emit_repair();self.say(f"Mapped '{value}' → {target} in reviewed copy")
        except Exception as e:self.fail(e)
    @Slot(int,int)
    def keepRepairUnresolved(self,issue_idx,col_idx):
        try:
            keep_unresolved(self.repair_audit,issue_idx,col_idx);self._emit_repair();self.say("Value kept unresolved")
        except Exception as e:self.fail(e)
    @Slot(int)
    def keepRepairIssue(self,issue_idx):
        try:
            keep_issue_as_is(self.repair_audit,issue_idx);self._emit_repair();self.say("Whole record kept for explicit review")
        except Exception as e:self.fail(e)
    @Slot(int,str)
    def createRepairRecord(self,issue_idx,mapping_json):
        try:
            mapping=json.loads(mapping_json or "{}")
            create_record_from_extras(self.repair_audit,issue_idx,mapping)
            self._emit_repair();self.say("New record candidate created from user-approved mappings")
        except Exception as e:self.fail(e)
    @Slot(str,str)
    def repair(self,src,dst):
        try:
            if self.repair_audit is None:raise ValueError("Inspect a file first.")
            pending=unresolved_extras(self.repair_audit)
            if pending:raise ValueError(f"{len(pending)} preserved extra value(s) are still unresolved. Map them before saving.")
            d=self._local(dst)
            if not d.lower().endswith(".csv"):d+=".csv"
            save_repaired(self.repair_audit,d);self.say("Reviewed copy saved; original unchanged")
        except Exception as e:self.fail(e)

    @Slot(str)
    def loadData(self,p):
        try:
            self.data=read_table(self._local(p));self.result=None;self.healthReady.emit(json.dumps(profile(self.data),default=str))
            self.emit_table(self.data);self.say(f"Dataset loaded: {len(self.data):,} rows × {len(self.data.columns):,} columns")
        except Exception as e:self.fail(e)
    @Slot(str,str,str)
    def stats(self,col,op,group):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            self.statsReady.emit(json.dumps(statistic(self.data,col,op,group),default=str));self.say(f"{op} calculated for {col}")
        except Exception as e:self.fail(e)
    def emit_table(self,d):
        self.result=d;rows=[[json_value(x) for x in r] for r in d.head(1000).itertuples(index=False,name=None)]
        self.tableReady.emit(json.dumps({"columns":[str(c) for c in d.columns],"rows":rows,"total":int(len(d)),"displayed":len(rows)},default=str))
    @Slot(str,str)
    def search(self,text,col):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            d=self.data;t=text.strip()
            if t:
                if col and col in d.columns:mask=d[col].fillna("").astype(str).str.contains(t,case=False,regex=False)
                else:mask=d.fillna("").astype(str).apply(lambda r:r.str.contains(t,case=False,regex=False).any(),axis=1)
                d=d[mask]
            self.emit_table(d);self.say(f"Search returned {len(d):,} rows")
        except Exception as e:self.fail(e)
    @Slot(str)
    def sql(self,q):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            d=run_sql(self.data,q);self.emit_table(d);self.say(f"Query returned {len(d):,} rows")
        except Exception as e:self.fail(e)

    @Slot(str)
    def reviewSingleFile(self,p):
        try:
            self.single_df=read_table(self._local(p))
            result=review_dataframe(self.single_df)
            result["total"]=len(self.single_df)
            self.singleReviewReady.emit(json.dumps(result,default=str))
            self.say(f"Single-file review complete: {result['issueCount']} record(s) need attention")
        except Exception as e:self.fail(e)

    @Slot(int)
    def normalizeSingleNielsen(self,width):
        try:
            if self.single_df is None: raise ValueError("Load a file first.")
            if "Nielsen Store Code" not in self.single_df.columns: raise ValueError("Nielsen Store Code column was not found.")
            width=max(1,int(width))
            self.single_df["Nielsen Store Code"]=self.single_df["Nielsen Store Code"].map(lambda x:normalize_nielsen(x,width))
            result=review_dataframe(self.single_df);result["total"]=len(self.single_df)
            self.singleReviewReady.emit(json.dumps(result,default=str))
            self.say(f"Nielsen Store Code preview normalized to width {width}")
        except Exception as e:self.fail(e)

    @Slot(str,str)
    def exportSingleReview(self,src,dst):
        try:
            if self.single_df is None: raise ValueError("Load a file first.")
            d=self._local(dst)
            if not d.lower().endswith(".csv"): d+=".csv"
            self.single_df.to_csv(d,index=False,encoding="utf-8-sig")
            self.say("Reviewed single-file copy exported; source unchanged")
        except Exception as e:self.fail(e)

    @Slot(result=str)
    def clipboardText(self):
        try:return QGuiApplication.clipboard().text()
        except Exception as e:self.fail(e);return ""
    @Slot(str)
    def validateCreator(self,rows_json):
        try:
            rows=json.loads(rows_json or "[]")
            findings=creator_validate(rows)
            self.creatorReady.emit(json.dumps({"findings":findings,"count":len(findings)}))
            self.say("Creator validation passed" if not findings else f"{len(findings)} creator value(s) need review")
        except Exception as e:self.fail(e)

    @Slot(str,str)
    def exportCreator(self,rows_json,dst):
        try:
            rows=json.loads(rows_json or "[]")
            findings=creator_validate(rows)
            if findings: raise ValueError(f"{len(findings)} invalid value(s) remain. Validate and correct them before export.")
            path=export_creator(rows,self._local(dst))
            self.say(f"Store CSV exported: {Path(path).name}")
        except Exception as e:self.fail(e)

def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE","Basic");app=QGuiApplication(sys.argv);engine=QQmlApplicationEngine()
    backend=Backend();engine.rootContext().setContextProperty("backend",backend);engine.addImportPath(str(BASE/"qml"))
    engine.load(QUrl.fromLocalFile(str(BASE/"qml"/"Main.qml")))
    if not engine.rootObjects():raise SystemExit("Main.qml failed to load")
    sys.exit(app.exec())
if __name__=="__main__":main()
