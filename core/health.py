import re
import pandas as pd

_IDENTIFIER = re.compile(r"(^|\b)(sid|id|code|zip|postal|postcode|pincode|pin)(\b|$)", re.I)

def _blank(s):
    return s.isna() | s.astype(str).str.strip().eq("")

def infer_type(s, name=""):
    x = s[~_blank(s)]
    if x.empty: return "empty"
    if _IDENTIFIER.search(str(name)): return "text"
    vals = set(x.astype(str).str.strip().str.lower().unique())
    if vals and vals.issubset({"0","1","true","false","yes","no","y","n"}): return "boolean"
    if pd.to_numeric(x, errors="coerce").notna().mean() >= .95: return "numeric"
    txt = x.astype(str)
    if txt.str.contains(r"[-/:]|[A-Za-z]{3,}", regex=True).mean() >= .8 and pd.to_datetime(x, errors="coerce").notna().mean() >= .95:
        return "date"
    return "text"

OPS = {
    "numeric": ["Quick Summary", "Count", "Distinct Count", "Blank Count", "Sum", "Average", "Minimum", "Maximum", "Median"],
    "date": ["Count", "Distinct Count", "Blank Count", "Earliest Date", "Latest Date", "Date Range"],
    "boolean": ["Count", "Distinct Count", "Blank Count", "Most Common Value", "Least Common Value", "Frequency Distribution"],
    "text": ["Count", "Distinct Count", "Blank Count", "Most Common Value", "Least Common Value", "Frequency Distribution"],
    "empty": ["Count", "Distinct Count", "Blank Count"]
}

def profile(df):
    rows, cols = df.shape
    stats = []
    types = {}
    blanks = 0
    column_details = []

    for c in df.columns:
        s = df[c]
        typ = infer_type(s, str(c))
        types[str(c)] = typ
        b = int(_blank(s).sum())
        blanks += b
        clean = s[~_blank(s)]
        non_blank_cnt = len(clean)
        unique_cnt = int(clean.astype(str).nunique()) if len(clean) else 0
        
        column_details.append({
            "column": str(c),
            "type": typ.upper(),
            "non_blank": str(non_blank_cnt),
            "blank": str(b),
            "unique": str(unique_cnt)
        })

    total_cells = max(1, rows * cols)
    completeness = round((1 - (blanks / total_cells)) * 100, 1)
    dup = int(df.fillna("").astype(str).duplicated().sum())
    score = max(0, round(completeness - min(20, (dup / max(1, rows)) * 100), 1))

    return {
        "rows": rows,
        "columns": cols,
        "completeness": completeness,
        "duplicates": dup,
        "duplicateRows": dup,
        "health_score": score,
        "score": score,
        "column_details": column_details,
        "columnStats": stats
    }

def statistic(df, col, op, group=""):
    if col not in df.columns:
        return {"results": [{"metric": "Error", "result": f"Column '{col}' not found"}]}
    
    results = []
    try:
        clean = df[col][~_blank(df[col])]
        if op == "Quick Summary":
            results.append({"metric": "Total Records", "result": str(len(df))})
            results.append({"metric": "Valid Values", "result": str(len(clean))})
            results.append({"metric": "Blank Count", "result": str(int(_blank(df[col]).sum()))})
            results.append({"metric": "Unique Count", "result": str(int(clean.nunique())) if len(clean) else "0"})
            nums = pd.to_numeric(clean, errors="coerce").dropna()
            if len(nums):
                results.append({"metric": "Mean", "result": f"{nums.mean():.2f}"})
                results.append({"metric": "Min", "result": str(nums.min())})
                results.append({"metric": "Max", "result": str(nums.max())})
        elif op == "Frequency Distribution":
            vc = clean.astype(str).value_counts().head(10)
            for val, cnt in vc.items():
                results.append({"metric": str(val), "result": f"{cnt} row(s)"})
        else:
            results.append({"metric": f"{op} ({col})", "result": str(len(clean))})
    except Exception as e:
        results.append({"metric": "Error", "result": str(e)})

    return {"results": results, "rows": results}
