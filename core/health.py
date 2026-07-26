import pandas as pd

def _blank_mask(s):
    return s.isna() | s.astype(str).str.strip().eq("")

def infer_type(s):
    nonblank = s[~_blank_mask(s)]
    if nonblank.empty:
        return "empty"
    numeric = pd.to_numeric(nonblank, errors="coerce")
    if numeric.notna().mean() >= 0.95:
        return "numeric"
    dates = pd.to_datetime(nonblank, errors="coerce")
    if dates.notna().mean() >= 0.95:
        return "date"
    vals = set(nonblank.astype(str).str.strip().str.lower().unique())
    if vals and vals.issubset({"0","1","true","false","yes","no","y","n"}):
        return "boolean"
    return "text"

OPS = {
    "numeric": ["Count","Distinct Count","Blank Count","Sum","Average","Minimum","Maximum","Median"],
    "date": ["Count","Distinct Count","Blank Count","Earliest Date","Latest Date","Date Range"],
    "boolean": ["Count","Distinct Count","Blank Count","Most Common Value","Least Common Value"],
    "text": ["Count","Distinct Count","Blank Count","Most Common Value","Least Common Value"],
    "empty": ["Count","Distinct Count","Blank Count"],
}

def profile(df):
    rows, cols = df.shape
    blanks = int(sum(_blank_mask(df[c]).sum() for c in df.columns))
    total = max(1, rows * cols)
    stats = []
    types = {}
    for c in df.columns:
        s = df[c]
        typ = infer_type(s)
        types[str(c)] = typ
        blank = int(_blank_mask(s).sum())
        nonblank = s[~_blank_mask(s)]
        stats.append({
            "column": str(c),
            "type": typ,
            "nonBlank": int(len(nonblank)),
            "blank": blank,
            "unique": int(nonblank.astype(str).nunique()),
            "duplicateValues": int(nonblank.astype(str).duplicated().sum()),
        })
    completeness = round((1 - blanks / total) * 100, 1)
    dup = int(df.fillna("").astype(str).duplicated().sum())
    score = max(0, round(completeness - min(20, (dup / max(1, rows)) * 100), 1))
    return {
        "rows": rows, "columns": cols, "completeness": completeness,
        "duplicateRows": dup, "score": score,
        "columnNames": [str(c) for c in df.columns],
        "columnTypes": types, "operations": OPS, "columnStats": stats
    }

def _calc(s, op, typ):
    blank = _blank_mask(s)
    clean = s[~blank]
    if op == "Count": return int(len(clean))
    if op == "Distinct Count": return int(clean.astype(str).nunique())
    if op == "Blank Count": return int(blank.sum())

    if typ == "numeric":
        n = pd.to_numeric(clean, errors="coerce").dropna()
        if n.empty: return ""
        if op == "Sum": return float(n.sum())
        if op == "Average": return float(n.mean())
        if op == "Minimum": return float(n.min())
        if op == "Maximum": return float(n.max())
        if op == "Median": return float(n.median())

    if typ == "date":
        d = pd.to_datetime(clean, errors="coerce").dropna()
        if d.empty: return ""
        if op == "Earliest Date": return d.min().isoformat()
        if op == "Latest Date": return d.max().isoformat()
        if op == "Date Range":
            return f"{d.min().isoformat()} → {d.max().isoformat()}"

    if op in ("Most Common Value", "Least Common Value"):
        if clean.empty: return ""
        vc = clean.astype(str).value_counts()
        return str(vc.index[0] if op == "Most Common Value" else vc.index[-1])

    raise ValueError(f"{op} is not valid for a {typ} column.")

def statistic(df, col, op, group=""):
    if col not in df.columns:
        raise ValueError("Select a valid column.")
    typ = infer_type(df[col])
    if op not in OPS[typ]:
        raise ValueError(f"{op} is not available for {typ} column '{col}'.")
    if group and group in df.columns:
        out = []
        for k, g in df.groupby(group, dropna=False):
            label = "(blank)" if pd.isna(k) or str(k).strip()=="" else str(k)
            out.append({"group": label, "value": _calc(g[col], op, typ)})
        return out
    return [{"group": "All rows", "value": _calc(df[col], op, typ)}]
