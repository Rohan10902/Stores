import re
import pandas as pd
from pathlib import Path

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

def _outliers(nums, limit=10):
    if len(nums) < 4:
        return None
    q1, q3 = nums.quantile(0.25), nums.quantile(0.75)
    iqr = q3 - q1
    if iqr == 0:
        return nums.iloc[0:0]
    lo, hi = q1 - 1.5 * iqr, q3 + 1.5 * iqr
    return nums[(nums < lo) | (nums > hi)].head(limit)


def _statistic_group(gdf, col, op, prefix=""):
    results = []
    clean = gdf[col][~_blank(gdf[col])]
    if op in ("Summary", "Quick Summary"):
        results.append({"metric": f"{prefix}Total Records", "result": str(len(gdf))})
        results.append({"metric": f"{prefix}Populated Values", "result": str(len(clean))})
        results.append({"metric": f"{prefix}Blank Cell Count", "result": str(int(_blank(gdf[col]).sum()))})
        results.append({"metric": f"{prefix}Unique Values", "result": str(int(clean.nunique())) if len(clean) else "0"})
        nums = pd.to_numeric(clean, errors="coerce").dropna()
        if len(nums):
            results.append({"metric": f"{prefix}Numeric Mean", "result": f"{nums.mean():.2f}"})
            results.append({"metric": f"{prefix}Minimum", "result": str(nums.min())})
            results.append({"metric": f"{prefix}Maximum", "result": str(nums.max())})
    elif op in ("Frequency", "Frequency Distribution"):
        counts = clean.astype(str).value_counts().head(10)
        for val, cnt in counts.items():
            results.append({"metric": f"{prefix}{val}", "result": f"{cnt} row(s)"})
    elif op == "Average":
        nums = pd.to_numeric(clean, errors="coerce").dropna()
        if len(nums):
            results.append({"metric": f"{prefix}Average ({col})", "result": f"{nums.mean():.2f}"})
        else:
            results.append({"metric": f"{prefix}Average ({col})", "result": "No numeric values found"})
    elif op == "Outliers":
        nums = pd.to_numeric(clean, errors="coerce").dropna()
        found = _outliers(nums)
        if found is None:
            results.append({"metric": f"{prefix}Outliers ({col})", "result": "Not enough numeric values"})
        elif found.empty:
            results.append({"metric": f"{prefix}Outliers ({col})", "result": "None detected"})
        else:
            for val in found:
                results.append({"metric": f"{prefix}Outlier", "result": str(val)})
    else:
        results.append({"metric": f"{prefix}{op} ({col})", "result": str(len(clean))})
    return results


def statistic(df, col, op, group=""):
    if col not in df.columns:
        return {"results": [{"metric": "Error", "result": f"Column '{col}' not found"}]}

    results = []
    try:
        group_col = group if group and group != "None" and group in df.columns else ""
        if group_col:
            for gval, gdf in df.groupby(df[group_col].astype(str)):
                results.extend(_statistic_group(gdf, col, op, prefix=f"[{group_col}={gval}] "))
        else:
            results.extend(_statistic_group(df, col, op))
    except Exception as e:
        results.append({"metric": "Error", "result": str(e)})

    return {"results": results, "rows": results}

def export_html_report(df, output_path):
    prof = profile(df)
    path = Path(output_path)
    
    html = f"""<!DOCTYPE html>
<html>
<head>
    <title>StoreLens Executive Health Audit</title>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0b1829; color: #f8fafc; padding: 24px; }}
        .header {{ border-bottom: 2px solid #1e293b; padding-bottom: 12px; margin-bottom: 20px; }}
        .cards {{ display: flex; gap: 16px; margin-bottom: 24px; }}
        .card {{ background: #0f172a; border: 1px solid #1e293b; border-radius: 8px; padding: 16px; flex: 1; text-align: center; }}
        .metric {{ font-size: 28px; font-weight: bold; color: #3b82f6; }}
        table {{ width: 100%; border-collapse: collapse; background: #0f172a; border-radius: 8px; overflow: hidden; }}
        th, td {{ padding: 10px 14px; text-align: left; border-bottom: 1px solid #1e293b; }}
        th {{ background: #1e293b; color: #94a3b8; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>StoreLens 7.2.1 — Data Health & Quality Report</h1>
        <p style="color: #94a3b8;">Local Data Audit Summary</p>
    </div>
    <div class="cards">
        <div class="card"><div class="metric">{prof['health_score']}/100</div><div>Health Score</div></div>
        <div class="card"><div class="metric">{prof['completeness']}%</div><div>Completeness</div></div>
        <div class="card"><div class="metric">{prof['rows']:,}</div><div>Total Rows</div></div>
        <div class="card"><div class="metric">{prof['duplicates']:,}</div><div>Duplicates</div></div>
    </div>
    <h2>Column Quality Analysis</h2>
    <table>
        <thead><tr><th>Column Name</th><th>Detected Type</th><th>Non-Blank Rows</th><th>Blank Rows</th><th>Unique Values</th></tr></thead>
        <tbody>
"""
    for col in prof['column_details']:
        html += f"<tr><td><b>{col['column']}</b></td><td>{col['type']}</td><td style='color:#4ade80;'>{col['non_blank']}</td><td style='color:#ef4444;'>{col['blank']}</td><td>{col['unique']}</td></tr>\n"

    html += """</tbody></table></body></html>"""
    path.write_text(html, encoding="utf-8")
    return str(path)
