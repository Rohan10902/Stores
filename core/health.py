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

def profile(df):
    rows, cols = df.shape
    column_details = []
    blanks = 0

    for c in df.columns:
        s = df[c]
        typ = infer_type(s, str(c))
        b = int(_blank(s).sum())
        blanks += b
        clean = s[~_blank(s)]
        
        column_details.append({
            "column": str(c),
            "type": typ.upper(),
            "non_blank": str(len(clean)),
            "blank": str(b),
            "unique": str(int(clean.astype(str).nunique())) if len(clean) else "0"
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
        "health_score": score,
        "column_details": column_details
    }

def statistic(df, col, op, group=""):
    if col not in df.columns:
        return {"results": [{"metric": "Error", "result": f"Column '{col}' not found"}]}
    
    results = []
    try:
        clean = df[col][~_blank(df[col])]
        
        if op in ("Summary", "Quick Summary"):
            results.append({"metric": "Total Records", "result": str(len(df))})
            results.append({"metric": "Populated Values", "result": str(len(clean))})
            results.append({"metric": "Blank Cell Count", "result": str(int(_blank(df[col]).sum()))})
            results.append({"metric": "Unique Values", "result": str(int(clean.nunique())) if len(clean) else "0"})
            nums = pd.to_numeric(clean, errors="coerce").dropna()
            if len(nums):
                results.append({"metric": "Numeric Average (Mean)", "result": f"{nums.mean():.2f}"})
                results.append({"metric": "Minimum Value", "result": str(nums.min())})
                results.append({"metric": "Maximum Value", "result": str(nums.max())})
        elif op in ("Frequency", "Frequency Distribution"):
            counts = clean.astype(str).value_counts().head(10)
            for val, cnt in counts.items():
                results.append({"metric": str(val), "result": f"{cnt} row(s)"})
        elif op == "Average":
            nums = pd.to_numeric(clean, errors="coerce").dropna()
            results.append({"metric": f"Mean of {col}", "result": f"{nums.mean():.2f}" if len(nums) else "No numeric data"})
        elif op in ("Outliers", "IQR Outliers"):
            nums = pd.to_numeric(clean, errors="coerce").dropna()
            if len(nums):
                q1, q3 = nums.quantile(0.25), nums.quantile(0.75)
                iqr = q3 - q1
                outliers = nums[(nums < (q1 - 1.5 * iqr)) | (nums > (q3 + 1.5 * iqr))]
                results.append({"metric": "Detected Outliers (IQR)", "result": str(len(outliers))})
            else:
                results.append({"metric": "Detected Outliers (IQR)", "result": "0"})
        else:
            results.append({"metric": f"{op} ({col})", "result": str(len(clean))})
    except Exception as e:
        results.append({"metric": "Calculation Exception", "result": str(e)})

    return {"results": results, "rows": results}
