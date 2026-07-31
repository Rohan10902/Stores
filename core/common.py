import csv
import io
import json
import re
from pathlib import Path
from difflib import SequenceMatcher
import pandas as pd

# Optional high-speed Polars acceleration with graceful fallback
try:
    import polars as pl
    HAS_POLARS = True
except ImportError:
    HAS_POLARS = False

STORE_FIELDS = [
    "Store Name", "SID", "Banner", "Nielsen Store Code",
    "Trip Received", "Last Trip", "Address 1", "Address 2",
    "Address 3", "ZIP", "Active / Inactive", "Is Census",
    "Is Exceptions", "Updated By"
]

ALIASES = {
    "Store Name": ["store name", "outlet name", "shop name", "location name"],
    "SID": ["sid", "store id", "store identifier", "location id"],
    "Banner": ["banner", "retail banner", "brand", "chain"],
    "Nielsen Store Code": ["nielsen store code", "nielsen code", "nielsen id", "nielsen store"],
    "Trip Received": ["trip received", "trip received date", "received date"],
    "Last Trip": ["last trip", "last trip date", "previous trip date"],
    "Address 1": ["address 1", "address1", "street address", "address line 1"],
    "Address 2": ["address 2", "address2", "address line 2"],
    "Address 3": ["address 3", "address3", "address line 3"],
    "ZIP": ["zip", "zip code", "postal code", "postcode", "pin", "pincode"],
    "Active / Inactive": ["active inactive", "active / inactive", "active flag", "store active"],
    "Is Census": ["is census", "census", "census flag"],
    "Is Exceptions": ["is exceptions", "is exception", "exceptions", "exception flag"],
    "Updated By": ["updated by", "last updated", "last updated timestamp", "updated timestamp", "modified timestamp"]
}

def sanitize_path(p):
    path = str(p or "").strip()
    if path.startswith("file:///"):
        return path[8:]
    elif path.startswith("file://"):
        return path[7:]
    return path

def norm_name(x): 
    return re.sub(r"[^a-z0-9]+", " ", str(x or "").lower()).strip()

def norm_value(x):
    if pd.isna(x): return ""
    if isinstance(x, float) and x.is_integer(): return str(int(x))
    return str(x).strip()

def json_value(x):
    if pd.isna(x): return ""
    if isinstance(x, pd.Timestamp): return x.isoformat(sep=" ")
    try: return x.item()
    except Exception: return x

def _unique_headers(header):
    out = []
    seen = {}
    for i, value in enumerate(header):
        base = str(value).strip() or f"Column {i+1}"
        key = base.casefold()
        seen[key] = seen.get(key, 0) + 1
        out.append(base if seen[key] == 1 else f"{base} ({seen[key]})")
    return out

def _read_delimited_ragged(p, ext):
    path = sanitize_path(p)
    
    # Accelerated Polars reader for standard delimited datasets
    if HAS_POLARS and ext in (".csv", ".tsv", ".txt"):
        try:
            p_df = pl.read_csv(
                path,
                separator="\t" if ext == ".tsv" else ",",
                infer_schema_length=0,
                ignore_errors=True
            )
            return p_df.to_pandas().fillna("")
        except Exception:
            pass # Fall back to robust ragged reader on irregular structure
            
    with open(path, "r", encoding="utf-8-sig", errors="replace") as f:
        chunk = f.read(8192)
        f.seek(0)
        if not chunk: return pd.DataFrame()
        
        delim = "\t" if ext == ".tsv" else ","
        if ext != ".tsv":
            try:
                delim = csv.Sniffer().sniff(chunk, delimiters=",;\t|").delimiter
            except csv.Error:
                first = chunk.splitlines()[0] if chunk.splitlines() else ""
                delim = "," if "," in first else "\t" if "\t" in first else ","
                
        reader = csv.reader(f, delimiter=delim)
        try:
            first_row = next(reader)
        except StopIteration:
            return pd.DataFrame()
            
        header = _unique_headers(first_row)
        data = []
        max_width = len(header)
        
        for row in reader:
            data.append(row)
            if len(row) > max_width:
                max_width = len(row)
                
        width = max_width
        columns = header + [f"EXTRA {i+1}" for i in range(width - len(header))]
        padded = [r + [""] * (width - len(r)) for r in data]
        return pd.DataFrame(padded, columns=columns, dtype=object)

def read_table(p):
    path = sanitize_path(p)
    ext = Path(path).suffix.lower()

    if ext in (".xlsx", ".xls", ".xlsm"):
        book = pd.read_excel(path, sheet_name=None, dtype=object)
        if not book: return pd.DataFrame()
        useful = [(name, df) for name, df in book.items() if not df.empty]
        if len(useful) == 1: return useful[0][1]
        if not useful: return next(iter(book.values()))
        
        scored = []
        for name, df in useful:
            matches = sum(1 for c in df.columns for f in STORE_FIELDS if norm_name(c) == norm_name(f) or norm_name(c) in [norm_name(a) for a in ALIASES.get(f, [])])
            scored.append((matches, len(df), name, df))
        
        scored.sort(key=lambda x: (x[0], x[1]), reverse=True)
        if len(scored) == 1 or scored[0][0] > scored[1][0]:
            return scored[0][3]
        raise ValueError("Workbook contains multiple populated worksheets. Please save/select the intended sheet as CSV before analysis.")
    
    if ext == ".json":
        obj = json.loads(Path(path).read_text(encoding="utf-8-sig"))
        return pd.json_normalize(obj if isinstance(obj, list) else list(obj.values())[0] if isinstance(obj, dict) else obj)
    
    if ext == ".xml": return pd.read_xml(path)
    if ext in (".csv", ".txt", ".tsv"): return _read_delimited_ragged(path, ext)
    
    raise ValueError(f"Unsupported file type: {ext}")

def map_columns(cols):
    out = {}
    used = set()
    for f in STORE_FIELDS:
        best_col = ""
        best = 0.0
        targets = [f] + ALIASES.get(f, [])
        for c in cols:
            if c in used: continue
            cn = norm_name(c)
            score = max(1.0 if cn == norm_name(t) else .93 if cn and (cn in norm_name(t) or norm_name(t) in cn) else SequenceMatcher(None, cn, norm_name(t)).ratio() for t in targets)
            if score > best: best_col, best = c, score
        if best >= .72:
            used.add(best_col)
            out[f] = {"column": str(best_col), "confidence": round(best * 100, 1)}
        else:
            out[f] = {"column": "", "confidence": round(best * 100, 1)}
    return out

def date_ok(x):
    if not norm_value(x): return True
    try:
        pd.to_datetime(norm_value(x), errors="raise")
        return True
    except Exception:
        return False

def binary_ok(x):
    value = norm_value(x)
    return value in ("", "0", "1")
