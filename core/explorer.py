import re
import pandas as pd
import duckdb

_DENY=re.compile(r"\b(insert|update|delete|drop|alter|create|attach|detach|copy|install|load|pragma|replace|vacuum|call|export|import)\b",re.I)
_TRUE={"true","yes","y"}; _FALSE={"false","no","n"}

def _blank(s):
    return s.isna() | s.astype(str).str.strip().eq("")

def _typed(s):
    blank=_blank(s); clean=s[~blank]
    if clean.empty:
        return s.map(lambda _: None), "VARCHAR"
    text=clean.astype(str).str.strip()
    low=set(text.str.lower().unique())
    if low and low.issubset(_TRUE|_FALSE):
        x=s.astype(str).str.strip().str.lower().map(lambda v: True if v in _TRUE else False if v in _FALSE else None)
        return x.astype("boolean"),"BOOLEAN"
    n=pd.to_numeric(text,errors="coerce")
    if n.notna().all():
        full=pd.to_numeric(s.where(~blank,None),errors="coerce")
        z=full.dropna()
        if len(z) and ((z%1)==0).all(): return full.astype("Int64"),"BIGINT"
        return full.astype("Float64"),"DOUBLE"
    # Dates only with strong date-like punctuation/text evidence.
    if text.str.contains(r"[-/:]|[A-Za-z]{3,}",regex=True).mean()>=.80:
        d=pd.to_datetime(text,errors="coerce")
        if d.notna().all(): return pd.to_datetime(s.where(~blank,None),errors="coerce"),"TIMESTAMP"
    return s.map(lambda v: None if pd.isna(v) or str(v).strip()=="" else str(v)),"VARCHAR"

def prepare_for_sql(df):
    typed=pd.DataFrame(index=df.index); schema={}
    for c in df.columns:
        typed[c],schema[str(c)]=_typed(df[c])
    return typed,schema

def run_sql(df,q):
    q=q.strip()
    if not re.match(r"^(select|with)\b",q,re.I): raise ValueError("Only read-only SELECT/WITH SQL is allowed.")
    if _DENY.search(q): raise ValueError("Only read-only SQL is allowed.")
    typed,_=prepare_for_sql(df)
    con=duckdb.connect(database=":memory:")
    try:
        con.register("data",typed)
        return con.execute(q).fetchdf()
    finally: con.close()
