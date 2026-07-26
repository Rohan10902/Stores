import pandas as pd
def profile(df):
    rows,cols=df.shape; blanks=int(df.isna().sum().sum()); total=max(1,rows*cols)
    stats=[]
    for c in df.columns:
        s=df[c]; num=pd.to_numeric(s,errors="coerce")
        stats.append({"column":str(c),"nonBlank":int(s.notna().sum()),"blank":int(s.isna().sum()),"unique":int(s.dropna().astype(str).nunique()),"duplicateValues":int(s.dropna().astype(str).duplicated().sum()),"numericCount":int(num.notna().sum())})
    completeness=round((1-blanks/total)*100,1)
    dup=int(df.duplicated().sum())
    score=max(0,round(completeness - min(20,(dup/max(1,rows))*100),1))
    return {"rows":rows,"columns":cols,"completeness":completeness,"duplicateRows":dup,"score":score,"columnNames":[str(c) for c in df.columns],"columnStats":stats}
def statistic(df,col,op,group=""):
    def calc(s):
        if op=="Count": return int(s.notna().sum())
        if op=="Distinct Count": return int(s.dropna().nunique())
        if op=="Blank Count": return int(s.isna().sum())
        n=pd.to_numeric(s,errors="coerce")
        return {"Sum":n.sum(),"Average":n.mean(),"Minimum":n.min(),"Maximum":n.max(),"Median":n.median()}[op]
    if group and group in df.columns:
        return [{"group":str(k) if not pd.isna(k) else "(blank)","value":calc(g[col])} for k,g in df.groupby(group,dropna=False)]
    return [{"group":"All rows","value":calc(df[col])}]
