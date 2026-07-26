import sys, os, json, logging
from pathlib import Path
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from core.common import read_table, map_columns, json_value
from core.store_validator import compare, suggest_keys, validation_insights
from core.csv_repair import inspect_csv, apply_mapping, keep_unresolved, save_repaired, unresolved_extras, keep_issue_as_is, create_record_from_extras, refresh_audit, preview_rows
from core.mapping_store import MappingStore
from core.health import profile, statistic
from core.explorer import run_sql
from core.file_creator import review_dataframe, normalize_identifier, creator_validate, export_creator

BASE = Path(sys._MEIPASS) if getattr(sys,"frozen",False) else Path(__file__).resolve().parent
LOG_DIR = Path(os.getenv("LOCALAPPDATA",str(Path.home()))) / "StoreDataAssistant" / "logs"
LOG_DIR.mkdir(parents=True,exist_ok=True)
logging.basicConfig(filename=LOG_DIR/"StoreDataAssistant.log",level=logging.INFO,format="%(asctime)s %(levelname)s %(message)s")

class Backend(QObject):
    messageChanged=Signal(); errorRaised=Signal(str); mappingReady=Signal(str); validationReady=Signal(str); detailReady=Signal(str)
    repairReady=Signal(str); healthReady=Signal(str); statsReady=Signal(str); tableReady=Signal(str); singleReviewReady=Signal(str); creatorReady=Signal(str)
    def __init__(self):
        super().__init__(); self._message="Ready"; self.master=self.upload=self.data=self.result=None; self.single_review=None; self.single_review_path=""; self.records=[]; self.repair_audit=None; self.mapping_store=MappingStore(); self.key_fields=[]
    @Property(str,notify=messageChanged)
    def message(self): return self._message
    def say(self,text): self._message=str(text); self.messageChanged.emit()
    def fail(self,error): logging.exception(str(error)); self.say(str(error)); self.errorRaised.emit(str(error))
    def _local(self,path):
        url=QUrl(path); return url.toLocalFile() if url.isLocalFile() else path
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
            if self.master is None or self.upload is None: raise ValueError("Load both files first.")
            self.mappingReady.emit(json.dumps({"master":map_columns(self.master.columns),"upload":map_columns(self.upload.columns),"suggestedKeys":suggest_keys(self.master,self.upload)}));self.say("Column mapping complete")
        except Exception as e:self.fail(e)
    @Slot(str)
    def validate(self,key_json=""):
        try:
            if self.master is None or self.upload is None: raise ValueError("Load both files first.")
            keys=json.loads(key_json) if key_json else suggest_keys(self.master,self.upload);_,_,self.records,self.key_fields=compare(self.master,self.upload,keys)
            rows=[{**{k:r[k] for k in ("row","sid","storeName","status","problem")},"categories":r.get("categories",[])} for r in self.records];intel=validation_insights(self.records)
            self.validationReady.emit(json.dumps({"total":len(rows),"correct":sum(r["status"]=="CORRECT" for r in rows),"review":sum(r["status"]=="REVIEW" for r in rows),"errors":sum(r["status"]=="ERROR" for r in rows),"rows":rows,"keyFields":self.key_fields,"insights":intel["groups"],"attention":intel["attention"]}));self.say("Validation complete — matching is key-based, not row-position-based")
        except Exception as e:self.fail(e)
    @Slot(int,bool)
    def detail(self,index,differences_only):
        try:
            if not 0<=index<len(self.records): return
            rec=self.records[index];rows=rec["comparisons"]
            if differences_only: rows=[r for r in rows if r["severity"]!="OK"]
            self.detailReady.emit(json.dumps({"missingMaster":"not found in Master" in rec["problem"],"sid":rec["sid"],"rows":rows,"problem":rec["problem"],"status":rec["status"],"context":rec["context"]}))
        except Exception as e:self.fail(e)
    def _emit_repair(self):
        refresh_audit(self.repair_audit);data={k:v for k,v in self.repair_audit.items() if k!="logical"};data["previewRows"]=preview_rows(self.repair_audit);self.repairReady.emit(json.dumps(data,default=str))
    @Slot(str)
    def inspectRepair(self,path):
        try:self.repair_audit=inspect_csv(self._local(path));self._emit_repair();self.say(f"Inspection complete: {self.repair_audit['unresolved']} issue(s) need review")
        except Exception as e:self.fail(e)
    @Slot(int,int,str,bool)
    def applyRepairMapping(self,issue_idx,col_idx,target,remember):
        try:
            if self.repair_audit is None: raise ValueError("Inspect a file first.")
            value=self.repair_audit["issues"][issue_idx]["columns"][col_idx]["detected"];apply_mapping(self.repair_audit,issue_idx,col_idx,target)
            if remember:self.mapping_store.remember(value,target)
            self._emit_repair();self.say(f"Mapped '{value}' → {target} in reviewed copy")
        except Exception as e:self.fail(e)
    @Slot(int,int)
    def keepRepairUnresolved(self,issue_idx,col_idx):
        try:keep_unresolved(self.repair_audit,issue_idx,col_idx);self._emit_repair();self.say("Value kept unresolved")
        except Exception as e:self.fail(e)
    @Slot(int)
    def keepRepairIssue(self,issue_idx):
        try:keep_issue_as_is(self.repair_audit,issue_idx);self._emit_repair();self.say("Whole record kept for explicit review")
        except Exception as e:self.fail(e)
    @Slot(int,str)
    def createRepairRecord(self,issue_idx,mapping_json):
        try:create_record_from_extras(self.repair_audit,issue_idx,json.loads(mapping_json or "{}"));self._emit_repair();self.say("New record created — verify it in Repaired Data Preview before export")
        except Exception as e:self.fail(e)
    @Slot(str,str)
    def repair(self,src,dst):
        try:
            if self.repair_audit is None: raise ValueError("Inspect a file first.")
            refresh_audit(self.repair_audit)
            if self.repair_audit["unresolved"]: raise ValueError(f"{self.repair_audit['unresolved']} unresolved repair item(s) remain. Resolve them before clean export.")
            dest=self._local(dst)
            if not dest.lower().endswith(".csv"):dest+=".csv"
            save_repaired(self.repair_audit,dest);self.say("Clean reviewed CSV saved; original unchanged")
        except Exception as e:self.fail(e)
    def _single_report(self):
        report=review_dataframe(self.single_review);report["total"]=int(len(self.single_review));report["structuralFindings"]=[]
        p=Path(self.single_review_path)
        if p.suffix.lower() in (".csv",".txt",".tsv"):
            try:
                audit=inspect_csv(p)
                for x in audit.get("issues",[]):
                    if x.get("status")!="AUTO FIXED": report["structuralFindings"].append({"row":x.get("line","?"),"severity":x.get("status","REVIEW"),"problem":x.get("problem","")+" — "+x.get("diagnosis","")})
            except Exception as e: report["structuralFindings"].append({"row":"?","severity":"REVIEW","problem":f"Structural parser: {e}"})
        report["issueCount"]+=len(report["structuralFindings"]);return report
    @Slot(str)
    def reviewSingleFile(self,path):
        try:self.single_review_path=self._local(path);self.single_review=read_table(self.single_review_path);report=self._single_report();self.singleReviewReady.emit(json.dumps(report,default=str));self.say(f"Single-file review complete: {report['issueCount']} finding(s) need attention")
        except Exception as e:self.fail(e)
    @Slot(str,int)
    def normalizeSingleIdentifier(self,field,width):
        try:
            if self.single_review is None: raise ValueError("Choose and analyze a file first.")
            mapping=map_columns(self.single_review.columns);column=mapping.get(field,{}).get("column","")
            if not column and field in self.single_review.columns:column=field
            if not column:raise ValueError(f"{field} column could not be detected.")
            before=self.single_review[column].astype(str).tolist();self.single_review[column]=self.single_review[column].map(lambda v:normalize_identifier(v,width));after=self.single_review[column].astype(str).tolist();changed=sum(a!=b for a,b in zip(before,after));report=self._single_report();report.setdefault("structuralFindings",[]).insert(0,{"row":"Preview","severity":"CHANGED" if changed else "OK","problem":f"{field}: {changed} value(s) padded to width {width}. Export Reviewed Copy to save these changes."});self.singleReviewReady.emit(json.dumps(report,default=str));self.say(f"Preview updated — {changed} {field} value(s) padded")
        except Exception as e:self.fail(e)
    @Slot(int)
    def normalizeSingleNielsen(self,width): self.normalizeSingleIdentifier("Nielsen Store Code",width)
    @Slot(str,str)
    def exportSingleReview(self,src,dst):
        try:
            if self.single_review is None or self.single_review_path!=self._local(src):self.single_review=read_table(self._local(src));self.single_review_path=self._local(src)
            dest=Path(self._local(dst));dest=dest if dest.suffix.lower()==".csv" else dest.with_suffix(".csv");self.single_review.to_csv(dest,index=False,encoding="utf-8-sig");self.say(f"Reviewed copy exported: {dest.name}")
        except Exception as e:self.fail(e)
    @Slot(result=str)
    def clipboardText(self):
        try:
            app=QGuiApplication.instance();return app.clipboard().text() if app else ""
        except Exception as e:self.fail(e);return ""
    @Slot(str)
    def validateCreator(self,rows_json):
        try:
            rows=json.loads(rows_json or "[]");findings=creator_validate(rows);self.creatorReady.emit(json.dumps({"count":len(findings),"findings":findings},default=str));self.say("Creator validation complete" if not findings else f"Creator validation found {len(findings)} value(s) to review")
        except Exception as e:self.fail(e)
    @Slot(str,str)
    def exportCreator(self,rows_json,dst):
        try:
            rows=json.loads(rows_json or "[]");findings=creator_validate(rows)
            if findings:raise ValueError(f"Fix {len(findings)} invalid value(s) before export.")
            path=export_creator(rows,self._local(dst));self.say(f"Store CSV exported: {Path(path).name}")
        except Exception as e:self.fail(e)
    @Slot(str)
    def loadData(self,path):
        try:self.data=read_table(self._local(path));self.result=None;self.healthReady.emit(json.dumps(profile(self.data),default=str));self.emit_table(self.data);self.say(f"Dataset loaded: {len(self.data):,} rows × {len(self.data.columns):,} columns")
        except Exception as e:self.fail(e)
    @Slot(str,str,str)
    def stats(self,col,op,group):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            self.statsReady.emit(json.dumps(statistic(self.data,col,op,group),default=str));self.say(f"{op} calculated for {col}")
        except Exception as e:self.fail(e)
    def emit_table(self,data):
        self.result=data;rows=[[json_value(x) for x in r] for r in data.head(1000).itertuples(index=False,name=None)];self.tableReady.emit(json.dumps({"columns":[str(c) for c in data.columns],"rows":rows,"total":int(len(data)),"displayed":len(rows)},default=str))
    @Slot(str,str)
    def search(self,text,col):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            data=self.data;term=text.strip()
            if term:
                if col and col in data.columns:mask=data[col].fillna("").astype(str).str.contains(term,case=False,regex=False)
                else:mask=data.fillna("").astype(str).apply(lambda r:r.str.contains(term,case=False,regex=False).any(),axis=1)
                data=data[mask]
            self.emit_table(data);self.say(f"Search returned {len(data):,} rows")
        except Exception as e:self.fail(e)
    @Slot(str)
    def sql(self,query):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            data=run_sql(self.data,query);self.emit_table(data);self.say(f"Query returned {len(data):,} rows")
        except Exception as e:self.fail(e)

def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE","Basic");app=QGuiApplication(sys.argv);engine=QQmlApplicationEngine();backend=Backend();engine.rootContext().setContextProperty("backend",backend);engine.addImportPath(str(BASE/"qml"));engine.load(QUrl.fromLocalFile(str(BASE/"qml"/"Main.qml")))
    if not engine.rootObjects():raise SystemExit("Main.qml failed to load")
    sys.exit(app.exec())
if __name__=="__main__":main()
