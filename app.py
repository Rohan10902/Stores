import os, sys, re, csv, json, sqlite3
from pathlib import Path
from difflib import SequenceMatcher
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pandas as pd
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

FIELDS=["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions","Updated By"]
ALIASES={
"Store Name":["store name","storename","outlet name","location name","shop name"],
"SID":["sid","store id","store identifier","site id"],
"Banner":["banner","brand","retailer banner","chain"],
"Nielsen Store Code":["nielsen store code","nielsen store","nielsen code","nielsen id"],
"Trip Received":["trip received","trip received date","received date"],
"Last Trip":["last trip","last trip date","last visit"],
"Address 1":["address 1","address1","address line 1","street address"],
"Address 2":["address 2","address2","address line 2"],
"Address 3":["address 3","address3","address line 3"],
"ZIP":["zip","zip code","postal code","postcode","pin","pincode"],
"Active / Inactive":["active inactive","active / inactive","active","status"],
"Is Census":["is census","census","census flag"],
"Is Exceptions":["is exceptions","is exception","exceptions","exception flag"],
"Updated By":["updated by","updatedby","last updated","updated date","updated timestamp","modified date"]}

def local_path(p):
    s=str(p or "")
    if s.startswith("file:///"): return QUrl(s).toLocalFile()
    return s

def clean(s):
    s=str(s or "").strip().lower()
    s=re.sub(r"[_\-/]+"," ",s); s=re.sub(r"[^a-z0-9 ]+","",s)
    return re.sub(r"\s+"," ",s).strip()

def sval(v):
    if pd.isna(v): return ""
    return str(v)

def norm(v): return re.sub(r"\s+"," ",sval(v).strip().lower())

def delimiter(path):
    sample=Path(path).read_text(encoding="utf-8-sig",errors="replace")[:65536]
    try: return csv.Sniffer().sniff(sample,delimiters=",;\t|").delimiter
    except csv.Error: return ","

def read_data(path):
    p=local_path(path); ext=Path(p).suffix.lower()
    if ext in {".xlsx",".xls",".xlsm"}: return pd.read_excel(p,dtype=object)
    if ext in {".csv",".txt",".tsv"}:
        sep="\t" if ext==".tsv" else delimiter(p)
        return pd.read_csv(p,sep=sep,dtype=object,keep_default_na=False,engine="python",quotechar='"',on_bad_lines="error")
    if ext==".json":
        try: return pd.read_json(p)
        except ValueError:
            with open(p,encoding="utf-8-sig") as f: return pd.json_normalize(json.load(f))
    if ext==".xml": return pd.read_xml(p)
    raise ValueError("Unsupported file type: "+(ext or "unknown"))

def score(field,col):
    c=clean(col); candidates=[clean(field)]+[clean(x) for x in ALIASES.get(field,[])]
    if c in candidates:return 100.0
    best=0
    for a in candidates:
        r=SequenceMatcher(None,c,a).ratio()*100
        A,C=set(a.split()),set(c.split()); u=A|C
        j=len(A&C)/len(u)*100 if u else 0
        best=max(best,r,j)
    return round(best,1)

def mapping(cols):
    out={}; used=set()
    for f in FIELDS:
        ranked=sorted([(score(f,c),str(c)) for c in cols if str(c) not in used],reverse=True)
        if ranked and ranked[0][0]>=45:
            out[f]={"column":ranked[0][1],"confidence":ranked[0][0]}; used.add(ranked[0][1])
        else: out[f]={"column":"","confidence":0}
    return out

def valid_date(v):
    if not str(v or "").strip(): return True
    try:return not pd.isna(pd.to_datetime(v,errors="coerce"))
    except:return False

def binary(v):
    s=str(v or "").strip().lower()
    if s in {"1","true","yes","y","active"}:return "1"
    if s in {"0","false","no","n","inactive"}:return "0"
    return s

class Backend(QObject):
    messageChanged=Signal(); busyChanged=Signal(); progressChanged=Signal()
    columnMappingReady=Signal(str); validationReady=Signal(str); csvInspectionReady=Signal(str); analysisReady=Signal(str); sqlResultReady=Signal(str)
    def __init__(self):
        super().__init__(); self._message="Ready"; self._busy=False; self._progress=0
        self.master=None; self.mapdf=None; self.data=None; self.mm={}; self.xm={}; self.results=[]
    @Property(str,notify=messageChanged)
    def message(self):return self._message
    @Property(bool,notify=busyChanged)
    def busy(self):return self._busy
    @Property(int,notify=progressChanged)
    def progress(self):return self._progress
    def status(self,msg,busy=False,progress=100):
        self._message=msg;self._busy=busy;self._progress=progress
        self.messageChanged.emit();self.busyChanged.emit();self.progressChanged.emit()
    def err(self,e):self.status("Error: "+str(e),False,0)
    def emit_map(self):self.columnMappingReady.emit(json.dumps({"master":self.mm,"mapping":self.xm}))
    @Slot(str)
    def loadMaster(self,p):
        try:self.master=read_data(p);self.mm=mapping(self.master.columns);self.emit_map();self.status(f"Master loaded: {len(self.master):,} rows.")
        except Exception as e:self.err(e)
    @Slot(str)
    def loadMapping(self,p):
        try:self.mapdf=read_data(p);self.xm=mapping(self.mapdf.columns);self.emit_map();self.status(f"Mapping loaded: {len(self.mapdf):,} rows.")
        except Exception as e:self.err(e)
    @Slot()
    def detectStoreColumns(self):
        try:
            if self.master is None or self.mapdf is None:raise ValueError("Select both files first.")
            self.mm=mapping(self.master.columns);self.xm=mapping(self.mapdf.columns);self.emit_map();self.status("Column detection complete.")
        except Exception as e:self.err(e)
    def val(self,row,mp,f):
        c=mp.get(f,{}).get("column","");return row.get(c,"") if c else ""
    @Slot()
    def validateStores(self):
        try:
            if self.master is None or self.mapdf is None:raise ValueError("Select both files first.")
            self.mm=mapping(self.master.columns);self.xm=mapping(self.mapdf.columns)
            ms=self.mm["SID"]["column"]; xs=self.xm["SID"]["column"]
            if not ms or not xs:raise ValueError("SID could not be identified.")
            master={}
            for _,r in self.master.iterrows():
                k=norm(r.get(ms,""))
                if k:master.setdefault(k,[]).append(r)
            counts={}
            for v in self.mapdf[xs]:
                k=norm(v)
                if k:counts[k]=counts.get(k,0)+1
            res=[];ok=rev=bad=0
            compare=["Store Name","Banner","Nielsen Store Code","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions"]
            for n,(_,r) in enumerate(self.mapdf.iterrows(),2):
                sidraw=self.val(r,self.xm,"SID");sid=norm(sidraw);problems=[];st="CORRECT";mr=None
                if not sid:st="ERROR";problems.append("SID is blank")
                elif sid not in master:st="ERROR";problems.append("SID not found in Master")
                else:
                    mr=master[sid][0]
                    if len(master[sid])>1:st="ERROR";problems.append("Duplicate SID in Master")
                if sid and counts.get(sid,0)>1:st="ERROR";problems.append("Duplicate SID in Mapping")
                if mr is not None:
                    for f in compare:
                        if not self.mm[f]["column"] or not self.xm[f]["column"]:continue
                        a=self.val(mr,self.mm,f);b=self.val(r,self.xm,f)
                        a,b=(binary(a),binary(b)) if f in {"Active / Inactive","Is Census","Is Exceptions"} else (norm(a),norm(b))
                        if a!=b:
                            if st!="ERROR":st="REVIEW"
                            problems.append(f+" mismatch")
                for f in ["Trip Received","Last Trip"]:
                    v=self.val(r,self.xm,f)
                    if str(v).strip() and not valid_date(v):
                        if st!="ERROR":st="REVIEW"
                        problems.append(f+" has invalid date")
                for f in ["Active / Inactive","Is Census","Is Exceptions"]:
                    v=self.val(r,self.xm,f)
                    if str(v).strip() and binary(v) not in {"0","1"}:
                        if st!="ERROR":st="REVIEW"
                        problems.append(f+": expected 1 or 0")
                u=self.val(r,self.xm,"Updated By")
                if str(u).strip() and not valid_date(u):
                    if st!="ERROR":st="REVIEW"
                    problems.append("Updated By has invalid date/time")
                ok+=st=="CORRECT";rev+=st=="REVIEW";bad+=st=="ERROR"
                res.append({"row":n,"sid":sval(sidraw),"storeName":sval(self.val(r,self.xm,"Store Name")),"status":st,"problem":"; ".join(problems) or "No issues"})
            self.results=res
            self.validationReady.emit(json.dumps({"total":len(res),"correct":ok,"review":rev,"errors":bad,"results":res}))
            self.status(f"Validation complete: {ok} correct, {rev} review, {bad} errors.")
        except Exception as e:self.err(e)
    @Slot(str)
    def inspectCSV(self,p):
        try:
            p=local_path(p);d=delimiter(p);issues=[];expected=None
            with open(p,encoding="utf-8-sig",errors="replace",newline="") as f:
                for n,row in enumerate(csv.reader(f,delimiter=d,quotechar='"'),1):
                    if expected is None:expected=len(row);continue
                    if len(row)!=expected:issues.append({"line":n,"expectedColumns":expected,"actualColumns":len(row),"content":d.join(row)})
            self.csvInspectionReady.emit(json.dumps({"problems":issues}));self.status(f"Inspection complete: {len(issues)} suspicious record(s).")
        except Exception as e:self.err(e)
    @Slot(str,str)
    def repairCSV(self,src,dst):
        try:
            src,dst=local_path(src),local_path(dst);d=delimiter(src)
            with open(src,encoding="utf-8-sig",errors="replace",newline="") as f:rows=list(csv.reader(f,delimiter=d,quotechar='"'))
            if not rows:raise ValueError("File is empty.")
            expected=len(rows[0]);out=[rows[0]];changed=0
            for row in rows[1:]:
                if len(row)>expected:row=row[:expected-1]+[d.join(row[expected-1:])];changed+=1
                elif len(row)<expected:row=row+[""]*(expected-len(row));changed+=1
                out.append(row)
            with open(dst,"w",encoding="utf-8-sig",newline="") as f:csv.writer(f,delimiter=d,quotechar='"',quoting=csv.QUOTE_MINIMAL).writerows(out)
            self.status(f"Repaired copy saved. {len(out)-1:,} rows preserved; {changed} adjusted.")
        except Exception as e:self.err(e)
    @Slot(str)
    def loadFile(self,p):
        try:
            self.data=read_data(p);df=self.data;rows,cols=df.shape
            blankmask=df.apply(lambda c:c.apply(lambda x:pd.isna(x) or str(x).strip()==""))
            blanks=int(blankmask.sum().sum());cells=rows*cols;complete=round((1-blanks/cells)*100,2) if cells else 100
            stats=[]
            for c in df.columns:
                s=df[c];bm=s.apply(lambda x:pd.isna(x) or str(x).strip()=="");nb=int((~bm).sum());u=int(s[~bm].astype(str).nunique()) if nb else 0
                stats.append({"column":str(c),"blank":int(bm.sum()),"nonBlank":nb,"unique":u,"duplicateValues":max(nb-u,0)})
            payload={"rows":rows,"columns":cols,"completeness":complete,"duplicateRows":int(df.astype(str).duplicated().sum()),"columnStats":stats}
            self.analysisReady.emit(json.dumps(payload));self.status(f"Analysis complete: {rows:,} rows, {cols} columns.")
        except Exception as e:self.err(e)
    @Slot(str)
    def runSQL(self,q):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            cmd=(re.match(r"^\s*([A-Za-z]+)",q or "") or [None,""])[1].lower()
            if cmd not in {"select","with","pragma","explain"}:raise ValueError("SQL is read-only. Use SELECT/WITH.")
            con=sqlite3.connect(":memory:")
            try:self.data.to_sql("data",con,index=False,if_exists="replace");r=pd.read_sql_query(q,con)
            finally:con.close()
            r=r.head(5000);rows=[{str(k):sval(v) for k,v in x.items()} for x in r.to_dict("records")]
            self.sqlResultReady.emit(json.dumps({"columns":[str(c) for c in r.columns],"rows":rows}));self.status(f"SQL returned {len(rows):,} row(s).")
        except Exception as e:self.err(e)
    @Slot(str)
    def exportValidationReport(self,p):
        try:
            if not self.results:raise ValueError("Run validation first.")
            p=local_path(p);df=pd.DataFrame(self.results)
            if Path(p).suffix.lower()==".csv":df.to_csv(p,index=False,encoding="utf-8-sig")
            else:
                if not p.lower().endswith(".xlsx"):p+=".xlsx"
                df.to_excel(p,index=False)
            self.status("Validation report exported.")
        except Exception as e:self.err(e)
    @Slot(str)
    def exportCurrentData(self,p):
        try:
            if self.data is None:raise ValueError("Load a dataset first.")
            p=local_path(p);ext=Path(p).suffix.lower()
            if ext==".csv":self.data.to_csv(p,index=False,encoding="utf-8-sig")
            elif ext==".json":self.data.to_json(p,orient="records",indent=2,force_ascii=False)
            else:
                if ext!=".xlsx":p+=".xlsx"
                self.data.to_excel(p,index=False)
            self.status("Dataset exported.")
        except Exception as e:self.err(e)

def resource(name):return os.path.join(getattr(sys,"_MEIPASS",os.path.dirname(os.path.abspath(__file__))),name)
def main():
    app=QGuiApplication(sys.argv);engine=QQmlApplicationEngine();backend=Backend()
    engine.rootContext().setContextProperty("backend",backend);engine.load(QUrl.fromLocalFile(resource("Main.qml")))
    if not engine.rootObjects():return 1
    return app.exec()
if __name__=="__main__":raise SystemExit(main())
