from collections import Counter, defaultdict
from .common import STORE_FIELDS, map_columns, norm_value, date_ok, binary_ok

DEFAULT_KEYS = ["SID", "Nielsen Store Code"]

def _get(row, mapping, field):
    c = mapping.get(field, {}).get("column", "")
    return norm_value(row[c]) if c and c in row.index else ""

def _key(row, mapping, fields):
    return tuple(_get(row, mapping, f).casefold() for f in fields)

def suggest_keys(master, uploaded):
    mm, um = map_columns(master.columns), map_columns(uploaded.columns)
    available = [f for f in STORE_FIELDS if mm.get(f,{}).get("column") and um.get(f,{}).get("column")]
    if "SID" not in available:
        raise ValueError("SID could not be detected in one or both files.")
    candidates = [["SID"]]
    if "Nielsen Store Code" in available:
        candidates.append(["SID","Nielsen Store Code"])
    # Prefer the smallest key that is unique in both datasets. If SID repeats,
    # SID + Nielsen Store Code is the default recommendation when available.
    def unique(df, mp, fields):
        keys=[_key(r,mp,fields) for _,r in df.iterrows()]
        keys=[k for k in keys if any(k)]
        return len(keys)==len(set(keys))
    for fields in candidates:
        if unique(master,mm,fields) and unique(uploaded,um,fields):
            return fields
    return candidates[-1]

def compare(master, uploaded, key_fields=None):
    mm, um = map_columns(master.columns), map_columns(uploaded.columns)
    key_fields = key_fields or suggest_keys(master, uploaded)
    for f in key_fields:
        if not mm.get(f,{}).get("column") or not um.get(f,{}).get("column"):
            raise ValueError(f"Matching field '{f}' could not be detected in both files.")

    master_groups=defaultdict(list)
    upload_groups=defaultdict(list)
    for ix,r in master.iterrows():
        master_groups[_key(r,mm,key_fields)].append((int(ix)+2,r))
    for ix,r in uploaded.iterrows():
        upload_groups[_key(r,um,key_fields)].append((int(ix)+2,r))

    records=[]
    for ix,r in uploaded.iterrows():
        row_no=int(ix)+2
        key=_key(r,um,key_fields)
        masters=master_groups.get(key,[])
        uploads=upload_groups.get(key,[])
        sid=_get(r,um,"SID")
        store=_get(r,um,"Store Name")
        problems=[]
        details=[]
        context={
            "keyFields": key_fields,
            "keyValues": [_get(r,um,f) for f in key_fields],
            "uploadedRows": [n for n,_ in uploads],
            "masterRows": [n for n,_ in masters],
            "duplicateType": "",
            "relatedUploaded": []
        }

        if len(uploads)>1:
            # Same composite identity: exact duplicate if all normalized mapped fields match.
            sigs=[]
            for _,ur in uploads:
                sigs.append(tuple(_get(ur,um,f).casefold() for f in STORE_FIELDS))
            exact=len(set(sigs))==1
            context["duplicateType"]="EXACT DUPLICATE" if exact else "POTENTIAL DUPLICATE"
            context["relatedUploaded"]=[
                {"row":n,"sid":_get(ur,um,"SID"),"nielsen":_get(ur,um,"Nielsen Store Code"),
                 "storeName":_get(ur,um,"Store Name")} for n,ur in uploads
            ]
            problems.append(f"{context['duplicateType']}: matching identity occurs on uploaded rows {', '.join(map(str,context['uploadedRows']))}")

        if len(masters)>1:
            context["duplicateType"]="MASTER KEY CONFLICT"
            problems.append(f"MASTER KEY CONFLICT: matching identity occurs on master rows {', '.join(map(str,context['masterRows']))}")

        if not masters:
            status="ERROR"
            problems.append("Matching identity not found in Master")
            for f in STORE_FIELDS:
                details.append({"field":f,"master":"","uploaded":_get(r,um,f),
                                "result":"MISSING MASTER","severity":"ERROR"})
        elif len(masters)>1:
            status="ERROR"
            mr=masters[0][1]
            for f in STORE_FIELDS:
                details.append({"field":f,"master":_get(mr,mm,f),"uploaded":_get(r,um,f),
                                "result":"MASTER CONFLICT","severity":"ERROR"})
        else:
            mr=masters[0][1]
            for f in STORE_FIELDS:
                a,b=_get(mr,mm,f),_get(r,um,f)
                sev,res,note="OK","MATCH",""
                if f in ("Active / Inactive","Is Census","Is Exceptions") and not binary_ok(b):
                    sev,res,note="ERROR","INVALID","expected 1/0, true/false, or yes/no"
                elif f in ("Trip Received","Last Trip") and not date_ok(b):
                    sev,res,note="ERROR","INVALID","invalid date"
                elif f=="Updated By" and b and not date_ok(b):
                    sev,res,note="REVIEW","REVIEW","unrecognized timestamp"
                elif a.casefold()!=b.casefold():
                    sev,res="REVIEW","DIFFERENT"
                if sev!="OK":
                    problems.append(f"{f}: {note or 'mismatch'}")
                details.append({"field":f,"master":a,"uploaded":b,"result":res,"severity":sev})

            if context["duplicateType"] in ("EXACT DUPLICATE","MASTER KEY CONFLICT"):
                status="ERROR"
            elif context["duplicateType"]=="POTENTIAL DUPLICATE":
                status="REVIEW"
            elif any(x["severity"]=="ERROR" for x in details):
                status="ERROR"
            elif any(x["severity"]=="REVIEW" for x in details):
                status="REVIEW"
            else:
                status="CORRECT"

        records.append({"row":row_no,"sid":sid,"storeName":store,"status":status,
                        "problem":"; ".join(problems) or "No differences",
                        "comparisons":details,"context":context})
    return mm,um,records,key_fields
