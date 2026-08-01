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
