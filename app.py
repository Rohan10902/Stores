# core/common.py
import os
import pandas as pd
from core.utils.logger import get_logger

logger = get_logger("Common")

def read_table(file_path: str) -> pd.DataFrame:
    if not file_path:
        raise ValueError("No file path provided.")
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")
    if not os.access(file_path, os.R_OK):
        raise PermissionError(f"Permission denied: {file_path}")

    ext = os.path.splitext(file_path)[1].lower()
    try:
        if ext == '.csv':
            return pd.read_csv(file_path, encoding='utf-8-sig', on_bad_lines='skip')
        elif ext in ['.xls', '.xlsx']:
            return pd.read_excel(file_path)
        else:
            raise ValueError(f"Unsupported format: {ext}")
    except (pd.errors.EmptyDataError, pd.errors.ParserError) as err:
        logger.error(f"Malformed table file at {file_path}: {err}")
        raise ValueError("The file is malformed or corrupted.") from err
    except PermissionError:
        logger.error(f"File locked by another process: {file_path}")
        raise PermissionError("File is open in another program (like Excel). Please close it.")

def json_value(val):
    try:
        if pd.isna(val):
            return ""
        if isinstance(val, (int, float, str, bool)):
            return val
        return str(val)
    except (ValueError, TypeError) as err:
        logger.warning(f"Failed to parse cell value: {err}")
        return str(val)
