from collections import Counter
from .common import STORE_FIELDS, map_columns, norm_value, date_ok, binary_ok

def compare(master, uploaded):
    mm, um = map_columns(master.columns), map_columns(uploaded.columns)
    mc, uc = mm["SID"]["column"], um["SID"]["column"]
    if not mc or not uc: raise ValueError("SID could not be detected in one or both files.")
    lookup={}
    for _,r in master.iterrows():
        sid=norm_value(r[mc])
        if sid and sid not in lookup: lookup[sid]=r
    counts=Counter(norm_value(x) for x in uploaded[uc] if norm_value(x))
    records=[]
    def get(row,m,f):
        c=m.get(f,{}).get("column","")
        return norm_value(row[c]) if c and c in row.index else ""
    for ix,r in uploaded.iterrows():
        sid=get(r,um,"SID"); mr=lookup.get(sid); details=[]; problems=[]
        if counts[sid]>1: problems.append("Duplicate SID in uploaded file")
        if mr is None:
            status="ERROR"; problems.append("SID not found in Master")
            for f in STORE_FIELDS: details.append({"field":f,"master":"","uploaded":get(r,um,f),"result":"MISSING MASTER","severity":"ERROR"})
        else:
            for f in STORE_FIELDS:
                a,b=get(mr,mm,f),get(r,um,f); sev,res,note="OK","MATCH",""
                if f in ("Active / Inactive","Is Census","Is Exceptions") and not binary_ok(b): sev,res,note="ERROR","INVALID","expected 1 or 0"
                elif f in ("Trip Received","Last Trip") and not date_ok(b): sev,res,note="ERROR","INVALID","invalid date"
                elif f=="Updated By" and b and not date_ok(b): sev,res,note="REVIEW","REVIEW","unrecognized timestamp"
                elif a.casefold()!=b.casefold(): sev,res="REVIEW","DIFFERENT"
                if sev!="OK": problems.append(f"{f}: {note or 'mismatch'}")
                details.append({"field":f,"master":a,"uploaded":b,"result":res,"severity":sev})
            status="ERROR" if counts[sid]>1 or any(x["severity"]=="ERROR" for x in details) else ("REVIEW" if any(x["severity"]=="REVIEW" for x in details) else "CORRECT")
        records.append({"row":int(ix)+2,"sid":sid,"storeName":get(r,um,"Store Name"),"status":status,"problem":"; ".join(problems) or "No differences","comparisons":details})
    return mm,um,records
