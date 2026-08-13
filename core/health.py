import os
import tempfile
from pathlib import Path

import pandas as pd

from core.common import read_table
from core.utils.logger import get_logger

logger = get_logger("Health")


def check_dataset_health(file_path: str) -> dict:
    if not file_path or not os.path.exists(file_path):
        raise FileNotFoundError(f"Health check failed: File not found at {file_path}")
    try:
        df = read_table(file_path)
        total_rows = len(df)
        total_cols = len(df.columns)
        missing_cells = int(df.isnull().sum().sum())
        return {
            "status": "HEALTHY" if total_rows > 0 else "EMPTY",
            "rows": total_rows,
            "columns": total_cols,
            "missingCells": missing_cells,
            "issues": [],
        }
    except Exception:
        logger.exception("Health check failed.")
        raise


def profile(df: pd.DataFrame) -> dict:
    if df is None or df.empty:
        return {"columns": {}, "rowCount": 0, "columnCount": 0}
    data = {"rowCount": len(df), "columnCount": len(df.columns), "columns": {}}
    for column in df.columns:
        series = df[column]
        data["columns"][str(column)] = {
            "nullCount": int(series.isnull().sum()),
            "uniqueCount": int(series.nunique()),
            "dtype": str(series.dtype),
        }
    return data


def statistic(df: pd.DataFrame, col: str = "", op: str = "", group: str = "") -> dict:
    if df is None or df.empty:
        return {"columns": [], "rows": []}
    if not col or not op:
        return df.describe(include="all").fillna("").to_dict()
    if col not in df.columns:
        raise ValueError(f"Column not found: {col}")
    operation = str(op).strip().lower()
    if group:
        if group not in df.columns:
            raise ValueError(f"Group column not found: {group}")
        grouped = df.groupby(group, dropna=False)[col]
        if operation in ("count", "size"):
            result = grouped.count()
        elif operation == "sum":
            result = pd.to_numeric(grouped.obj[col], errors="coerce").groupby(df[group], dropna=False).sum()
        elif operation == "mean":
            result = pd.to_numeric(grouped.obj[col], errors="coerce").groupby(df[group], dropna=False).mean()
        elif operation == "min":
            result = grouped.min()
        elif operation == "max":
            result = grouped.max()
        elif operation == "median":
            result = pd.to_numeric(grouped.obj[col], errors="coerce").groupby(df[group], dropna=False).median()
        elif operation == "nunique":
            result = grouped.nunique()
        else:
            raise ValueError(f"Unsupported statistic operation: {op}")
        rows = []
        for key, value in result.items():
            if hasattr(key, "item"):
                key = key.item()
            if hasattr(value, "item"):
                value = value.item()
            rows.append({str(group): "" if pd.isna(key) else str(key), str(op): "" if pd.isna(value) else value})
        return {"columns": [str(group), str(op)], "rows": rows, "operation": op, "column": col, "group": group}

    series = df[col]
    if operation in ("count", "size"):
        value = int(series.count())
    elif operation == "nunique":
        value = int(series.nunique())
    elif operation == "nulls":
        value = int(series.isnull().sum())
    elif operation == "mean":
        value = float(pd.to_numeric(series, errors="coerce").mean())
    elif operation == "sum":
        value = float(pd.to_numeric(series, errors="coerce").sum())
    elif operation == "min":
        value = series.min()
    elif operation == "max":
        value = series.max()
    elif operation == "median":
        value = float(pd.to_numeric(series, errors="coerce").median())
    else:
        raise ValueError(f"Unsupported statistic operation: {op}")
    if pd.isna(value):
        value = ""
    if hasattr(value, "item"):
        value = value.item()
    return {"column": col, "operation": op, "group": group, "value": value}


def export_html_report(health_data, dst_path: str) -> None:
    if not dst_path:
        raise ValueError("Destination path cannot be empty.")
    if isinstance(health_data, pd.DataFrame):
        health_data = check_dataframe_health(health_data)
    if not isinstance(health_data, dict):
        raise TypeError("Health report data must be a dictionary.")
    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Dataset Health Report</title>
<style>body {{ font-family: Arial, sans-serif; margin: 40px; }} .card {{ padding: 16px; margin-bottom: 12px; border: 1px solid #ddd; border-radius: 8px; }}</style>
</head><body><h1>Dataset Health Report</h1>
<div class="card"><strong>Status:</strong> {health_data.get("status", "UNKNOWN")}</div>
<div class="card"><strong>Rows:</strong> {health_data.get("rows", 0)}</div>
<div class="card"><strong>Columns:</strong> {health_data.get("columns", 0)}</div>
<div class="card"><strong>Missing Cells:</strong> {health_data.get("missingCells", 0)}</div>
</body></html>"""
    destination = Path(dst_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{destination.stem}.", suffix=".tmp", dir=str(destination.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            file.write(html)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp_name, destination)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def check_dataframe_health(df):
    if df is None:
        return {"status": "EMPTY", "rows": 0, "columns": 0, "missingCells": 0}
    rows = len(df)
    columns = len(df.columns)
    missing = int(df.isnull().sum().sum())
    return {"status": "HEALTHY" if rows > 0 else "EMPTY", "rows": rows, "columns": columns, "missingCells": missing}
