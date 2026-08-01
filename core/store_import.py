# core/store_import.py
import os
import pandas as pd
from core.utils.logger import get_logger

logger = get_logger("StoreImport")


def import_stores(file_path: str) -> list:
    """
    Imports store records from a validated source file.
    """
    if not file_path or not os.path.exists(file_path):
        raise FileNotFoundError(f"Import file not found: {file_path}")

    try:
        ext = os.path.splitext(file_path)[1].lower()
        if ext == '.csv':
            df = pd.read_csv(file_path, encoding='utf-8-sig')
        elif ext in ['.xls', '.xlsx']:
            df = pd.read_excel(file_path)
        else:
            raise ValueError(f"Unsupported import format: {ext}")

        if df.empty:
            return []

        records = df.to_dict(orient='records')
        return records

    except FileNotFoundError as fnf:
        logger.error(f"Import file not found: {fnf}")
        raise
    except (pd.errors.EmptyDataError, pd.errors.ParserError) as pe:
        logger.error(f"Failed to parse import file: {pe}")
        raise ValueError("The import file is empty or malformed.") from pe
    except OSError as oe:
        logger.error(f"OS error during store import: {oe}")
        raise OSError(f"System error accessing import file: {oe}") from oe
