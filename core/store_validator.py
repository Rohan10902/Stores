from collections import Counter, defaultdict
from difflib import SequenceMatcher
from .common import STORE_FIELDS, map_columns, norm_value, date_ok, binary_ok

try:
    from rapidfuzz import fuzz
    HAS_RAPIDFUZZ = True
except ImportError:
    HAS_RAPIDFUZZ = False

def string_similarity(a, b):
    sa, sb = str(a or "").strip().lower(), str(b or "").strip().lower()
    if not sa or not sb:
        return 100.0 if sa == sb else 0.0
    if HAS_RAPIDFUZZ:
        return round(float(fuzz.token_sort_ratio(sa, sb)), 1)
    return round(SequenceMatcher(None, sa, sb).ratio() * 100.0, 1)

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
        candidates.append(["SID", "Nielsen Store Code"])

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
                
                sim = string_similarity(a, b)
                is_diff = (a.casefold() != b.casefold())
                diffs_dict[f] = is_diff
                
                res = "MATCH" if not is_diff else f"DIFFERENT ({sim}% match)"
                if is_diff:
                    problems.append(f"{f}: mismatch ({sim}% similarity)")
                details.append({"field": f, "master": a, "uploaded": b, "result": res, "severity": "REVIEW" if is_diff else "OK"})
        else:
            for f in STORE_FIELDS:
                u_val = _get(r, um, f)
                upload_dict[f] = u_val
                master_dict[f] = ""
                diffs_dict[f] = True
                details.append({"field": f, "master": "", "uploaded": u_val, "result": "MISSING MASTER", "severity": "ERROR"})

        status = "CORRECT" if masters and not problems else ("REVIEW" if masters else "ERROR")
        msg = "Exact match with Master." if status == "CORRECT" else ("; ".join(problems) if masters else "Store key not found in Master file.")

        records.append({
            "row": row_no,
            "key": key_str,
            "status": status,
            "message": msg,
            "master": master_dict,
            "upload": upload_dict,
            "diffs": diffs_dict,
            "comparisons": details
        })

    return mm, um, records, key_fields

def validation_insights(records):
    attention = sum(1 for r in records if r["status"] in ("ERROR", "REVIEW"))
    return {"groups": [], "attention": attention}
