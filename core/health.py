import pandas as pd

def _blank(s): return s.isna() | s.astype(str).str.strip().eq("")

def infer_type(s):
    x=s[~_blank(s)]
    if x.empty:return "empty"
    vals=set(x.astype(str).str.strip().str.lower().unique())
    if vals and vals.issubset({"0","1","true","false","yes","no","y","n","active","inactive"}):return "boolean"
    if pd.to_numeric(x,errors="coerce").notna().mean()>=.95:return "numeric"
    txt=x.astype(str)
    if txt.str.contains(r"[-/:]|[A-Za-z]{3,}",regex=True).mean()>=.8 and pd.to_datetime(x,errors="coerce").notna().mean()>=.95:return "date"
    return "text"

OPS={
"numeric":["Quick Summary","Count","Distinct Count","Blank Count","Sum","Average","Minimum","Maximum","Median","Frequency Distribution"],
"date":["Count","Distinct Count","Blank Count","Earliest Date","Latest Date","Date Range","Frequency Distribution"],
"boolean":["Count","Distinct Count","Blank Count","Most Common Value","Least Common Value","Frequency Distribution"],
"text":["Count","Distinct Count","Blank Count","Most Common Value","Least Common Value","Frequency Distribution"],
"empty":["Count","Distinct Count","Blank Count"]}

def profile(df):
    rows,cols=df.shape; stats=[];types={};blanks=0
    for c in df.columns:
        s=df[c];typ=infer_type(s);types[str(c)]=typ;b=int(_blank(s).sum());blanks+=b;clean=s[~_blank(s)]
        stats.append({"column":str(c),"type":typ,"nonBlank":len(clean),"blank":b,
                      "unique":int(clean.astype(str).nunique()),
                      "duplicateValues":int(clean.astype(str).duplicated().sum())})
    completeness=round((1-blanks/max(1,rows*cols))*100,1)
    dup=int(df.fillna("").astype(str).duplicated().sum())
    score=max(0,round(completeness-min(20,dup/max(1,rows)*100),1))
    return {"rows":rows,"columns":cols,"completeness":completeness,"duplicateRows":dup,"score":score,
            "columnNames":[str(c) for c in df.columns],"columnTypes":types,"operations":OPS,"columnStats":stats}

def _numeric(s, col):
    clean=s[~_blank(s)]
    converted=pd.to_numeric(clean,errors="coerce")
    bad=clean[converted.isna()].astype(str).tolist()
    if bad:
        sample=", ".join(bad[:8])
        more=f" (+{len(bad)-8} more)" if len(bad)>8 else ""
        raise ValueError(f"'{col}' contains {len(bad)} non-numeric value(s): {sample}{more}")
    return converted.dropna()

def _scalar(s,op,typ,col=""):
    clean=s[~_blank(s)]
    if op=="Count":return len(clean)
    if op=="Distinct Count":return int(clean.astype(str).nunique())
    if op=="Blank Count":return int(_blank(s).sum())
    if typ=="numeric":
        n=_numeric(s,col)
        if n.empty:return ""
        return {"Sum":n.sum(),"Average":n.mean(),"Minimum":n.min(),"Maximum":n.max(),"Median":n.median()}[op]
    if typ=="date":
        d=pd.to_datetime(clean,errors="coerce").dropna()
        if d.empty:return ""
        if op=="Earliest Date":return d.min().isoformat()
        if op=="Latest Date":return d.max().isoformat()
        return f"{d.min().isoformat()} → {d.max().isoformat()}"
    if op in ("Most Common Value","Least Common Value"):
        if clean.empty:return ""
        vc=clean.astype(str).value_counts()
        return vc.index[0] if op=="Most Common Value" else vc.index[-1]
    raise ValueError(f"{op} is not valid for {typ} data.")

def _insight(df,col,typ,op,rows):
    s=df[col]; total=len(s); blanks=int(_blank(s).sum()); clean=s[~_blank(s)]; bits=[]
    if blanks: bits.append(f"{blanks} blank value(s) ({round(blanks/max(1,total)*100,1)}%).")
    if typ=="numeric" and len(clean):
        n=pd.to_numeric(clean,errors="coerce").dropna()
        if len(n):
            bits.append(f"Range {n.min():g} to {n.max():g}; average {n.mean():g}; median {n.median():g}.")
            q1,q3=n.quantile(.25),n.quantile(.75);iqr=q3-q1
            outliers=int(((n<q1-1.5*iqr)|(n>q3+1.5*iqr)).sum()) if iqr else 0
            if outliers:bits.append(f"{outliers} potential IQR outlier(s) detected.")
    elif typ in ("text","boolean") and len(clean):
        vc=clean.astype(str).value_counts();top=vc.iloc[0];names=", ".join(map(str,vc[vc==top].index[:4]))
        bits.append(f"Most frequent: {names} ({int(top)} record(s), {round(top/len(clean)*100,1)}%).")
        if len(vc)>1 and len(vc[vc==top])>1: bits.append("The most-common value is tied.")
    elif typ=="date" and len(clean):
        d=pd.to_datetime(clean,errors="coerce").dropna()
        if len(d):bits.append(f"Dates span {d.min().date()} to {d.max().date()}.")
    return " ".join(bits) or "No notable issue detected for this calculation."

def statistic(df,col,op,group=""):
    if col not in df.columns:raise ValueError("Select a valid column.")
    typ=infer_type(df[col])
    if op not in OPS[typ]:raise ValueError(f"{op} is not available for {typ} column '{col}'.")
    rows=[]
    if op=="Quick Summary":
        clean=_numeric(df[col],col)
        metrics=[("Records",len(df)),("Valid Numeric",len(clean)),("Blank",int(_blank(df[col]).sum())),
                 ("Sum",clean.sum() if len(clean) else ""),("Average",clean.mean() if len(clean) else ""),
                 ("Minimum",clean.min() if len(clean) else ""),("Maximum",clean.max() if len(clean) else ""),
                 ("Median",clean.median() if len(clean) else "")]
        rows=[{"label":k,"result":v,"count":"","percent":"","interpretation":"Quick Summary"} for k,v in metrics]
    elif op=="Frequency Distribution":
        if group and group in df.columns:
            for k,g in df.groupby(group,dropna=False):
                clean=g[col][~_blank(g[col])].astype(str);vc=clean.value_counts();den=max(1,len(clean))
                for v,n in vc.items(): rows.append({"label":"(blank)" if pd.isna(k) else str(k),"result":str(v),"count":int(n),"percent":round(n/den*100,1),"interpretation":"Frequency"})
        else:
            clean=df[col][~_blank(df[col])].astype(str);vc=clean.value_counts();den=max(1,len(clean))
            for v,n in vc.items(): rows.append({"label":str(v),"result":str(v),"count":int(n),"percent":round(n/den*100,1),"interpretation":"Frequency"})
    elif group and group in df.columns:
        for k,g in df.groupby(group,dropna=False): rows.append({"label":"(blank)" if pd.isna(k) else str(k),"result":_scalar(g[col],op,typ,col),"count":len(g),"percent":round(len(g)/max(1,len(df))*100,1),"interpretation":op})
    else:
        val=_scalar(df[col],op,typ,col);count="";percent="";clean=df[col][~_blank(df[col])]
        if op in ("Most Common Value","Least Common Value") and len(clean): count=int((clean.astype(str)==str(val)).sum());percent=round(count/len(clean)*100,1)
        rows=[{"label":f"{op} — {col}","result":val,"count":count,"percent":percent,"interpretation":op}]
    return {"type":typ,"column":col,"operation":op,"rows":rows,"insight":_insight(df,col,typ,op,rows)}
