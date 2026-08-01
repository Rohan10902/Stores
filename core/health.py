# core/health.py
import os
import pandas as pd
from core.utils.logger import get_logger

logger = get_logger("Health")


def check_dataset_health(file_path: str) -> dict:
    """
    Performs a health check on a dataset, evaluating missing values, 
    row counts, and structural integrity.
    """
    if not file_path or not os.path.exists(file_path):
        raise FileNotFoundError(f"Health check failed: File not found at {file_path}")

    try:
        ext = os.path.splitext(file_path)[1].lower()
        if ext == '.csv':
            df = pd.read_csv(file_path, encoding='utf-8-sig', on_bad_lines='skip')
        elif ext in ['.xls', '.xlsx']:
            df = pd.read_excel(file_path)
        else:
            raise ValueError(f"Unsupported health check file format: {ext}")

        total_rows = len(df)
        total_cols = len(df.columns)
        missing_cells = int(df.isnull().sum().sum())
        
        return {
            "status": "HEALTHY" if total_rows > 0 else "EMPTY",
            "rows": total_rows,
            "columns": total_cols,
            "missingCells": missing_cells,
            "issues": []
        }

    except FileNotFoundError as fnf:
        logger.error(f"File missing during health check: {fnf}")
        raise
    except (ValueError, TypeError) as ve:
        logger.error(f"Value or type error during health analysis: {ve}")
        raise ValueError(f"Invalid dataset structure for health check: {ve}") from ve
    except OSError as oe:
        logger.error(f"OS error reading file for health check: {oe}")
        raise OSError(f"Could not read file due to OS restriction: {oe}") from oe


def profile(df: pd.DataFrame) -> dict:
    """
    Generates dataset profiling statistics required by health_controller.py.
    """
    if df is None or df.empty:
        return {"columns": {}, "rowCount": 0, "columnCount": 0}
    
    try:
        profile_data = {
            "rowCount": len(df),
            "columnCount": len(df.columns),
            "columns": {}
        }
        for col in df.columns:
            series = df[col]
            profile_data["columns"][str(col)] = {
                "nullCount": int(series.isnull().sum()),
                "uniqueCount": int(series.nunique()),
                "dtype": str(series.dtype)
            }
        return profile_data
    except Exception as e:
        logger.exception("Error generating dataset profile")
        raise RuntimeError("Failed to generate dataset profile.") from e


def statistic(df: pd.DataFrame) -> dict:
    """
    Computes statistical summaries required by health_controller.py.
    """
    if df is None or df.empty:
        return {}
    try:
        return df.describe(include='all').fillna("").to_dict()
    except Exception as e:
        logger.exception("Error computing statistics")
        raise RuntimeError("Failed to compute dataset statistics.") from e


def export_html_report(health_data: dict, dst_path: str) -> None:
    """
    Exports health check and profile results to an HTML report file.
    """
    if not dst_path:
        raise ValueError("Destination path cannot be empty.")
        
    try:
        html_content = f"""
        <html>
        <head><title>Dataset Health Report</title></head>
        <body>
            <h1>Dataset Health Report</h1>
            <p>Status: {health_data.get('status', 'UNKNOWN')}</p>
            <p>Rows: {health_data.get('rows', 0)}</p>
            <p>Columns: {health_data.get('columns', 0)}</p>
            <p>Missing Cells: {health_data.get('missingCells', 0)}</p>
        </body>
        </html>
        """
        with open(dst_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        logger.info(f"Successfully exported HTML report to {dst_path}")
    except OSError as oe:
        logger.error(f"OS error writing HTML report to {dst_path}: {oe}")
        raise OSError("Could not write HTML report file.") from oe
    except Exception as e:
        logger.exception("Unexpected error exporting HTML report")
        raise RuntimeError("Failed to export HTML report.") from e
