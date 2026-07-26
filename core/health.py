import pandas as pd


def _blank(s):
    return s.isna() | s.astype(str).str.strip().eq("")


def _numeric_parse(s):
    """Parse common spreadsheet numeric text without changing source values."""
    clean = s[~_blank(s)]
    if clean.empty:
        return clean, pd.Series(dtype="float64"), []
    raw = clean.astype(str).str.strip()
    normalized = raw.str.replace(",", "", regex=False).str.replace(r"^\$", "", regex=True).str.strip()
    # Support accounting negatives such as (1,250.50).
    normalized = normalized.str.replace(r"^\((.*)\)$", r"-\1", regex=True)
    parsed = pd.to_numeric(normalized, errors="coerce")
    invalid = raw[parsed.isna()].drop_duplicates().tolist()
    return clean, parsed, invalid


def _numeric_error(col, invalid):
    shown = [str(v) for v in invalid[:12]]
    suffix = f" (+{len(invalid)-12} more)" if len(invalid) > 12 else ""
    values = ", ".join(repr(v) for v in shown)
    return (
        f"Cannot calculate numeric statistics for '{col}'. "
        f"The following value(s) are non-numeric: {values}{suffix}. "
        "Correct/remove those values, or use a text statistic instead."
    )


def infer_type(s):
    x = s[~_blank(s)]
    if x.empty:
        return "empty"
    vals = set(x.astype(str).str.strip().str.lower().unique())
    if vals and vals.issubset({"0", "1", "true", "false", "yes", "no", "y", "n"}):
        return "boolean"
    _, numeric, _ = _numeric_parse(s)
    if numeric.notna().mean() >= .95:
        return "numeric"
    txt = x.astype(str)
    if txt.str.contains(r"[-/:]|[A-Za-z]{3,}", regex=True).mean() >= .8 and pd.to_datetime(x, errors="coerce").notna().mean() >= .95:
        return "date"
    return "text"


NUMERIC_OPS = ["Quick Summary", "Sum", "Average", "Minimum", "Maximum", "Median"]
OPS = {
    "numeric": ["Quick Summary", "Count", "Distinct Count", "Blank Count", "Sum", "Average", "Minimum", "Maximum", "Median"],
    "date": ["Count", "Distinct Count", "Blank Count", "Earliest Date", "Latest Date", "Date Range"],
    # Numeric operations are deliberately available for text columns too. If the
    # selected values cannot be safely parsed, statistic() returns a clear prompt
    # listing the offending values instead of silently dropping them.
    "boolean": ["Count", "Distinct Count", "Blank Count", "Most Common Value", "Least Common Value", "Frequency Distribution"],
    "text": ["Count", "Distinct Count", "Blank Count", "Sum", "Average", "Minimum", "Maximum", "Median", "Most Common Value", "Least Common Value", "Frequency Distribution"],
    "empty": ["Count", "Distinct Count", "Blank Count"]
}


def profile(df):
    rows, cols = df.shape
    stats = []
    types = {}
    blanks = 0
    for c in df.columns:
        s = df[c]
        typ = infer_type(s)
        types[str(c)] = typ
        b = int(_blank(s).sum())
        blanks += b
        clean = s[~_blank(s)]
        stats.append({"column": str(c), "type": typ, "nonBlank": len(clean), "blank": b,
                      "unique": int(clean.astype(str).nunique()),
                      "duplicateValues": int(clean.astype(str).duplicated().sum())})
    completeness = round((1 - blanks / max(1, rows * cols)) * 100, 1)
    dup = int(df.fillna("").astype(str).duplicated().sum())
    score = max(0, round(completeness - min(20, dup / max(1, rows) * 100), 1))
    return {"rows": rows, "columns": cols, "completeness": completeness, "duplicateRows": dup, "score": score,
            "columnNames": [str(c) for c in df.columns], "columnTypes": types, "operations": OPS, "columnStats": stats}


def _numeric_scalar(s, op, col):
    _, parsed, invalid = _numeric_parse(s)
    if invalid:
        raise ValueError(_numeric_error(col, invalid))
    n = parsed.dropna()
    if n.empty:
        return ""
    return {"Sum": n.sum(), "Average": n.mean(), "Minimum": n.min(), "Maximum": n.max(), "Median": n.median()}[op]


def _scalar(s, op, typ, col="column"):
    clean = s[~_blank(s)]
    if op == "Count":
        return len(clean)
    if op == "Distinct Count":
        return int(clean.astype(str).nunique())
    if op == "Blank Count":
        return int(_blank(s).sum())
    if op in ("Sum", "Average", "Minimum", "Maximum", "Median"):
        return _numeric_scalar(s, op, col)
    if typ == "date":
        d = pd.to_datetime(clean, errors="coerce").dropna()
        if d.empty:
            return ""
        if op == "Earliest Date":
            return d.min().isoformat()
        if op == "Latest Date":
            return d.max().isoformat()
        return f"{d.min().isoformat()} → {d.max().isoformat()}"
    if op in ("Most Common Value", "Least Common Value"):
        if clean.empty:
            return ""
        vc = clean.astype(str).value_counts()
        return vc.index[0] if op == "Most Common Value" else vc.index[-1]
    raise ValueError(f"{op} is not valid for {typ} data.")


def _insight(df, col, typ, op, rows):
    s = df[col]
    total = len(s)
    blanks = int(_blank(s).sum())
    clean = s[~_blank(s)]
    bits = []
    if blanks:
        bits.append(f"{blanks} blank value(s) ({round(blanks / max(1, total) * 100, 1)}%).")
    _, n, invalid = _numeric_parse(s)
    if not invalid and len(n.dropna()) and (typ == "numeric" or op in NUMERIC_OPS):
        n = n.dropna()
        bits.append(f"Range {n.min():g} to {n.max():g}; average {n.mean():g}; median {n.median():g}.")
        q1, q3 = n.quantile(.25), n.quantile(.75)
        iqr = q3 - q1
        outliers = int(((n < q1 - 1.5 * iqr) | (n > q3 + 1.5 * iqr)).sum()) if iqr else 0
        if outliers:
            bits.append(f"{outliers} potential IQR outlier(s) detected.")
    elif typ in ("text", "boolean") and len(clean):
        vc = clean.astype(str).value_counts()
        top = vc.iloc[0]
        names = ", ".join(map(str, vc[vc == top].index[:4]))
        bits.append(f"Most frequent: {names} ({int(top)} record(s), {round(top / len(clean) * 100, 1)}%).")
        if len(vc) > 1 and len(vc[vc == top]) > 1:
            bits.append("The most-common value is tied.")
    elif typ == "date" and len(clean):
        d = pd.to_datetime(clean, errors="coerce").dropna()
        if len(d):
            bits.append(f"Dates span {d.min().date()} to {d.max().date()}.")
    return " ".join(bits) or "No notable issue detected for this calculation."


def statistic(df, col, op, group=""):
    if col not in df.columns:
        raise ValueError("Select a valid column.")
    typ = infer_type(df[col])
    if op not in OPS[typ]:
        raise ValueError(f"{op} is not available for {typ} column '{col}'.")
    rows = []
    if op == "Quick Summary":
        _, n, invalid = _numeric_parse(df[col])
        if invalid:
            raise ValueError(_numeric_error(col, invalid))
        clean = n.dropna()
        metrics = [
            ("Records", len(df)), ("Valid Numeric", len(clean)), ("Blank", int(_blank(df[col]).sum())),
            ("Sum", clean.sum() if len(clean) else ""), ("Average", clean.mean() if len(clean) else ""),
            ("Minimum", clean.min() if len(clean) else ""), ("Maximum", clean.max() if len(clean) else ""),
            ("Median", clean.median() if len(clean) else "")
        ]
        rows = [{"label": k, "result": v, "count": "", "percent": "", "interpretation": "Quick Summary"} for k, v in metrics]
    elif op == "Frequency Distribution":
        if group and group in df.columns:
            for k, g in df.groupby(group, dropna=False):
                clean = g[col][~_blank(g[col])].astype(str)
                vc = clean.value_counts()
                den = max(1, len(clean))
                for v, n in vc.items():
                    rows.append({"label": "(blank)" if pd.isna(k) else str(k), "result": str(v), "count": int(n), "percent": round(n / den * 100, 1), "interpretation": "Frequency"})
        else:
            clean = df[col][~_blank(df[col])].astype(str)
            vc = clean.value_counts()
            den = max(1, len(clean))
            for v, n in vc.items():
                rows.append({"label": str(v), "result": str(v), "count": int(n), "percent": round(n / den * 100, 1), "interpretation": "Frequency"})
    elif group and group in df.columns:
        for k, g in df.groupby(group, dropna=False):
            rows.append({"label": "(blank)" if pd.isna(k) else str(k), "result": _scalar(g[col], op, typ, col),
                         "count": len(g), "percent": round(len(g) / max(1, len(df)) * 100, 1), "interpretation": op})
    else:
        val = _scalar(df[col], op, typ, col)
        count = ""
        percent = ""
        clean = df[col][~_blank(df[col])]
        if op in ("Most Common Value", "Least Common Value") and len(clean):
            count = int((clean.astype(str) == str(val)).sum())
            percent = round(count / len(clean) * 100, 1)
        rows = [{"label": f"{op} — {col}", "result": val, "count": count, "percent": percent, "interpretation": op}]
    return {"type": typ, "column": col, "operation": op, "rows": rows, "insight": _insight(df, col, typ, op, rows)}
