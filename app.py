import sys, os, json, logging
from pathlib import Path
import pandas as pd
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from core.common import read_table, map_columns, json_value
from core.store_validator import compare
from core.csv_repair import inspect_csv, save_repaired
from core.health import profile, statistic
from core.explorer import run_sql

BASE=Path(sys._MEIPASS) if getattr(sys,"frozen",False) else Path(__file__).resolve().parent
(BASE/"logs").mkdir(exist_ok=True)
logging.basicConfig(filename=BASE/"logs"/"StoreDataAssistant.log",level=logging.INFO,format="%(asctime)s %(levelname)s %(message)s")

class Backend(QObject):
 messageChanged=Signal(); errorRaised=Signal(str); mappingReady=Signal(str); validationReady=Signal(str); detailReady=Signal(str); repairReady=Signal(str); healthReady=Signal(str); statsReady=Signal(str); tableReady=Signal(str)
 def __init__(self):
  super().__init__();self._message="Ready";self.master=None;self.upload=None;self.records=[];self.data=None;self.result=None
 @Property(str,notify=messageChanged)
 def message(self):return self._message
 def say(self,s):self._message=s;self.messageChanged.emit()
 def fail(self,e):logging.exception(str(e));self.say(str(e));self.errorRaised.emit(str(e))
 @Slot(str)
 def loadMaster(self,p):
  try:self.master=read_table(QUrl(p).toLocalFile());self.say(f"Master loaded: {len(self.master):,} rows")
  except Exception as e:self.fail(e)
 @Slot(str)
 def loadUpload(self,p):
  try:self.upload=read_table(QUrl(p).toLocalFile());self.say(f"Uploaded file loaded: {len(self.upload):,} rows")
  except Exception as e:self.fail(e)
 @Slot()
 def detect(self):
  try:self.mappingReady.emit(json.dumps({"master":map_columns(self.master.columns),"upload":map_columns(self.upload.columns)}));self.say("Column mapping complete")
  except Exception as e:self.fail(e)
 @Slot()
 def validate(self):
  try:
   mm,um,self.records=compare(self.master,self.upload); rows=[{k:r[k] for k in ("row","sid","storeName","status","problem")} for r in self.records]
   self.validationReady.emit(json.dumps({"total":len(rows),"correct":sum(r["status"]=="CORRECT" for r in rows),"review":sum(r["status"]=="REVIEW" for r in rows),"errors":sum(r["status"]=="ERROR" for r in rows),"rows":rows}));self.say("Validation complete")
  except Exception as e:self.fail(e)
 @Slot(int,bool)
 def detail(self,i,diff):
  if 0<=i<len(self.records):
   x=self.records[i]["comparisons"];x=[r for r in x if r["severity"]!="OK"] if diff else x;self.detailReady.emit(json.dumps(x))
 @Slot(str)
 def inspectRepair(self,p):
  try:self.repairReady.emit(json.dumps(inspect_csv(QUrl(p).toLocalFile())["issues"]));self.say("Repair inspection complete")
  except Exception as e:self.fail(e)
 @Slot(str,str)
 def repair(self,src,dst):
  try:
   s=QUrl(src).toLocalFile();d=QUrl(dst).toLocalFile()
   if not d.lower().endswith(".csv"):d+=".csv"
   save_repaired(s,d);self.say("Repaired copy saved; original unchanged")
  except Exception as e:self.fail(e)
 @Slot(str)
 def loadData(self,p):
  try:self.data=read_table(QUrl(p).toLocalFile());self.result=None;self.healthReady.emit(json.dumps(profile(self.data)));self.say(f"Dataset loaded: {len(self.data):,} rows")
  except Exception as e:self.fail(e)
 @Slot(str,str,str)
 def stats(self,col,op,group):
  try:self.statsReady.emit(json.dumps(statistic(self.data,col,op,group),default=str));self.say(f"{op} calculated")
  except Exception as e:self.fail(e)
 def emit_table(self,d):
  self.result=d;rows=[[json_value(x) for x in r] for r in d.head(1000).itertuples(index=False,name=None)]
  self.tableReady.emit(json.dumps({"columns":[str(c) for c in d.columns],"rows":rows,"total":len(d)},default=str))
 @Slot(str,str)
 def search(self,text,col):
  try:
   d=self.data;t=text.strip()
   if t:
    mask=d[col].fillna("").astype(str).str.contains(t,case=False,regex=False) if col in d.columns else d.fillna("").astype(str).apply(lambda r:r.str.contains(t,case=False,regex=False).any(),axis=1);d=d[mask]
   self.emit_table(d);self.say(f"Search returned {len(d):,} rows")
  except Exception as e:self.fail(e)
 @Slot(str)
 def sql(self,q):
  try:d=run_sql(self.data,q);self.emit_table(d);self.say(f"Query returned {len(d):,} rows")
  except Exception as e:self.fail(e)

def main():
 os.environ.setdefault("QT_QUICK_CONTROLS_STYLE","Basic")
 app=QGuiApplication(sys.argv);engine=QQmlApplicationEngine();b=Backend();engine.rootContext().setContextProperty("backend",b)
 engine.addImportPath(str(BASE/"qml"));engine.load(QUrl.fromLocalFile(str(BASE/"qml"/"Main.qml")))
 if not engine.rootObjects():raise SystemExit("Main.qml failed to load")
 sys.exit(app.exec())
if __name__=="__main__":main()
