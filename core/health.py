# core/health.py
import os
import pandas as pd
from core.utils.logger import get_logger

logger = get_logger("Health")

def profile(df: pd.DataFrame) -> dict:
    """
    Generates a statistical health profile for the given DataFrame.
    """
    if df is None or df.empty:
        raise ValueError("Cannot profile an empty or null DataFrame.")

    try:
        profile_data = {
            "row_count": len(df),
            "column_count": len(df.columns),
            "columns": list(df.columns),
            "missing_values": df.isnull().sum().to_dict(),
            "duplicate_rows": int(df.duplicated().sum())
        }
        return profile_data
    except (ValueError, KeyError, TypeError) as err:
        logger.error(f"Error computing dataset profile: {err}")
        raise ValueError("Failed to compute dataset profile due to malformed data.") from err
    except Exception as e:
        logger.exception("Unexpected error during data profiling.")
        raise RuntimeError("An unexpected error occurred while profiling the dataset.") from e

def statistic(df: pd.DataFrame, col: str, op: str, group: str = None) -> dict:
    """
    Computes statistical aggregations on columns.
    """
    if df is None or df.empty:
        raise ValueError("Dataset is empty.")
    if col and col not in df.columns:
        raise KeyError(f"Column '{col}' not found in dataset.")
    if group and group not in df.columns:
        raise KeyError(f"Group column '{group}' not found in dataset.")

    try:
        # Example metric tracking logic based on operation
        result = {}
        if op == "sum":
            result = df.groupby(group)[col].sum().to_dict() if group else {"total": float(df[col].sum())}
        elif op == "mean":
            result = df.groupby(group)[col].mean().to_dict() if group else {"mean": float(df[col].mean())}
        elif op == "count":
            result = df.groupby(group)[col].count().to_dict() if group else {"count": int(df[col].count())}
        else:
            raise ValueError(f"Unsupported statistical operation: {op}")
        return result
    except KeyError as ke:
        logger.error(f"Column missing during stats calculation: {ke}")
        raise
    except (TypeError, ValueError) as ve:
        logger.error(f"Type/Value error during stats calculation: {ve}")
        raise ValueError(f"Cannot perform operation '{op}' on column '{col}'. Check data types.") from ve
    except Exception as e:
        logger.exception("Unexpected error calculating statistics.")
        raise RuntimeError("An unexpected error occurred while calculating statistics.") from e

def export_html_report(df: pd.DataFrame, dst_path: str) -> str:
    """
    Exports a standalone executive health HTML report.
    """
    if df is None or df.empty:
        raise ValueError("Cannot export report for an empty dataset.")
    if not dst_path:
        raise ValueError("Destination path is required.")

    target_dir = os.path.dirname(dst_path)
    if target_dir and not os.path.exists(target_dir):
        try:
            os.makedirs(target_dir, exist_ok=True)
        except OSError as oe:
            logger.error(f"Failed to create directory for report: {target_dir}")
            raise OSError(f"Could not create target directory: {target_dir}") from oe

    if os.path.exists(dst_path) and not os.access(dst_path, os.W_OK):
        raise PermissionError("Permission denied. The report file may be open in another application.")

    try:
        html_content = f"""
        <html>
        <head><title>StoreLens Health Report</title></head>
        <body>
            <h1>StoreLens Health Report</h1>
            <p>Total Rows: {len(df)}</p>
            <p>Total Columns: {len(df.columns)}</p>
        </body>
        </html>
        """
        with open(dst_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
            
        logger.info(f"Successfully exported health report to {dst_path}")
        return dst_path
        
    except PermissionError as pe:
        logger.error(f"Permission denied writing HTML report to {dst_path}: {pe}")
        raise
    except OSError as oe:
        logger.error(f"OS error writing HTML report to {dst_path}: {oe}")
        raise RuntimeError("An OS error occurred while writing the report file.") from oe
    except Exception as e:
        logger.exception("Unexpected error generating health report.")
        raise RuntimeError("An unexpected error occurred while generating the report.") from e
