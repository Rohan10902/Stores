import sys, os, re, csv, json, sqlite3
from pathlib import Path
from collections import Counter
from difflib import SequenceMatcher
import pandas as pd
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

FIELDS=["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions","Updated By"]
ALIASES={
"Store Name":["store name","outlet name","shop name","location name"],"SID":["sid","store id","store identifier"],
"Banner":["banner","retail banner","brand","chain"],"Nielsen Store Code":["nielsen store code","nielsen code","nielsen id","nielsen store"],
"Trip Received":["trip received","trip received date","received date"],"Last Trip":["last trip","last trip date","previous trip date"],
"Address 1":["address 1","address1","street address","address line 1"],"Address 2":["address 2","address2","address line 2","address line two"],
"Address 3":["address 3","address3","address line 3","address line three"],"ZIP":["zip","zip code","postal code","postcode","pin","pincode"],
"Active / Inactive":["active inactive","active / inactive","store active","active flag"],"Is Census":["is census","census","census flag"],
"Is Exceptions":["is exceptions","is exception","exceptions","exception flag"],"Updated By":["updated by","last updated","last updated timestamp","updated timestamp"]}

def path(v):
    s=str(v or "")
    return QUrl(s).toLocalFile() if s.startswith("file:") else s
def n(s): return re.sub(r"[^a-z0-9]+"," ",str(s or "").lower()).strip()
def v(x):
    if pd.isna(x): return ""
    if isinstance(x,float) and x.is_integer(): return str(int(x))
    return str(x).strip()
def read(p):
    p=path(p); e=Path(p).suffix.lower()
    if e in (".xlsx",".xls",".xlsm"): return pd.read_excel(p,dtype=object)
    if e==".json":
        x=json.loads(Path(p).read_text(encoding="utf-8-sig"))
        return pd.json_normalize(x if isinstance(x,list) else x)
    if e==".xml": return pd.read_xml(p)
    if e in (".csv",".txt",".tsv"):
        sep="\t" if e==".tsv" else None
        return pd.read_csv(p,sep=sep,engine="python",dtype=object)
    raise ValueError("Unsupported file type")
def mapping(cols):
    out={}; used=set()
    for f in FIELDS:
        best=("",0)
        for c in cols:
            if c in used: continue
            cn=n(c); score=max([1 if cn==n(t) else .93 if cn and (cn in n(t) or n(t) in cn) else SequenceMatcher(None,cn,n(t)).ratio() for t in [f]+ALIASES.get(f,[])])
            if score>best[1]: best=(c,score)
        if best[1]>=.55: used.add(best[0]); out[f]={"column":str(best[0]),"confidence":round(best[1]*100,1)}
        else: out[f]={"column":"","confidence":round(best[1]*100,1)}
    return out
def dateok(x):
    if not v(x): return True
    try: pd.to_datetime(v(x),errors="raise"); return True
    except: return False
def binary(x): return v(x).lower() in ("","0","1","0.0","1.0","true","false","yes","no")
def js(x):
    if pd.isna(x): return ""
    if isinstance(x,pd.Timestamp): return x.isoformat(sep=" ")
    try: return x.item()
    except: return x

class Backend(QObject):
    messageChanged=Signal(); columnMappingReady=Signal(str); validationReady=Signal(str); comparisonDetailReady=Signal(str)
    csvInspectionReady=Signal(str); analysisReady=Signal(str); statisticsReady=Signal(str); sqlResultReady=Signal(str); errorRaised=Signal(str)
    def __init__(self):
        super().__init__(); self._message="Ready"; self.master=None; self.upload=None; self.mm={}; self.um={}; self.valid=[]; self.data=None; self.result=None
    @Property(str,notify=messageChanged)
    def message(self): return self._message
    def msg(self,s): self._message=s; self.messageChanged.emit()
    def err(self,e): self.msg(str(e)); self.errorRaised.emit(str(e))
    @Slot(str)
    def loadMaster(self,p):
        try:self.master=read(p);self.mm=mapping(self.master.columns);self.msg(f"Master loaded: {len(self.master)} rows")
        except Exception as e:self.err(e)
    @Slot(str)
    def loadMapping(self,p):
        try:self.upload=read(p);self.um=mapping(self.upload.columns);self.msg(f"Uploaded file loaded: {len(self.upload)} rows")
        except Exception as e:self.err(e)
    @Slot()
    def detectStoreColumns(self):
        try:
            if self.master is None or self.upload is None: raise ValueError("Load both files first")
            self.mm=mapping(self.master.columns);self.um=mapping(self.upload.columns)
            self.columnMappingReady.emit(json.dumps({"master":self.mm,"mapping":self.um}));self.msg("Column detection complete")
        except Exception as e:self.err(e)
    def get(self,row,m,f):
        c=m.get(f,{}).get("column",""); return v(row[c]) if c and c in row.index else ""
    @Slot()
    def validateStores(self):
        try:
            if self.master is None or self.upload is None: raise ValueError("Load both files first")
            self.mm=mapping(self.master.columns);self.um=mapping(self.upload.columns)
            mc=self.mm["SID"]["column"]; uc=self.um["SID"]["column"]
            if not mc or not uc: raise ValueError("SID could not be detected")
            lookup={}
            for _,r in self.master.iterrows():
                sid=v(r[mc])
                if sid and sid not in lookup: lookup[sid]=r
            counts=Counter(v(x) for x in self.upload[uc] if v(x)); self.valid=[]; summary=[]
            for ix,r in self.upload.iterrows():
                sid=v(r[uc]); mr=lookup.get(sid); comp=[]; problems=[]
                if counts[sid]>1: problems.append("Duplicate SID in uploaded file")
                if mr is None:
                    status="ERROR"; problems.append("SID not found in Master")
                    for f in FIELDS: comp.append({"field":f,"master":"","uploaded":self.get(r,self.um,f),"result":"MISSING MASTER","severity":"ERROR"})
                else:
                    for f in FIELDS:
                        a,b=self.get(mr,self.mm,f),self.get(r,self.um,f); sev="OK"; res="MATCH"; note=""
                        if f in ("Active / Inactive","Is Census","Is Exceptions") and not binary(b): sev,res,note="ERROR","INVALID","expected 1 or 0"
                        elif f in ("Trip Received","Last Trip") and not dateok(b): sev,res,note="ERROR","INVALID","invalid date"
                        elif f=="Updated By" and b and not dateok(b): sev,res,note="REVIEW","REVIEW","unrecognized timestamp"
                        elif a.casefold()!=b.casefold(): sev,res="REVIEW","DIFFERENT"
                        if sev!="OK": problems.append(f"{f}: {note or 'mismatch'}")
                        comp.append({"field":f,"master":a,"uploaded":b,"result":res,"severity":sev})
                    status="ERROR" if any(x["severity"]=="ERROR" for x in comp) or counts[sid]>1 else ("REVIEW" if any(x["severity"]=="REVIEW" for x in comp) else "CORRECT")
                rec={"row":int(ix)+2,"sid":sid,"storeName":self.get(r,self.um,"Store Name"),"status":status,"problem":"; ".join(problems) or "No differences","comparisons":comp}
                self.valid.append(rec); summary.append({k:rec[k] for k in ("row","sid","storeName","status","problem")})
            self.validationReady.emit(json.dumps({"total":len(summary),"correct":sum(x["status"]=="CORRECT" for x in summary),"review":sum(x["status"]=="REVIEW" for x in summary),"errors":sum(x["status"]=="ERROR" for x in summary),"results":summary}))
            self.msg("Validation complete")
        except Exception as e:self.err(e)
    @Slot(int,bool)
    def getComparisonDetail(self,i,diff):
        if 0<=i<len(self.valid):
            rows=self.valid[i]["comparisons"]; rows=[x for x in rows if x["severity"]!="OK"] if diff else rows
            self.comparisonDetailReady.emit(json.dumps({"rows":rows}))
    @Slot(str)
    def exportValidationReport(self,p):
        try:
            p=path(p); rows=[]
            for r in self.valid:
                for c in r["comparisons"]: rows.append({"Row":r["row"],"SID":r["sid"],"Store Name":r["storeName"],"Field":c["field"],"Master Value":c["master"],"Uploaded Value":c["uploaded"],"Result":c["result"]})
            d=pd.DataFrame(rows)
            if p.lower().endswith(".csv"): d.to_csv(p,index=False)
            else:
                if not p.lower().endswith(".xlsx"):p+=".xlsx"
                d.to_excel(p,index=False)
            self.msg("Comparison report exported")
        except Exception as e:self.err(e)
    def inspect(self,p):
        p=path(p); raw=Path(p).read_text(encoding="utf-8-sig",errors="replace"); lines=raw.splitlines(keepends=True)
        try: delim=csv.Sniffer().sniff(raw[:12000],delimiters=",;\t|").delimiter
        except: delim=","
        header=next(csv.reader([lines[0]],delimiter=delim)); exp=len(header); logical=[]; issues=[]; buf=""; start=1
        def openq(s):
            i=c=0
            while i<len(s):
                if s[i]=='"':
                    if i+1<len(s) and s[i+1]=='"':i+=2;continue
                    c+=1
                i+=1
            return c%2==1
        for no,line in enumerate(lines,1):
            if not buf:start=no
            buf+=line
            if openq(buf):continue
            vals=next(csv.reader([buf],delimiter=delim)); logical.append((start,no,vals,buf.rstrip()))
            if no>1 and len(vals)!=exp:issues.append({"line":f"{start}-{no}" if start!=no else str(no),"expectedColumns":exp,"actualColumns":len(vals),"status":"UNRESOLVED","repair":"Column count differs from header","content":buf.rstrip()})
            elif start!=no:issues.append({"line":f"{start}-{no}","expectedColumns":exp,"actualColumns":len(vals),"status":"REPAIRED","repair":f"Combined physical lines {start}-{no} into one logical record","content":buf.rstrip()})
            buf=""
        if buf:issues.append({"line":f"{start}-{len(lines)}","expectedColumns":exp,"actualColumns":0,"status":"UNRESOLVED","repair":"Unclosed quoted field","content":buf.rstrip()})
        return {"delimiter":delim,"expected":exp,"logical":logical,"issues":issues}
    @Slot(str)
    def inspectCSV(self,p):
        try:
            x=self.inspect(p);self.csvInspectionReady.emit(json.dumps({"problems":x["issues"]}));self.msg(f"CSV inspection: {len(x['issues'])} issue(s)")
        except Exception as e:self.err(e)
    @Slot(str,str)
    def repairCSV(self,src,dst):
        try:
            x=self.inspect(src);dst=path(dst)
            if not dst.lower().endswith(".csv"):dst+=".csv"
            with open(dst,"w",newline="",encoding="utf-8-sig") as f:
                w=csv.writer(f,delimiter=x["delimiter"])
                for _,_,vals,_ in x["logical"]:
                    if len(vals)<x["expected"]:vals+=[""]*(x["expected"]-len(vals))
                    elif len(vals)>x["expected"]:vals=vals[:x["expected"]-1]+[x["delimiter"].join(vals[x["expected"]-1:])]
                    w.writerow(vals)
            self.msg("Repaired copy saved; original unchanged")
        except Exception as e:self.err(e)
    @Slot(str)
    def loadFile(self,p):
        try:self.data=read(p);self.result=None;self.profile();self.msg(f"Dataset loaded: {len(self.data)} rows × {len(self.data.columns)} columns")
        except Exception as e:self.err(e)
    def profile(self):
        d=self.data; rows,cols=d.shape; blanks=int(d.isna().sum().sum()); total=max(1,rows*cols)
        stats=[]
        for c in d.columns:
            s=d[c];num=pd.to_numeric(s,errors="coerce")
            stats.append({"column":str(c),"nonBlank":int(s.notna().sum()),"blank":int(s.isna().sum()),"unique":int(s.dropna().astype(str).nunique()),"duplicateValues":int(s.dropna().astype(str).duplicated().sum()),"numericCount":int(num.notna().sum())})
        self.analysisReady.emit(json.dumps({"rows":rows,"columns":cols,"completeness":round((1-blanks/total)*100,1),"duplicateRows":int(d.duplicated().sum()),"columnNames":[str(c) for c in d.columns],"columnStats":stats}))
    @Slot(str,str,str)
    def calculateStatistics(self,col,op,grp):
        try:
            if self.data is None:raise ValueError("Load a dataset first")
            def calc(s):
                if op=="Count":return int(s.notna().sum())
                if op=="Distinct Count":return int(s.dropna().nunique())
                if op=="Blank Count":return int(s.isna().sum())
                z=pd.to_numeric(s,errors="coerce")
                return {"Sum":z.sum(),"Average":z.mean(),"Minimum":z.min(),"Maximum":z.max(),"Median":z.median()}[op]
            rows=[]
            if grp and grp in self.data.columns:
                for k,g in self.data.groupby(grp,dropna=False):rows.append({"group":v(k) or "(blank)","value":js(calc(g[col]))})
            else:rows=[{"group":"All rows","value":js(calc(self.data[col]))}]
            self.statisticsReady.emit(json.dumps({"rows":rows},default=str));self.msg(f"{op} calculated")
        except Exception as e:self.err(e)
    def emit_table(self,d):
        self.result=d
        rows=[[js(x) for x in r] for r in d.head(2000).itertuples(index=False,name=None)]
        self.sqlResultReady.emit(json.dumps({"columns":[str(c) for c in d.columns],"rows":rows,"totalRows":len(d),"shownRows":min(len(d),2000)},default=str))
    @Slot(str,str)
    def searchData(self,text,col):
        try:
            d=self.data
            if d is None:raise ValueError("Load a dataset first")
            t=text.strip()
            if t:
                mask=d[col].fillna("").astype(str).str.contains(t,case=False,regex=False) if col in d.columns else d.fillna("").astype(str).apply(lambda r:r.str.contains(t,case=False,regex=False).any(),axis=1)
                d=d[mask]
            self.emit_table(d);self.msg(f"Search returned {len(d)} row(s)")
        except Exception as e:self.err(e)
    @Slot(str)
    def runSQL(self,q):
        try:
            if self.data is None:raise ValueError("Load a dataset first")
            if not re.match(r"^(select|with)\b",q.strip(),re.I) or re.search(r"\b(insert|update|delete|drop|alter|create|attach|detach|pragma|replace|vacuum)\b",q,re.I):raise ValueError("Only read-only SELECT/WITH SQL is allowed")
            con=sqlite3.connect(":memory:");self.data.to_sql("data",con,index=False,if_exists="replace");d=pd.read_sql_query(q,con);con.close();self.emit_table(d);self.msg(f"Query returned {len(d)} row(s)")
        except Exception as e:self.err(e)
    @Slot(str)
    def exportCurrentData(self,p):
        try:
            d=self.result if self.result is not None else self.data;p=path(p)
            if d is None:raise ValueError("Nothing to export")
            if p.lower().endswith(".csv"):d.to_csv(p,index=False)
            elif p.lower().endswith(".json"):d.to_json(p,orient="records",indent=2)
            else:
                if not p.lower().endswith(".xlsx"):p+=".xlsx"
                d.to_excel(p,index=False)
            self.msg("Data exported")
        except Exception as e:self.err(e)

def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE","Basic")
    a=QGuiApplication(sys.argv);e=QQmlApplicationEngine();b=Backend();e.rootContext().setContextProperty("backend",b)
    base=Path(sys._MEIPASS) if getattr(sys,"frozen",False) else Path(__file__).resolve().parent
    e.load(QUrl.fromLocalFile(str(base/"Main.qml")))
    if not e.rootObjects():raise SystemExit("Main.qml failed to load")
    sys.exit(a.exec())
if __name__=="__main__":main()
