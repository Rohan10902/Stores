import sys, csv, re, json, math
from pathlib import Path
from collections import Counter
from datetime import datetime
import pandas as pd
import duckdb
from PySide6.QtCore import QObject, Signal, Slot, Property, QAbstractTableModel, QModelIndex, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

FIELDS = ["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip",
          "Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census",
          "Is Exceptions","Updated By"]

ALIASES = {
"Store Name":["store name","storename","store","shop name","outlet name","location name"],
"SID":["sid","store id","storeid","store code","outlet id","location id"],
"Banner":["banner","chain","brand","retailer banner"],
"Nielsen Store Code":["nielsen store code","nielsen code","nielsen store","nielsen id"],
"Trip Received":["trip received","trip received date","trip date","received date"],
"Last Trip":["last trip","last trip date","last received","last received date"],
"Address 1":["address 1","address1","address line 1","street","address"],
"Address 2":["address 2","address2","address line 2"],
"Address 3":["address 3","address3","address line 3"],
"ZIP":["zip","zipcode","zip code","postal code","postcode","pin code","pincode"],
"Active / Inactive":["active inactive","active / inactive","active/inactive","active flag","status"],
"Is Census":["is census","census","census flag"],
"Is Exceptions":["is exceptions","is exception","exceptions","exception flag"],
"Updated By":["updated by","last updated","updated at","last update","update timestamp"]
}

def txt(v): return "" if pd.isna(v) else str(v).strip()
def norm(v): return re.sub(r"[^a-z0-9]+"," ",txt(v).casefold()).strip()

def similarity(a,b):
    from difflib import SequenceMatcher
    return SequenceMatcher(None,norm(a),norm(b)).ratio()

def detect_mapping(columns):
    result={}
    for f in FIELDS:
        best,score=None,0
        for c in columns:
            s=max([similarity(c,f)]+[similarity(c,a) for a in ALIASES[f]])
            if s>score: best,score=c,s
        result[f] = best if score>=0.48 else None
    return result

def parse_date(v):
    s=txt(v)
    if not s: return None
    try:
        d=pd.to_datetime(s, errors="coerce", dayfirst=True)
        return None if pd.isna(d) else d
    except: return None

def read_file(path):
    p=Path(path)
    ext=p.suffix.lower()
    if ext in [".xlsx",".xls"]:
        return pd.read_excel(p, dtype=str).fillna("")
    if ext==".json":
        return pd.json_normalize(json.loads(p.read_text(encoding="utf-8-sig"))).fillna("")
    if ext==".xml":
        return pd.read_xml(p).fillna("")
    if ext in [".csv",".tsv",".txt"]:
        sep="\t" if ext==".tsv" else None
        try:
            return pd.read_csv(p, sep=sep, engine="python", dtype=str, keep_default_na=False)
        except:
            return repair_read_csv(p)[0]
    raise ValueError("Supported: CSV, TSV, TXT, XLSX, XLS, JSON, XML")

def repair_read_csv(path):
    raw=Path(path).read_text(encoding="utf-8-sig",errors="replace").splitlines()
    if not raw: return pd.DataFrame(),[]
    sample="\n".join(raw[:20])
    try: dialect=csv.Sniffer().sniff(sample, delimiters=",;\t|")
    except: dialect=csv.excel
    header=next(csv.reader([raw[0]],dialect))
    expected=len(header); rows=[]; issues=[]; buf=""; start=2
    for line_no,line in enumerate(raw[1:],2):
        candidate=(buf+"\n"+line) if buf else line
        try: vals=next(csv.reader([candidate],dialect))
        except: vals=[]
        if len(vals)<expected:
            if not buf: start=line_no
            buf=candidate; continue
        if len(vals)==expected:
            rows.append(vals); buf=""; continue
        # extra separators: preserve raw information in issue log, do not invent columns
        rows.append(vals[:expected])
        issues.append({"line":line_no,"problem":f"{len(vals)-expected} extra field(s) / possible shift",
                       "raw":candidate,"unplaced":" | ".join(vals[expected:])})
        buf=""
    if buf:
        try: vals=next(csv.reader([buf],dialect))
        except: vals=[]
        vals=(vals+[""]*expected)[:expected]
        rows.append(vals)
        issues.append({"line":start,"problem":"Incomplete/split final record","raw":buf,"unplaced":""})
    return pd.DataFrame(rows,columns=header),issues

def standardize(df):
    mp=detect_mapping(df.columns)
    out=pd.DataFrame(index=df.index)
    for f in FIELDS: out[f]=df[mp[f]].astype(str) if mp[f] else ""
    return out,mp

def row_rule_issues(row):
    p=[]
    for f in ["Trip Received","Last Trip"]:
        if txt(row.get(f)) and parse_date(row.get(f)) is None: p.append(f"{f}: invalid date")
    for f in ["Active / Inactive","Is Census","Is Exceptions"]:
        if txt(row.get(f)) not in ("","0","1"): p.append(f"{f}: expected 1 or 0")
    if txt(row.get("Updated By")) and parse_date(row.get("Updated By")) is None:
        p.append("Updated By: invalid date/time")
    if not txt(row.get("SID")): p.append("SID: missing")
    return p

def health(df):
    n=len(df); missing=int(df.replace("",pd.NA).isna().sum().sum())
    dup=int(df.duplicated().sum())
    mixed=0; outliers=0
    colstats=[]
    for c in df.columns:
        s=df[c].map(txt); non=s[s!=""]; unique=int(non.nunique()); blank=n-len(non)
        nums=pd.to_numeric(non.str.replace(",","",regex=False),errors="coerce")
        numeric_ratio=float(nums.notna().mean()) if len(non) else 0
        dates=pd.to_datetime(non,errors="coerce",dayfirst=True)
        date_ratio=float(dates.notna().mean()) if len(non) else 0
        typ="Text"
        if numeric_ratio>.85: typ="Number"
        elif date_ratio>.85: typ="Date"
        elif unique<=max(20,int(n*.02)): typ="Category"
        if .15<numeric_ratio<.85: mixed+=1
        oc=0
        if typ=="Number" and nums.notna().sum()>4:
            q1,q3=nums.quantile(.25),nums.quantile(.75); iqr=q3-q1
            oc=int(((nums<q1-1.5*iqr)|(nums>q3+1.5*iqr)).sum()); outliers+=oc
        colstats.append({"column":str(c),"type":typ,"blank":blank,"unique":unique,"outliers":oc})
    penalty=(missing/max(n*max(len(df.columns),1),1))*35+(dup/max(n,1))*20+(mixed/max(len(df.columns),1))*15+(outliers/max(n,1))*10
    return {"rows":n,"columns":len(df.columns),"missing":missing,"duplicates":dup,"mixed":mixed,
            "outliers":outliers,"score":max(0,round(100-penalty,1)),"columns_detail":colstats}

def detect_structure(path):
    p=Path(path); ext=p.suffix.lower()
    if ext in [".xlsx",".xls"]:
        raw=pd.read_excel(p,header=None,dtype=str).fillna("")
    elif ext in [".csv",".tsv",".txt"]:
        raw=pd.read_csv(p,header=None,sep=None,engine="python",dtype=str,keep_default_na=False)
    else: return "Structured / nested",85
    if raw.shape[1]==2 and raw.iloc[:,0].astype(str).nunique()>max(3,len(raw)*.6):
        return "Vertical / key-value",88
    if raw.shape[1]>=3: return "Horizontal table",94
    return "Line-by-line",80

class Backend(QObject):
    messageChanged=Signal(); dataChanged=Signal()
    def __init__(self):
        super().__init__(); self._message="Ready"; self.df=pd.DataFrame(); self.master=pd.DataFrame()
        self.store=pd.DataFrame(); self.mapping={}; self.results=[]; self.structural=[]
    @Property(str,notify=messageChanged)
    def message(self): return self._message
    def say(self,s): self._message=s; self.messageChanged.emit()

    @Slot(str,result="QVariant")
    def analyzeFile(self,path):
        try:
            path=QUrl(path).toLocalFile() if path.startswith("file:") else path
            structure,confidence=detect_structure(path)
            self.df=read_file(path); h=health(self.df)
            h["structure"]=structure; h["structureConfidence"]=confidence
            self.say(f"Analyzed {len(self.df):,} records locally")
            return h
        except Exception as e: self.say(str(e)); return {"error":str(e)}

    @Slot(str,str,result="QVariant")
    def validateStores(self,masterPath,mappingPath):
        try:
            masterPath=QUrl(masterPath).toLocalFile() if masterPath.startswith("file:") else masterPath
            mappingPath=QUrl(mappingPath).toLocalFile() if mappingPath.startswith("file:") else mappingPath
            mraw=read_file(masterPath)
            try: sraw,struct=repair_read_csv(mappingPath) if Path(mappingPath).suffix.lower()==".csv" else (read_file(mappingPath),[])
            except: sraw,struct=read_file(mappingPath),[]
            self.master,mmap=standardize(mraw); self.store,smap=standardize(sraw); self.structural=struct
            master_by={}
            for i,r in self.master.iterrows():
                sid=txt(r["SID"])
                if sid: master_by.setdefault(sid,[]).append(r)
            dup_store=Counter(self.store["SID"].map(txt))
            results=[]; correct=review=error=0
            compare=["Store Name","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions"]
            for i,r in self.store.iterrows():
                sid=txt(r["SID"]); problems=row_rule_issues(r); status="CORRECT"
                if not sid or sid not in master_by: status="ERROR"; problems.insert(0,"SID not found in Master")
                elif len(master_by[sid])>1: status="ERROR"; problems.insert(0,"Duplicate SID in Master")
                else:
                    mr=master_by[sid][0]
                    for f in compare:
                        if norm(r[f])!=norm(mr[f]): problems.append(f"{f}: mismatch")
                    if dup_store[sid]>1: problems.insert(0,"Duplicate SID in Mapping")
                    if problems: status="REVIEW"
                if status=="CORRECT": correct+=1
                elif status=="REVIEW": review+=1
                else: error+=1
                results.append({"row":i+2,"sid":sid,"store":txt(r["Store Name"]),"status":status,"problem":"; ".join(dict.fromkeys(problems))})
            self.results=results
            self.say(f"Validated {len(results):,} store records")
            return {"total":len(results),"correct":correct,"review":review,"error":error,
                    "broken":len(struct),"masterMapping":mmap,"storeMapping":smap,"rows":results[:500]}
        except Exception as e: self.say(str(e)); return {"error":str(e)}

    @Slot(str,result="QVariant")
    def inspectBroken(self,path):
        try:
            path=QUrl(path).toLocalFile() if path.startswith("file:") else path
            if Path(path).suffix.lower() not in [".csv",".txt",".tsv"]:
                return {"error":"Broken-line repair is intended for delimited text files."}
            df,issues=repair_read_csv(path); self.df=df; self.structural=issues
            return {"rows":len(df),"columns":len(df.columns),"issues":issues[:500],"issueCount":len(issues)}
        except Exception as e: return {"error":str(e)}

    @Slot(str,str,result=str)
    def exportClean(self,inputPath,outputPath):
        try:
            inputPath=QUrl(inputPath).toLocalFile() if inputPath.startswith("file:") else inputPath
            outputPath=QUrl(outputPath).toLocalFile() if outputPath.startswith("file:") else outputPath
            df,_=repair_read_csv(inputPath); df.to_csv(outputPath,index=False,encoding="utf-8-sig")
            return outputPath
        except Exception as e: return "ERROR: "+str(e)

    @Slot(str,result="QVariant")
    def runSql(self,sql):
        try:
            q=sql.strip()
            if not re.match(r"^(select|with)\b",q,re.I): return {"error":"Read-only SQL: SELECT/CTE queries only."}
            if re.search(r"\b(delete|update|insert|drop|alter|create|attach|copy|install|load|call)\b",q,re.I):
                return {"error":"Destructive/external SQL commands are disabled."}
            con=duckdb.connect(database=":memory:")
            con.register("data",self.df)
            out=con.execute(q).df()
            return {"columns":[str(c) for c in out.columns],"rows":out.head(1000).astype(str).values.tolist(),"count":len(out)}
        except Exception as e: return {"error":str(e)}

    @Slot(str,result="QVariant")
    def quickAnalysis(self,column):
        try:
            if column not in self.df.columns: return {"error":"Column not found"}
            s=self.df[column].map(txt); nums=pd.to_numeric(s.str.replace(",","",regex=False),errors="coerce")
            if nums.notna().sum():
                return {"count":int(nums.notna().sum()),"sum":float(nums.sum()),"average":float(nums.mean()),
                        "min":float(nums.min()),"max":float(nums.max()),"blank":int((s=="").sum())}
            return {"count":int((s!="").sum()),"unique":int(s[s!=""].nunique()),"blank":int((s=="").sum()),
                    "top":dict(Counter(s[s!=""]).most_common(10))}
        except Exception as e: return {"error":str(e)}

def main():
    app=QGuiApplication(sys.argv); app.setApplicationName("Store Data Assistant 6.0")
    engine=QQmlApplicationEngine(); backend=Backend()
    engine.rootContext().setContextProperty("backend",backend)
    qml=Path(__file__).with_name("Main.qml")
    engine.load(QUrl.fromLocalFile(str(qml.resolve())))
    if not engine.rootObjects(): raise SystemExit("Main.qml failed to load")
    sys.exit(app.exec())
if __name__=="__main__": main()
