import csv, re
from pathlib import Path
import pandas as pd
from .common import STORE_FIELDS, norm_value, date_ok, binary_ok

def empty_rows(n=10):
    return [{f:"" for f in STORE_FIELDS} for _ in range(max(1,n))]

def parse_clipboard(text):
    text=str(text or "").replace("\r\n","\n").replace("\r","\n")
    if not text.strip(): return []
    # Excel/Sheets clipboard is tab-separated; fall back to CSV for comma text.
    delim="\t" if "\t" in text else ","
    return [row for row in csv.reader(text.splitlines(),delimiter=delim)]

def normalize_nielsen(value,width):
    s=norm_value(value)
    if not s:return ""
    # Preserve non-numeric identifiers; only zero-pad all-digit codes.
    return s.zfill(int(width)) if s.isdigit() else s

def review_dataframe(df):
    rows=[]; issues=[]; widths=[]
    if "Nielsen Store Code" in df.columns:
        codes=[norm_value(x) for x in df["Nielsen Store Code"] if norm_value(x)]
        numeric=[x for x in codes if x.isdigit()]
        widths=[len(x) for x in numeric]
    suggested=max(widths) if widths else 0
    for ix,r in df.iterrows():
        item={"row":int(ix)+2,"severity":"OK","issues":[]}
        for f in STORE_FIELDS:
            if f not in df.columns: continue
            v=norm_value(r.get(f,""))
            if f in ("Active / Inactive","Is Census","Is Exceptions") and not binary_ok(v):
                item["issues"].append(f"{f}: invalid boolean value '{v}'")
            elif f in ("Trip Received","Last Trip") and not date_ok(v):
                item["issues"].append(f"{f}: invalid date '{v}'")
        if "Nielsen Store Code" in df.columns:
            code=norm_value(r.get("Nielsen Store Code",""))
            if suggested and code.isdigit() and len(code)<suggested:
                item["issues"].append(f"Nielsen Store Code: {code} is shorter than suggested width {suggested}")
        if item["issues"]: item["severity"]="REVIEW"
        rows.append(item); issues.extend(item["issues"])
    return {"rows":rows,"issueCount":sum(bool(x["issues"]) for x in rows),
            "suggestedNielsenWidth":suggested,
            "columns":[str(c) for c in df.columns]}

def creator_validate(rows):
    findings=[]
    for i,row in enumerate(rows):
        if not any(norm_value(row.get(f,"")) for f in STORE_FIELDS): continue
        for f in ("Active / Inactive","Is Census","Is Exceptions"):
            v=norm_value(row.get(f,""))
            if not binary_ok(v): findings.append({"row":i+1,"field":f,"value":v,"message":"Expected 1/0, true/false, or yes/no"})
        for f in ("Trip Received","Last Trip"):
            v=norm_value(row.get(f,""))
            if not date_ok(v): findings.append({"row":i+1,"field":f,"value":v,"message":"Invalid date"})
    return findings

def export_creator(rows,dst):
    path=Path(dst)
    if path.suffix.lower()!=".csv": path=path.with_suffix(".csv")
    with path.open("w",newline="",encoding="utf-8-sig") as f:
        w=csv.DictWriter(f,fieldnames=STORE_FIELDS,extrasaction="ignore")
        w.writeheader()
        for row in rows:
            if any(norm_value(row.get(k,"")) for k in STORE_FIELDS):
                w.writerow({k:norm_value(row.get(k,"")) for k in STORE_FIELDS})
    return str(path)
