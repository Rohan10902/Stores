# core/common.py
import os
import pandas as pd
from core.utils.logger import get_logger

logger = get_logger("Common")


def read_table(file_path: str) -> pd.DataFrame:
    """
    Safely reads CSV or Excel files into a Pandas DataFrame.
    Includes strict defensive checks for file existence, permissions, and formats.
    """
    if not file_path:
        raise ValueError("No file path was provided to the reader.")
        
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"The file does not exist: {file_path}")
        
    if not os.access(file_path, os.R_OK):
        raise PermissionError(f"Permission denied. Cannot read file: {file_path}")
        
    ext = os.path.splitext(file_path)[1].lower()
    
    try:
        if ext == '.csv':
            return pd.read_csv(file_path, encoding='utf-8-sig', on_bad_lines='skip')
        elif ext in ['.xls', '.xlsx']:
            return pd.read_excel(file_path)
        else:
            raise ValueError(f"Unsupported file format: {ext}. Please use .csv, .xls, or .xlsx")
            
    except PermissionError as pe:
        logger.error(f"File locked by another process: {file_path}")
        raise PermissionError("The file is currently open in another program (like Excel). Please close it and try again.") from pe
    except (pd.errors.EmptyDataError, pd.errors.ParserError) as parse_err:
        logger.error(f"Malformed or empty file parsing error at {file_path}: {parse_err}")
        raise ValueError("The file is malformed, corrupted, or empty.") from parse_err


def json_value(val):
    """
    Safely converts pandas/numpy data types to JSON-serializable Python native types.
    Prevents TypeError crashes during json.dumps().
    """
    try:
        if pd.isna(val):
            return ""
        if isinstance(val, (int, float, str, bool)):
            return val
        return str(val)
    except (ValueError, TypeError) as err:
        logger.warning(f"Failed to parse cell value, converting to string: {err}")
        return str(val)
