# core/common.py
import os
import pandas as pd
from core.utils.logger import get_logger

logger = get_logger("Common")

# Standard store field definitions required by store_validator.py
STORE_FIELDS = [
    "store_code", "store_name", "address", "city",
    "state", "pincode", "phone", "email", "status"
]

# Common column field variations mapping for file creation and validation
ALIASES = {
    "code": "store_code",
    "store code": "store_code",
    "store_id": "store_code",
    "id": "store_code",
    "name": "store_name",
    "store name": "store_name",
    "store": "store_name",
    "addr": "address",
    "street": "address",
    "town": "city",
    "province": "state",
    "postal code": "pincode",
    "zip": "pincode",
    "zipcode": "pincode",
    "mobile": "phone",
    "contact": "phone",
    "mail": "email"
}


def read_table(file_path: str) -> pd.DataFrame:
    """Read a supported dataset without silently dropping malformed records."""
    if not file_path:
        raise ValueError("No file path was provided to the reader.")

    if not os.path.exists(file_path):
        raise FileNotFoundError(f"The file does not exist: {file_path}")

    if not os.path.isfile(file_path):
        raise ValueError(f"The selected path is not a file: {file_path}")

    if not os.access(file_path, os.R_OK):
        raise PermissionError(f"Permission denied. Cannot read file: {file_path}")

    ext = os.path.splitext(file_path)[1].lower()

    try:
        if ext == ".csv":
            try:
                return pd.read_csv(
                    file_path,
                    encoding="utf-8-sig",
                    on_bad_lines="error",
                )
            except UnicodeDecodeError:
                return pd.read_csv(
                    file_path,
                    encoding="cp1252",
                    on_bad_lines="error",
                )

        if ext == ".tsv":
            return pd.read_csv(
                file_path,
                sep="\t",
                encoding="utf-8-sig",
                on_bad_lines="error",
            )

        if ext == ".txt":
            return pd.read_csv(
                file_path,
                sep=None,
                engine="python",
                encoding="utf-8-sig",
                on_bad_lines="error",
            )

        if ext in (".xls", ".xlsx", ".xlsm"):
            return pd.read_excel(file_path)

        raise ValueError(
            f"Unsupported file format: {ext}. "
            "Please use .csv, .tsv, .txt, .xls, .xlsx, or .xlsm."
        )

    except PermissionError as pe:
        logger.error(f"File locked by another process: {file_path}")
        raise PermissionError(
            "The file is currently open in another program (like Excel). "
            "Please close it and try again."
        ) from pe
    except (pd.errors.EmptyDataError, pd.errors.ParserError) as parse_err:
        logger.error(
            f"Malformed or empty file parsing error at {file_path}: {parse_err}"
        )
        raise ValueError(
            "The file is malformed, corrupted, or has inconsistent columns. "
            "No rows were silently discarded."
        ) from parse_err


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


def map_columns(df: pd.DataFrame, mapping: dict) -> pd.DataFrame:
    """
    Maps DataFrame columns according to a given dictionary mapping.
    """
    if df is None or df.empty:
        return df
    try:
        return df.rename(columns=mapping)
    except (TypeError, ValueError) as err:
        logger.error(f"Error mapping columns: {err}")
        return df


def norm_value(val) -> str:
    """
    Normalizes string values for comparison (strips whitespace and lowers case).
    """
    if pd.isna(val):
        return ""
    try:
        return str(val).strip().lower()
    except (ValueError, TypeError):
        return ""


def norm_name(val) -> str:
    """
    Normalizes names/strings for file creation matching.
    """
    return norm_value(val)


def date_ok(val) -> bool:
    """
    Validates whether a value represents a valid date format.
    """
    if pd.isna(val) or not str(val).strip():
        return False
    try:
        pd.to_datetime(val)
        return True
    except (ValueError, TypeError):
        return False


def binary_ok(val) -> bool:
    """
    Validates whether a value represents a valid binary indicator (Yes/No, 1/0, True/False).
    """
    if pd.isna(val):
        return False
    norm = norm_value(val)
    return norm in ["1", "0", "true", "false", "yes", "no", "y", "n"]
