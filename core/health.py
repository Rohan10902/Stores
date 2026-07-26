import pandas as pd

def _blank(s):
    return s.isna() | s.astype(str).str.strip().eq("")

def infer_type(s):
    x=s[~_blank(s)]
    if x.empty: return "empty"
    if pd.to_numeric(x, errors="coerce").notna().mean() >= .95: return "numeric"
    if pd.to_datetime(x, errors="coerce").notna().mean() >= .95: return "date"
    vals=set(x.astype(str).str.strip().str.lower().unique())
    if vals and vals.issubset({"0","1","true","false","yes","no","y","n"}): return "boolean"
    return "text"

OPS={
 "numeric":["Count","Distinct Count","Blank Count","Sum","Average","Minimum","Maximum","Median"],
 "date":["Count","Distinct Count","Blank Count","Earliest Date","Latest Date","Date Range"],
 "boolean":["Count","Distinct Count","Blank Count","Most Common Value","Least Common Value","Frequency Distribution"],
 "text":["Count","Distinct Count","Blank Count","Most Common Value","Least Common Value","Frequency Distribution"],
 "empty":["Count","Distinct Count","Blank Count"]
}

def profile(df):
    rows,cols=df.shape; stats=[]; types={}; blanks=0
    for c in df.columns:
        s=df[c]; typ=infer_type(s); types[str(c)]=typ
        b=int(_blank(s).sum()); blanks+=b; clean=s[~_blank(s)]
        stats.append({"column":str(c),"type":typ,"nonBlank":len(clean),"blank":b,
                      "unique":int(clean.astype(str).nunique()),
                      "duplicateValues":int(clean.astype(str).duplicated().sum())})
    total=max(1,rows*cols); completeness=round((1-blanks/total)*100,1)
    dup=int(df.fillna("").astype(str).duplicated().sum())
    score=max(0,round(completeness-min(20,dup/max(1,rows)*100),1))
    return {"rows":rows,"columns":cols,"completeness":completeness,"duplicateRows":dup,"score":score,
            "columnNames":[str(c) for c in df.columns],"columnTypes":types,"operations":OPS,"columnStats":stats}

def _scalar(s,op,typ):
    clean=s[~_blank(s)]
    if op=="Count": return len(clean)
    if op=="Distinct Count": return int(clean.astype(str).nunique())
    if op=="Blank Count": return int(_blank(s).sum())
    if typ=="numeric":
        n=pd.to_numeric(clean,errors="coerce").dropna()
        if n.empty:return ""
        return {"Sum":n.sum(),"Average":n.mean(),"Minimum":n.min(),"Maximum":n.max(),"Median":n.median()}[op]
    if typ=="date":
        d=pd.to_datetime(clean,errors="coerce").dropna()
        if d.empty:return ""
        if op=="Earliest Date":return d.min().isoformat()
        if op=="Latest Date":return d.max().isoformat()
        if op=="Date Range":return f"{d.min().isoformat()} → {d.max().isoformat()}"
    if op in ("Most Common Value","Least Common Value"):
        if clean.empty:return ""
        vc=clean.astype(str).value_counts()
        return vc.index[0] if op=="Most Common Value" else vc.index[-1]
    raise ValueError(f"{op} is not valid for {typ} data.")

def statistic(df,col,op,group=""):
    if col not in df.columns: raise ValueError("Select a valid column.")
    typ=infer_type(df[col])
    if op not in OPS[typ]: raise ValueError(f"{op} is not available for {typ} column '{col}'.")

    if op=="Frequency Distribution":
        def freq(part,label):
            clean=part[col][~_blank(part[col])].astype(str)
            vc=clean.value_counts(dropna=False); total=max(1,len(clean))
            return [{"group":label,"result":str(v),"count":int(n),"percent":round(n/total*100,1)}
                    for v,n in vc.items()]
        if group and group in df.columns:
            out=[]
            for k,g in df.groupby(group,dropna=False):
                out += freq(g,"(blank)" if pd.isna(k) else str(k))
            return {"columns":["Group","Value","Count","Percent"],"rows":out,"type":typ}
        return {"columns":["Group","Value","Count","Percent"],"rows":freq(df,"All rows"),"type":typ}

    if group and group in df.columns:
        rows=[]
        for k,g in df.groupby(group,dropna=False):
            rows.append({"group":"(blank)" if pd.isna(k) else str(k),"result":_scalar(g[col],op,typ),
                         "records":len(g)})
        return {"columns":["Group","Records",op+" of "+col],"rows":rows,"type":typ}

    val=_scalar(df[col],op,typ)
    clean=df[col][~_blank(df[col])]
    extra={}
    if op in ("Most Common Value","Least Common Value") and len(clean):
        count=int((clean.astype(str)==str(val)).sum())
        extra={"count":count,"percent":round(count/len(clean)*100,1)}
    return {"columns":["Metric","Result","Count","Percent"],"rows":[
        {"group":f"{op} — {col}","result":val,"count":extra.get("count",""),"percent":extra.get("percent","")}
    ],"type":typ}
