import csv, re
from pathlib import Path
import pandas as pd
from .common import STORE_FIELDS, ALIASES, norm_name, norm_value, date_ok, binary_ok

def empty_rows(n=10):
    return [{f:"" for f in STORE_FIELDS} for _ in range(max(1,n))]

def parse_clipboard(text):
    text=str(text or "").replace("\r\n","\n").replace("\r","\n")
    if not text.strip(): return []
    delim="\t" if "\t" in text else ","
    return [row for row in csv.reader(text.splitlines(),delimiter=delim)]

def normalize_nielsen(value,width):
    s=norm_value(value)
    if not s:return ""
    return s.zfill(int(width)) if s.isdigit() else s

def _canonical_field(value):
    n=norm_name(value)
    if not n:return ""
    for field in STORE_FIELDS:
        if n==norm_name(field) or any(n==norm_name(a) for a in ALIASES.get(field,[])):
            return field
    return ""

def _detect_structure(df):
    """Describe layout without silently reshaping the user's source."""
    columns=[str(c) for c in df.columns]
    horizontal=sum(1 for c in columns if _canonical_field(c))
    vertical=[]
    # A vertical/key-value record normally has field names down one column and
    # values beside them. Check every column because its heading may be arbitrary.
    for c in df.columns:
        matches=[]
        for ix,v in df[c].items():
            field=_canonical_field(v)
            if field:matches.append((int(ix)+2,field))
        if len(matches)>=2:vertical.append((c,matches))
    if horizontal>=2:return {"kind":"HORIZONTAL","confidence":"HIGH","message":"Standard row-based table detected."}
    if vertical:
        key_col,matches=max(vertical,key=lambda x:len(x[1]))
        fields=[]
        for _,f in matches:
            if f not in fields:fields.append(f)
        return {"kind":"VERTICAL","confidence":"HIGH" if len(fields)>=3 else "MEDIUM","message":f"Vertical key/value layout detected: {len(fields)} store field(s) are arranged down column '{key_col}'. Review One File will not silently treat these lines as {len(df)} independent store records.","fields":fields,"keyColumn":str(key_col)}
    return {"kind":"UNKNOWN","confidence":"LOW","message":"The file does not look like a standard horizontal store table. Review the structure before treating rows as store records."}

def review_dataframe(df):
    rows=[];issues=[];widths=[];structure=_detect_structure(df)
    if structure["kind"]!="HORIZONTAL":
        # Structural ambiguity is itself a finding. This fixes the previous false
        # '0 needs attention' result for vertical/key-value test files.
        return {"rows":[{"row":1,"severity":"REVIEW","issues":[structure["message"]]}],"issueCount":1,"suggestedNielsenWidth":0,"columns":[str(c) for c in df.columns],"structure":structure,"recordCount":1 if structure["kind"]=="VERTICAL" else int(len(df))}
    if "Nielsen Store Code" in df.columns:
        codes=[norm_value(x) for x in df["Nielsen Store Code"] if norm_value(x)]
        numeric=[x for x in codes if x.isdigit()];widths=[len(x) for x in numeric]
    suggested=max(widths) if widths else 0
    for ix,r in df.iterrows():
        item={"row":int(ix)+2,"severity":"OK","issues":[]}
        for f in STORE_FIELDS:
            if f not in df.columns:continue
            v=norm_value(r.get(f,""))
            if f in ("Active / Inactive","Is Census","Is Exceptions") and not binary_ok(v):item["issues"].append(f"{f}: invalid boolean value '{v}'")
            elif f in ("Trip Received","Last Trip") and not date_ok(v):item["issues"].append(f"{f}: invalid date '{v}'")
        if "Nielsen Store Code" in df.columns:
            code=norm_value(r.get("Nielsen Store Code",""))
            if suggested and code.isdigit() and len(code)<suggested:item["issues"].append(f"Nielsen Store Code: {code} is shorter than suggested width {suggested}")
        if item["issues"]:item["severity"]="REVIEW"
        rows.append(item);issues.extend(item["issues"])
    return {"rows":rows,"issueCount":sum(bool(x["issues"]) for x in rows),"suggestedNielsenWidth":suggested,"columns":[str(c) for c in df.columns],"structure":structure,"recordCount":int(len(df))}

def creator_validate(rows):
    findings=[]
    for i,row in enumerate(rows):
        if not any(norm_value(row.get(f,"")) for f in STORE_FIELDS):continue
        for f in ("Active / Inactive","Is Census","Is Exceptions"):
            v=norm_value(row.get(f,""))
            if not binary_ok(v):findings.append({"row":i+1,"field":f,"value":v,"message":"Expected 1/0, true/false, or yes/no"})
        for f in ("Trip Received","Last Trip"):
            v=norm_value(row.get(f,""))
            if not date_ok(v):findings.append({"row":i+1,"field":f,"value":v,"message":"Invalid date"})
    return findings

def export_creator(rows,dst):
    path=Path(dst)
    if path.suffix.lower()!=".csv":path=path.with_suffix(".csv")
    with path.open("w",newline="",encoding="utf-8-sig") as f:
        w=csv.DictWriter(f,fieldnames=STORE_FIELDS,extrasaction="ignore");w.writeheader()
        for row in rows:
            if any(norm_value(row.get(k,"")) for k in STORE_FIELDS):w.writerow({k:norm_value(row.get(k,"")) for k in STORE_FIELDS})
    return str(path)