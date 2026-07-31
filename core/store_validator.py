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

    def unique(df, mp, fields):
        keys = [_key(r, mp, fields) for _, r in df.iterrows()]
        keys = [k for k in keys if any(k)]
        return len(keys) == len(set(keys))

    for fields in candidates:
        if unique(master, mm, fields) and unique(uploaded, um, fields):
            return fields
    return candidates[-1]

def compare(master, uploaded, key_fields=None):
    mm, um = map_columns(master.columns), map_columns(uploaded.columns)
    key_fields = key_fields or suggest_keys(master, uploaded)
    for f in key_fields:
        if not mm.get(f,{}).get("column") or not um.get(f,{}).get("column"):
            raise ValueError(f"Matching field '{f}' could not be detected in both files.")
            
    master_groups = defaultdict(list)
    upload_groups = defaultdict(list)
    for ix, r in master.iterrows():
        master_groups[_key(r, mm, key_fields)].append((int(ix)+2, r))
    for ix, r in uploaded.iterrows():
        upload_groups[_key(r, um, key_fields)].append((int(ix)+2, r))
        
    records = []
    for ix, r in uploaded.iterrows():
        row_no = int(ix) + 2
        key_tuple = _key(r, um, key_fields)
        key_str = " | ".join([_get(r, um, k) for k in key_fields if _get(r, um, k)]) or "No Key"
        masters = master_groups.get(key_tuple, [])
        uploads = upload_groups.get(key_tuple, [])
        sid = _get(r, um, "SID")
        store = _get(r, um, "Store Name")
        problems = []
        details = []
        master_dict = {}
        upload_dict = {}
        diffs_dict = {}

        if masters:
            mr = masters[0][1]
            for f in STORE_FIELDS:
                a, b = _get(mr, mm, f), _get(r, um, f)
                master_dict[f] = a
                upload_dict[f] = b
                is_diff = (a.casefold() != b.casefold())
                diffs_dict[f] = is_diff
                sev = "REVIEW" if is_diff else "OK"
                res = "DIFFERENT" if is_diff else "MATCH"
                if is_diff:
                    problems.append(f"{f}: mismatch")
                details.append({"field": f, "master": a, "uploaded": b, "result": res, "severity": sev})
        else:
            for f in STORE_FIELDS:
                u_val = _get(r, um, f)
                upload_dict[f] = u_val
                master_dict[f] = ""
                diffs_dict[f] = True
                details.append({"field": f, "master": "", "uploaded": u_val, "result": "MISSING MASTER", "severity": "ERROR"})

        if not masters:
            status = "ERROR"
            msg = "Matching identity not found in Master file."
        elif any(d["severity"] == "ERROR" for d in details):
            status = "ERROR"
            msg = "; ".join(problems)
        elif any(d["severity"] == "REVIEW" for d in details):
            status = "REVIEW"
            msg = "; ".join(problems)
        else:
            status = "CORRECT"
            msg = "Exact match with Master record."

        records.append({
            "row": row_no,
            "key": key_str,
            "status": status,
            "message": msg,
            "problem": msg,
            "master": master_dict,
            "upload": upload_dict,
            "diffs": diffs_dict,
            "comparisons": details
        })

    return mm, um, records, key_fields

def validation_insights(records):
    groups = Counter()
    for r in records:
        if r["status"] in ("ERROR", "REVIEW"):
            groups[r["status"]] += 1
    attention = sum(groups.values())
    return {"groups": [], "attention": attention}
