import sys, os, json, logging
from pathlib import Path
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from core.common import read_table, map_columns, json_value, norm_value
from core.store_validator import compare, suggest_keys, validation_insights
from core.csv_repair import inspect_csv, apply_mapping, keep_unresolved, save_repaired, unresolved_extras, keep_issue_as_is, create_record_from_extras, delete_created_record, undo_last_created_action, join_shifted_rows
from core.mapping_store import MappingStore
from core.health import profile, statistic
from core.explorer import run_sql
from core.file_creator import review_dataframe, normalize_nielsen, creator_validate, export_creator

BASE = Path(sys._MEIPASS) if getattr(sys, "frozen", False) else Path(__file__).resolve().parent
LOG_DIR = Path(os.getenv("LOCALAPPDATA", str(Path.home()))) / "StoreLens" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
logging.basicConfig(filename=LOG_DIR / "StoreLens.log", level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

class Backend(QObject):
    messageChanged=Signal();errorRaised=Signal(str);mappingReady=Signal(str);validationReady=Signal(str);detailReady=Signal(str);repairReady=Signal(str);healthReady=Signal(str);statsReady=Signal(str);tableReady=Signal(str);singleReviewReady=Signal(str);creatorReady=Signal(str)
    def __init__(self):
        super().__init__();self._message="Ready";self.master=self.upload=self.data=self.result=None;self.single_review=None;self.single_review_path="";self.single_review_width=0;self.records=[];self.repair_audit=None;self.mapping_store=MappingStore();self.key_fields=[]
    @Property(str,notify=messageChanged)
    def message(self):return self._message
    def say(self,text):self._message=str(text);self.messageChanged.emit()
    def fail(self,error):logging.exception(str(error));self.say(str(error));self.errorRaised.emit(str(error))
    def _local(self,path):
        url=QUrl(path);return url.toLocalFile() if url.isLocalFile() else path
    @Slot(str)
    def loadMaster(self,path):
        try:self.master=read_table(self._local(path));self.say(f"Master loaded: {len(self.master):,} rows")
        except Exception as e:self.fail(e)
    @Slot(str)
    def loadUpload(self,path):
        try:self.upload=read_table(self._local(path));self.say(f"Uploaded file loaded: {len(self.upload):,} rows")
        except Exception as e:self.fail(e)
    @Slot()
    def detect(self):
        try:
            if self.master is None or self.upload is None:raise ValueError("Load both files first.")
            suggested=suggest_keys(self.master,self.upload);self.mappingReady.emit(json.dumps({"master":map_columns(self.master.columns),"upload":map_columns(self.upload.columns),"suggestedKeys":suggested}));self.say("Column mapping complete")
        except Exception as e:self.fail(e)
    @Slot(str)
    def validate(self,key_json=""):
        try:
            if self.master is None or self.upload is None:raise ValueError("Load both files first.")
            keys=json.loads(key_json) if key_json else suggest_keys(self.master,self.upload);_,_,self.records,self.key_fields=compare(self.master,self.upload,keys);rows=[{**{k:r[k] for k in ("row","sid","storeName","status","problem")},"categories":r.get("categories",[])} for r in self.records];intel=validation_insights(self.records);self.validationReady.emit(json.dumps({"total":len(rows),"correct":sum(r["status"]=="CORRECT" for r in rows),"review":sum(r["status"]=="REVIEW" for r in rows),"errors":sum(r["status"]=="ERROR" for r in rows),"rows":rows,"keyFields":self.key_fields,"insights":intel["groups"],"attention":intel["attention"]}));self.say("Validation complete")
        except Exception as e:self.fail(e)
    @Slot(int,bool)
    def detail(self,index,differences_only):
        try:
            if not 0<=index<len(self.records):return
            rec=self.records[index];rows=rec["comparisons"]
            if differences_only:rows=[r for r in rows if r["severity"]!="OK"]
            self.detailReady.emit(json.dumps({"missingMaster":"not found in Master" in rec["problem"],"sid":rec["sid"],"rows":rows,"problem":rec["problem"],"status":rec["status"],"context":rec["context"]}))
        except Exception as e:self.fail(e)
    def _emit_repair(self):
        data={k:v for k,v in self.repair_audit.items() if k not in ("logical","undoStack")};data["previewRows"]=[dict(zip(self.repair_audit["header"],list(rec["values"])[:self.repair_audit["expected"]])) for rec in self.repair_audit["logical"][1:]];data["canUndo"]=bool(self.repair_audit.get("undoStack"));data["records"]=max(0,len(self.repair_audit["logical"])-1);self.repairReady.emit(json.dumps(data,default=str))
    @Slot(str)
    def inspectRepair(self,path):
        try:self.repair_audit=inspect_csv(self._local(path));self._emit_repair();self.say("Inspection complete")
        except Exception as e:self.fail(e)
    @Slot(int)
    def joinRepairRows(self,issue_idx):
        try:join_shifted_rows(self.repair_audit,issue_idx);self._emit_repair();self.say("Broken record joined successfully. Undo is available.")
        except Exception as e:self.fail(e)
    @Slot(int,int,str,bool)
    def applyRepairMapping(self,issue_idx,col_idx,target,remember):
        try:
            value=self.repair_audit["issues"][issue_idx]["columns"][col_idx]["detected"];apply_mapping(self.repair_audit,issue_idx,col_idx,target)
            if remember:self.mapping_store.remember(value,target)
            self._emit_repair()
        except Exception as e:self.fail(e)
    @Slot(int,int)
    def keepRepairUnresolved(self,issue_idx,col_idx):
        try:keep_unresolved(self.repair_audit,issue_idx,col_idx);self._emit_repair()
        except Exception as e:self.fail(e)
    @Slot(int)
    def keepRepairIssue(self,issue_idx):
        try:keep_issue_as_is(self.repair_audit,issue_idx);self._emit_repair()
        except Exception as e:self.fail(e)
    @Slot(int,str)
    def createRepairRecord(self,issue_idx,mapping_json):
        try:create_record_from_extras(self.repair_audit,issue_idx,json.loads(mapping_json or "{}"));self._emit_repair();self.say("New line created successfully. Review it below; Delete and Undo are available.")
        except Exception as e:self.fail(e)
    @Slot(int)
    def deleteRepairRecord(self,record_id):
        try:delete_created_record(self.repair_audit,record_id);self._emit_repair();self.say(f"Created line #{record_id} deleted. Undo is available.")
        except Exception as e:self.fail(e)
    @Slot()
    def undoRepairAction(self):
        try:undo_last_created_action(self.repair_audit);self._emit_repair();self.say("Last repair action undone.")
        except Exception as e:self.fail(e)
    @Slot(str,str)
    def repair(self,src,dst):
        try:
            if self.repair_audit is None:raise ValueError("Inspect a file first.")
            pending=unresolved_extras(self.repair_audit)
            if pending:raise ValueError(f"{len(pending)} unresolved value(s) remain")
            dest=self._local(dst);dest=dest if dest.lower().endswith(".csv") else dest+".csv";save_repaired(self.repair_audit,dest);self.say("Reviewed copy saved")
        except Exception as e:self.fail(e)
    def _single_report(self,preview_width=0):
        report=review_dataframe(self.single_review);report["total"]=int(report.get("recordCount",len(self.single_review)));report["previewColumns"]=[str(c) for c in self.single_review.columns];report["previewRows"]=[[json_value(v) for v in row] for row in self.single_review.head(200).itertuples(index=False,name=None)];return report
    @Slot(str)
    def reviewSingleFile(self,path):
        try:local=self._local(path);self.single_review=read_table(local);self.single_review_path=local;self.single_review_width=0;self.singleReviewReady.emit(json.dumps(self._single_report(),default=str));self.say("Single-file analysis complete")
        except Exception as e:self.fail(e)
    @Slot(str,str)
    def exportSingleReview(self,src,dst):
        try:
            local=self._local(src)
            if self.single_review is None or self.single_review_path!=local:self.single_review=read_table(local);self.single_review_path=local
            output=self.single_review.copy();dest=Path(self._local(dst));dest=dest if dest.suffix.lower()==".csv" else dest.with_suffix(".csv");output.to_csv(dest,index=False,encoding="utf-8-sig");self.say("Reviewed copy exported")
        except Exception as e:self.fail(e)
    @Slot(result=str)
    def clipboardText(self):
        app=QGuiApplication.instance();return app.clipboard().text() if app else ""
    @Slot(str)
    def validateCreator(self,rows_json):
        try:findings=creator_validate(json.loads(rows_json or "[]"));self.creatorReady.emit(json.dumps({"count":len(findings),"findings":findings},default=str))
        except Exception as e:self.fail(e)
    @Slot(str,str)
    def exportCreator(self,rows_json,dst):
        try:
            rows=json.loads(rows_json or "[]");findings=creator_validate(rows)
            if findings:raise ValueError(f"Fix {len(findings)} invalid value(s) before export.")
            export_creator(rows,self._local(dst));self.say("Store CSV exported")
        except Exception as e:self.fail(e)
    @Slot(str)
    def loadData(self,path):
        try:self.data=read_table(self._local(path));self.healthReady.emit(json.dumps(profile(self.data),default=str));self.emit_table(self.data);self.say(f"Dataset loaded: {len(self.data):,} rows")
        except Exception as e:self.fail(e)
    @Slot(str,str,str)
    def stats(self,col,op,group):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            self.statsReady.emit(json.dumps(statistic(self.data,col,op,group),default=str))
        except Exception as e:self.fail(e)
    def emit_table(self,data):
        self.result=data;rows=[[json_value(x) for x in r] for r in data.head(1000).itertuples(index=False,name=None)];self.tableReady.emit(json.dumps({"columns":[str(c) for c in data.columns],"rows":rows,"total":int(len(data)),"displayed":len(rows)},default=str))
    @Slot(str,str)
    def search(self,text,col):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            data=self.data;term=text.strip()
            if term:mask=data[col].fillna("").astype(str).str.contains(term,case=False,regex=False) if col and col in data.columns else data.fillna("").astype(str).apply(lambda r:r.str.contains(term,case=False,regex=False).any(),axis=1);data=data[mask]
            self.emit_table(data)
        except Exception as e:self.fail(e)
    @Slot(str)
    def sql(self,query):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            self.emit_table(run_sql(self.data,query))
        except Exception as e:self.fail(e)

def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE","Basic");app=QGuiApplication(sys.argv);engine=QQmlApplicationEngine();backend=Backend();engine.rootContext().setContextProperty("backend",backend);engine.addImportPath(str(BASE/"qml"));warnings=[]
    def capture(items):
        for item in items:text=item.toString();warnings.append(text);logging.error("QML: %s",text);print("QML:",text,file=sys.stderr,flush=True)
    engine.warnings.connect(capture);engine.load(QUrl.fromLocalFile(str(BASE/"qml"/"Main.qml")))
    if not engine.rootObjects():
        print("STORELENS_QML_STARTUP_FAILED",file=sys.stderr,flush=True)
        for text in warnings:print(text,file=sys.stderr,flush=True)
        return 2
    if os.getenv("STORELENS_CI_STARTUP_TEST")=="1":app.processEvents();print("STORELENS_STARTUP_OK",flush=True);return 0
    return app.exec()

if __name__=="__main__":sys.exit(main())