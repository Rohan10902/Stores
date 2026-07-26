import sys, os, json, logging, traceback
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
from core.file_creator import review_dataframe, normalize_nielsen, creator_validate, export_creator

BASE = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
LOG_DIR = Path(os.getenv("LOCALAPPDATA", str(Path.home()))) / "StoreDataAssistant" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "StoreDataAssistant.log"
logging.basicConfig(filename=LOG_FILE, level=logging.INFO,
                    format="%(asctime)s %(levelname)s %(message)s", force=True)

def _write_fatal(message):
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as fh:
            fh.write("\nFATAL STARTUP ERROR\n" + str(message) + "\n")
    except Exception:
        pass

class Backend(QObject):
    messageChanged = Signal(); errorRaised = Signal(str); mappingReady = Signal(str); validationReady = Signal(str)
    detailReady = Signal(str); repairReady = Signal(str); healthReady = Signal(str); statsReady = Signal(str)
    tableReady = Signal(str); singleReviewReady = Signal(str); nielsenPreviewReady = Signal(str); creatorReady = Signal(str)

    def __init__(self):
        super().__init__(); self._message="Ready"; self.master=self.upload=self.data=self.result=None
        self.single_review=None; self.single_review_path=""; self.single_nielsen_preview=None
        self.records=[]; self.repair_audit=None; self.mapping_store=MappingStore(); self.key_fields=[]

    @Property(str, notify=messageChanged)
    def message(self): return self._message
    def say(self,text): self._message=str(text); self.messageChanged.emit()
    def fail(self,error): logging.exception(str(error)); self.say(str(error)); self.errorRaised.emit(str(error))
    def _local(self,path):
        url=QUrl(path); return url.toLocalFile() if url.isLocalFile() else path

    @Slot(str)
    def loadMaster(self,path):
        try: self.master=read_table(self._local(path)); self.say(f"Master loaded: {len(self.master):,} rows")
        except Exception as e: self.fail(e)
    @Slot(str)
    def loadUpload(self,path):
        try: self.upload=read_table(self._local(path)); self.say(f"Uploaded file loaded: {len(self.upload):,} rows")
        except Exception as e: self.fail(e)
    @Slot()
    def detect(self):
        try:
            if self.master is None or self.upload is None: raise ValueError("Load both files first.")
            self.mappingReady.emit(json.dumps({"master":map_columns(self.master.columns),"upload":map_columns(self.upload.columns),"suggestedKeys":suggest_keys(self.master,self.upload)})); self.say("Column mapping complete")
        except Exception as e: self.fail(e)
    @Slot(str)
    def validate(self,key_json=""):
        try:
            if self.master is None or self.upload is None: raise ValueError("Load both files first.")
            keys=json.loads(key_json) if key_json else suggest_keys(self.master,self.upload)
            _,_,self.records,self.key_fields=compare(self.master,self.upload,keys)
            rows=[{**{k:r[k] for k in ("row","sid","storeName","status","problem")},"categories":r.get("categories",[])} for r in self.records]
            intel=validation_insights(self.records)
            self.validationReady.emit(json.dumps({"total":len(rows),"correct":sum(r["status"]=="CORRECT" for r in rows),"review":sum(r["status"]=="REVIEW" for r in rows),"errors":sum(r["status"]=="ERROR" for r in rows),"rows":rows,"keyFields":self.key_fields,"insights":intel["groups"],"attention":intel["attention"]})); self.say("Validation complete — matching is key-based, not row-position-based")
        except Exception as e: self.fail(e)
    @Slot(int,bool)
    def detail(self,index,differences_only):
        try:
            if not (0<=index<len(self.records)): return
            rec=self.records[index]; rows=rec["comparisons"]
            if differences_only: rows=[r for r in rows if r["severity"]!="OK"]
            self.detailReady.emit(json.dumps({"missingMaster":"not found in Master" in rec["problem"],"sid":rec["sid"],"rows":rows,"problem":rec["problem"],"status":rec["status"],"context":rec["context"]}))
        except Exception as e: self.fail(e)

    def _emit_repair(self): self.repairReady.emit(json.dumps({k:v for k,v in self.repair_audit.items() if k!="logical"},default=str))
    @Slot(str)
    def inspectRepair(self,path):
        try: self.repair_audit=inspect_csv(self._local(path)); self._emit_repair(); self.say(f"Inspection complete: {self.repair_audit['unresolved']} issue(s) need review")
        except Exception as e: self.fail(e)
    @Slot(int,int,str,bool)
    def applyRepairMapping(self,issue_idx,col_idx,target,remember):
        try:
            if self.repair_audit is None: raise ValueError("Inspect a file first.")
            value=self.repair_audit["issues"][issue_idx]["columns"][col_idx]["detected"]; apply_mapping(self.repair_audit,issue_idx,col_idx,target)
            if remember: self.mapping_store.remember(value,target)
            self._emit_repair(); self.say(f"Mapped '{value}' → {target} in reviewed copy")
        except Exception as e: self.fail(e)
    @Slot(int,int)
    def keepRepairUnresolved(self,issue_idx,col_idx):
        try: keep_unresolved(self.repair_audit,issue_idx,col_idx); self._emit_repair(); self.say("Value kept unresolved")
        except Exception as e: self.fail(e)
    @Slot(int)
    def keepRepairIssue(self,issue_idx):
        try: keep_issue_as_is(self.repair_audit,issue_idx); self._emit_repair(); self.say("Whole record kept for explicit review")
        except Exception as e: self.fail(e)
    @Slot(int,str)
    def createRepairRecord(self,issue_idx,mapping_json):
        try: create_record_from_extras(self.repair_audit,issue_idx,json.loads(mapping_json or "{}")); self._emit_repair(); self.say("New record candidate created from user-approved mappings")
        except Exception as e: self.fail(e)
    @Slot(str,str)
    def repair(self,src,dst):
        try:
            if self.repair_audit is None: raise ValueError("Inspect a file first.")
            pending=unresolved_extras(self.repair_audit)
            if pending: raise ValueError(f"{len(pending)} preserved extra value(s) are still unresolved. Map them before saving.")
            dest=self._local(dst); dest=dest if dest.lower().endswith(".csv") else dest+".csv"; save_repaired(self.repair_audit,dest); self.say("Reviewed copy saved; original unchanged")
        except Exception as e: self.fail(e)

    @Slot(str)
    def reviewSingleFile(self,path):
        try:
            local=self._local(path); self.single_review=read_table(local); self.single_review_path=local; self.single_nielsen_preview=None
            report=review_dataframe(self.single_review); report["total"]=int(len(self.single_review)); self.singleReviewReady.emit(json.dumps(report,default=str)); self.nielsenPreviewReady.emit(json.dumps({"rows":[],"changed":0,"unchanged":0,"width":0})); self.say(f"Single-file review complete: {report['issueCount']} row(s) need attention")
        except Exception as e: self.fail(e)

    def _nielsen_column(self):
        mapping=map_columns(self.single_review.columns); column=mapping.get("Nielsen Store Code",{}).get("column","")
        if not column: raise ValueError("Nielsen Store Code column could not be detected.")
        return column

    @Slot(int)
    def previewSingleNielsen(self,width):
        try:
            if self.single_review is None: raise ValueError("Choose and analyze a file first.")
            column=self._nielsen_column(); rows=[]; changed=0
            proposed=self.single_review[column].copy()
            for pos,(idx,value) in enumerate(self.single_review[column].items()):
                new_value=normalize_nielsen(value,width); proposed.at[idx]=new_value
                before="" if value is None else str(value); after="" if new_value is None else str(new_value); is_changed=before!=after
                if is_changed: changed+=1
                rows.append({"row":pos+2,"current":before,"proposed":after,"status":"CHANGE" if is_changed else "UNCHANGED"})
            self.single_nielsen_preview={"column":column,"width":width,"values":proposed}
            self.nielsenPreviewReady.emit(json.dumps({"rows":rows,"changed":changed,"unchanged":len(rows)-changed,"width":width},default=str)); self.say(f"Nielsen preview ready: {changed} code(s) would change")
        except Exception as e: self.fail(e)

    @Slot()
    def applySingleNielsen(self):
        try:
            if self.single_review is None or self.single_nielsen_preview is None: raise ValueError("Preview Nielsen padding first.")
            p=self.single_nielsen_preview; self.single_review[p["column"]]=p["values"]; width=p["width"]; self.single_nielsen_preview=None
            report=review_dataframe(self.single_review); report["total"]=int(len(self.single_review)); self.singleReviewReady.emit(json.dumps(report,default=str)); self.say(f"Applied Nielsen padding to reviewed copy at width {width}. Original source remains unchanged.")
        except Exception as e: self.fail(e)

    @Slot(int)
    def normalizeSingleNielsen(self,width): self.previewSingleNielsen(width)

    @Slot(str,str)
    def exportSingleReview(self,src,dst):
        try:
            if self.single_review is None or self.single_review_path!=self._local(src): self.single_review=read_table(self._local(src)); self.single_review_path=self._local(src)
            dest=Path(self._local(dst)); dest=dest if dest.suffix.lower()==".csv" else dest.with_suffix(".csv"); self.single_review.to_csv(dest,index=False,encoding="utf-8-sig"); self.say(f"Reviewed copy exported: {dest.name}")
        except Exception as e: self.fail(e)

    @Slot(result=str)
    def clipboardText(self):
        try:
            app=QGuiApplication.instance(); return app.clipboard().text() if app else ""
        except Exception as e: self.fail(e); return ""
    @Slot(str)
    def validateCreator(self,rows_json):
        try:
            findings=creator_validate(json.loads(rows_json or "[]")); self.creatorReady.emit(json.dumps({"count":len(findings),"findings":findings},default=str)); self.say("Creator validation complete" if not findings else f"Creator validation found {len(findings)} value(s) to review")
        except Exception as e: self.fail(e)
    @Slot(str,str)
    def exportCreator(self,rows_json,dst):
        try:
            rows=json.loads(rows_json or "[]"); findings=creator_validate(rows)
            if findings: raise ValueError(f"Fix {len(findings)} invalid value(s) before export.")
            path=export_creator(rows,self._local(dst)); self.say(f"Store CSV exported: {Path(path).name}")
        except Exception as e: self.fail(e)

    @Slot(str)
    def loadData(self,path):
        try: self.data=read_table(self._local(path)); self.result=None; self.healthReady.emit(json.dumps(profile(self.data),default=str)); self.emit_table(self.data); self.say(f"Dataset loaded: {len(self.data):,} rows × {len(self.data.columns):,} columns")
        except Exception as e: self.fail(e)
    @Slot(str,str,str)
    def stats(self,col,op,group):
        try:
            if self.data is None: raise ValueError("Load a dataset first.")
            self.statsReady.emit(json.dumps(statistic(self.data,col,op,group),default=str)); self.say(f"{op} calculated for {col}")
        except Exception as e: self.fail(e)
    def emit_table(self,data):
        self.result=data; rows=[[json_value(x) for x in r] for r in data.head(1000).itertuples(index=False,name=None)]; self.tableReady.emit(json.dumps({"columns":[str(c) for c in data.columns],"rows":rows,"total":int(len(data)),"displayed":len(rows)},default=str))
    @Slot(str,str)
    def search(self,text,col):
        try:
            if self.data is None: raise ValueError("Load a dataset first.")
            data=self.data; term=text.strip()
            if term:
                if col and col in data.columns: mask=data[col].fillna("").astype(str).str.contains(term,case=False,regex=False)
                else: mask=data.fillna("").astype(str).apply(lambda r:r.str.contains(term,case=False,regex=False).any(),axis=1)
                data=data[mask]
            self.emit_table(data); self.say(f"Search returned {len(data):,} rows")
        except Exception as e: self.fail(e)
    @Slot(str)
    def sql(self,query):
        try:
            if self.data is None: raise ValueError("Load a dataset first.")
            data=run_sql(self.data,query); self.emit_table(data); self.say(f"Query returned {len(data):,} rows")
        except Exception as e: self.fail(e)


def main():
    try:
        app=QGuiApplication(sys.argv); engine=QQmlApplicationEngine(); backend=Backend(); engine.rootContext().setContextProperty("backend",backend); engine.addImportPath(str(BASE/"qml"))
        errors=[]; engine.warnings.connect(lambda warnings: errors.extend(w.toString() for w in warnings)); qml=BASE/"qml"/"Main.qml"; logging.info("Loading QML from %s",qml); engine.load(QUrl.fromLocalFile(str(qml)))
        if not engine.rootObjects(): raise RuntimeError("QML failed to create root object:\n"+"\n".join(errors))
        return app.exec()
    except Exception:
        details=traceback.format_exc(); _write_fatal(details); return 1

if __name__=="__main__": sys.exit(main())