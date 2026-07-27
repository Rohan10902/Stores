import csv, json, re
from pathlib import Path
import pandas as pd
from difflib import SequenceMatcher

STORE_FIELDS = ["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions","Updated By"]
ALIASES = {
"Store Name":["store name","outlet name","shop name","location name"],
"SID":["sid","store id","store identifier","location id"],
"Banner":["banner","retail banner","brand","chain"],
"Nielsen Store Code":["nielsen store code","nielsen code","nielsen id","nielsen store"],
"Trip Received":["trip received","trip received date","received date"],
"Last Trip":["last trip","last trip date","previous trip date"],
"Address 1":["address 1","address1","street address","address line 1"],
"Address 2":["address 2","address2","address line 2","address line 2"],
"Address 3":["address 3","address3","address line 3"],
"ZIP":["zip","zip code","postal code","postcode","pin","pincode"],
"Active / Inactive":["active inactive","active / inactive","active flag","store active"],
"Is Census":["is census","census","census flag"],
"Is Exceptions":["is exceptions","is exception","exceptions","exception flag"],
"Updated By":["updated by","last updated","last updated timestamp","updated timestamp","modified timestamp"]
}
def norm_name(x): return re.sub(r"[^a-z0-9]+"," ",str(x or "").lower()).strip()
def norm_value(x):
    if pd.isna(x): return ""
    if isinstance(x,float) and x.is_integer(): return str(int(x))
    return str(x).strip()
def json_value(x):
    if pd.isna(x): return ""
    if isinstance(x,pd.Timestamp): return x.isoformat(sep=" ")
    try: return x.item()
    except Exception: return x

def _read_delimited_ragged(p, ext):
    """Read delimited text without discarding rows that have extra fields."""
    text=Path(p).read_text(encoding="utf-8-sig",errors="replace")
    lines=text.splitlines()
    if not lines:return pd.DataFrame()
    if ext==".tsv":delim="\t"
    else:
        try:delim=csv.Sniffer().sniff(text[:8192],delimiters=",;\t|").delimiter
        except csv.Error:delim="," if "," in lines[0] else "\t" if "\t" in lines[0] else ","
    rows=list(csv.reader(lines,delimiter=delim))
    if not rows:return pd.DataFrame()
    header=[str(x).strip() or f"Column {i+1}" for i,x in enumerate(rows[0])]
    data=rows[1:]
    width=max([len(header)]+[len(r) for r in data])
    columns=header+[f"EXTRA {i+1}" for i in range(width-len(header))]
    padded=[r+[""]*(width-len(r)) for r in data]
    return pd.DataFrame(padded,columns=columns,dtype=object)

def read_table(p):
    p=str(p); ext=Path(p).suffix.lower()
    if ext in (".xlsx",".xls",".xlsm"): return pd.read_excel(p,dtype=object)
    if ext==".json":
        obj=json.loads(Path(p).read_text(encoding="utf-8-sig"))
        if isinstance(obj,list): return pd.json_normalize(obj)
        if isinstance(obj,dict):
            vals=list(obj.values())
            if len(vals)==1 and isinstance(vals[0],list): return pd.json_normalize(vals[0])
            return pd.json_normalize(obj)
    if ext==".xml": return pd.read_xml(p)
    if ext in (".csv",".txt",".tsv"):
        return _read_delimited_ragged(p,ext)
    raise ValueError(f"Unsupported file type: {ext}")
def map_columns(cols):
    out={}; used=set()
    for f in STORE_FIELDS:
        best_col=""; best=0.0
        targets=[f]+ALIASES.get(f,[])
        for c in cols:
            if c in used: continue
            cn=norm_name(c)
            score=max(1.0 if cn==norm_name(t) else .93 if cn and (cn in norm_name(t) or norm_name(t) in cn) else SequenceMatcher(None,cn,norm_name(t)).ratio() for t in targets)
            if score>best: best_col,best=c,score
        if best>=.55: used.add(best_col); out[f]={"column":str(best_col),"confidence":round(best*100,1)}
        else: out[f]={"column":"","confidence":round(best*100,1)}
    return out
def date_ok(x):
    if not norm_value(x): return True
    try: pd.to_datetime(norm_value(x),errors="raise"); return True
    except Exception: return False
def binary_ok(x): return norm_value(x).lower() in ("","0","1","0.0","1.0","true","false","yes","no")