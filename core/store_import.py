# core/store_import.py
import os
import pandas as pd
from core.utils.logger import get_logger

logger = get_logger("StoreImport")

def import_store_data(file_path: str) -> pd.DataFrame:
    """
    Safely imports and validates raw store data from CSV or Excel files.
    """
    if not file_path:
        raise ValueError("No file path provided for import.")

    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Import file does not exist: {file_path}")

    if not os.access(file_path, os.R_OK):
        raise PermissionError(f"Permission denied reading file: {file_path}")

    ext = os.path.splitext(file_path)[1].lower()

    try:
        if ext == '.csv':
            df = pd.read_csv(file_path, encoding='utf-8-sig', on_bad_lines='skip')
        elif ext in ['.xls', '.xlsx']:
            df = pd.read_excel(file_path)
        else:
            raise ValueError(f"Unsupported file extension: {ext}")

        if df is None or df.empty:
            raise ValueError("The imported dataset contains no rows or is corrupted.")

        return df

    except FileNotFoundError as fnf:
        logger.error(f"File missing during import: {fnf}")
        raise
    except PermissionError as pe:
        logger.error(f"File locked or permission denied: {pe}")
        raise PermissionError("The file is open in another program (like Excel). Please close it.") from pe
    except ValueError as ve:
        logger.error(f"Value/Format error during import: {ve}")
        raise
    except pd.errors.ParserError as parse_err:
        logger.error(f"Malformed file parsing error: {parse_err}")
        raise ValueError("The file layout is corrupted or malformed. Please check the structure.") from parse_err
    except Exception as e:
        # Final boundary catch for unpredicted parser/system failures
        logger.exception(f"Unexpected critical error importing file {file_path}")
        raise RuntimeError("An unexpected error occurred while processing the import file.") from e
