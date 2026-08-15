# Canonical Store Builder schema is maintained in the UI source and backend together.
from __future__ import annotations

import csv
import os
from pathlib import Path
from collections import Counter

import pandas as pd

from core.utils.logger import get_logger

logger = get_logger("Common")

STORE_FIELDS = [
    "Store Name", "SID", "Banner", "Nielsen Store Code", "Trip Received", "Last Trip",
    "Address 1", "Address 2", "Address 3", "ZIP", "Active / Inactive", "Is Census",
    "Is Exceptions", "Updated By",
]
MATCH_FIELDS = ["SID", "Nielsen Store Code"]
REQUIRED_STORE_FIELDS = (
    "Store Name", "SID", "Nielsen Store Code", "Active / Inactive", "Is Census", "Is Exceptions",
)
BINARY_STORE_FIELDS = ("Active / Inactive", "Is Census", "Is Exceptions")
BINARY_TRUE_VALUES = {"1", "true", "yes", "y"}
BINARY_FALSE_VALUES = {"0", "false", "no", "n"}
ALIASES = {
    "Store Name": ["store name", "store", "name", "store_name"],
    "SID": ["sid", "store id", "storeid", "store code", "store_id", "id"],
    "Banner": ["banner", "brand"],
    "Nielsen Store Code": ["nielsen store code", "nielsen code", "nielsen store", "nielsen"],
    "Trip Received": ["trip received", "trip_received"],
    "Last Trip": ["last trip", "last_trip"],
    "Address 1": ["address 1", "address1", "address", "addr", "street", "address line 1"],
    "Address 2": ["address 2", "address2", "address line 2"],
    "Address 3": ["address 3", "address3", "address line 3"],
    "ZIP": ["zip", "zipcode", "zip code", "postal code", "postcode", "pincode", "pin code"],
    "Active / Inactive": ["active / inactive", "active/inactive", "active inactive", "status", "active", "isactive", "is active"],
    "Is Census": ["is census", "census", "census flag", "is_census", "iscensus", "is census"],
    "Is Exceptions": ["is exceptions", "is exception", "exceptions", "exception", "is_exceptions", "isexception", "is exception"],
    "Updated By": ["updated by", "updated_by", "modified by", "modified_by", "last updated by"],
}
LEGACY_ALIASES = {
    "store_code": "SID", "store_name": "Store Name", "address": "Address 1", "pincode": "ZIP",
}


def _normal_header(value: object) -> str:
    return " ".join(str(value or "").strip().lower().replace("_", " ").replace("-", " ").split())


def canonical_field(value: object) -> str:
    normalized = _normal_header(value)
    if not normalized:
        return ""
    for field in STORE_FIELDS:
        if normalized == _normal_header(field) or any(normalized == _normal_header(alias) for alias in ALIASES.get(field, [])):
            return field
    return LEGACY_ALIASES.get(normalized, "")


def canonicalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    if df is None or df.empty:
        return df
    mapping = {}
    used = set()
    for column in df.columns:
        target = canonical_field(column)
        if target and target not in used:
            mapping[column] = target
            used.add(target)
    return df.rename(columns=mapping)


def _read_csv_strict(path: str) -> pd.DataFrame:
    try:
        return pd.read_csv(path, encoding="utf-8-sig", dtype=str, keep_default_na=False, on_bad_lines="error")
    except UnicodeDecodeError:
        return pd.read_csv(path, encoding="cp1252", dtype=str, keep_default_na=False, on_bad_lines="error")


def read_table(file_path: str) -> pd.DataFrame:
    if not file_path:
        raise ValueError("No file path was provided to the reader.")
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"The file does not exist: {file_path}")
    if not path.is_file():
        raise ValueError(f"The selected path is not a file: {file_path}")
    if not os.access(path, os.R_OK):
        raise PermissionError(f"Permission denied. Cannot read file: {file_path}")
    ext = path.suffix.lower()
    try:
        if ext == ".csv": return _read_csv_strict(str(path))
        if ext == ".tsv": return pd.read_csv(str(path), sep="\t", encoding="utf-8-sig", dtype=str, keep_default_na=False, on_bad_lines="error")
        if ext == ".txt": return pd.read_csv(str(path), sep=None, engine="python", encoding="utf-8-sig", dtype=str, keep_default_na=False, on_bad_lines="error")
        if ext in {".xls", ".xlsx", ".xlsm"}: return pd.read_excel(str(path), dtype=str).fillna("")
        if ext == ".json": return pd.read_json(str(path)).fillna("")
        if ext == ".xml": return pd.read_xml(str(path)).fillna("")
        raise ValueError("Unsupported file format. Use CSV, TSV/TXT, Excel, JSON, or XML.")
    except PermissionError as exc:
        logger.error("File locked or inaccessible: %s", file_path)
        raise PermissionError("The file is currently open or inaccessible. Close it and try again.") from exc
    except (pd.errors.EmptyDataError, pd.errors.ParserError, ValueError) as exc:
        logger.error("Malformed input %s: %s", file_path, exc)
        raise ValueError(f"The file could not be read safely: {exc}") from exc


def clean_value(val) -> str:
    if val is None: return ""
    try:
        if pd.isna(val): return ""
    except (TypeError, ValueError):
        pass
    return str(val).strip()


def norm_value(val) -> str:
    return clean_value(val).casefold()


def norm_name(val) -> str:
    return norm_value(val)


def date_ok(val) -> bool:
    text = clean_value(val)
    if not text: return False
    try: return not pd.isna(pd.to_datetime(text, errors="raise"))
    except (ValueError, TypeError): return False


def binary_ok(val) -> bool:
    return norm_value(val) in BINARY_TRUE_VALUES | BINARY_FALSE_VALUES


def normalize_binary_value(value) -> str:
    normalized = norm_value(value)
    if normalized in BINARY_TRUE_VALUES:
        return "1"
    if normalized in BINARY_FALSE_VALUES:
        return "0"
    return clean_value(value)


def suggested_numeric_width(values) -> int:
    widths = [len(clean_value(value)) for value in values if clean_value(value).isdigit()]
    if not widths:
        return 0
    counts = Counter(widths)
    top = max(counts.values())
    return max(width for width, count in counts.items() if count == top)


def normalize_nielsen_code(value, width: int = 0) -> str:
    text = clean_value(value)
    if not text or not text.isdigit() or not width:
        return text
    return text.zfill(int(width))


def normalize_store_row(row: dict, nielsen_width: int = 0) -> dict:
    """Return a canonical Store Builder row with backend-owned normalization."""
    normalized = {field: clean_value(row.get(field, "")) for field in STORE_FIELDS}
    for field in BINARY_STORE_FIELDS:
        normalized[field] = normalize_binary_value(normalized[field])
    normalized["Nielsen Store Code"] = normalize_nielsen_code(
        normalized["Nielsen Store Code"], nielsen_width
    )
    return normalized


def normalize_store_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Canonicalize and normalize store records without changing source columns unnecessarily."""
    if df is None:
        return df
    frame = canonicalize_columns(df.copy()).fillna("").astype(str)
    if "Nielsen Store Code" in frame.columns:
        width = suggested_numeric_width(frame["Nielsen Store Code"].tolist())
        frame["Nielsen Store Code"] = frame["Nielsen Store Code"].map(
            lambda value: normalize_nielsen_code(value, width)
        )
    for field in BINARY_STORE_FIELDS:
        if field in frame.columns:
            frame[field] = frame[field].map(normalize_binary_value)
    return frame


def parse_delimited_text(text: str) -> list[list[str]]:
    text = str(text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not text.strip(): return []
    delimiter = "\t" if "\t" in text[:4096] else ","
    return [row for row in csv.reader(text.splitlines(), delimiter=delimiter)]


def json_value(val):
    try:
        if pd.isna(val): return ""
        if isinstance(val, (int, float, str, bool)): return val
        return str(val)
    except (ValueError, TypeError): return str(val)


def map_columns(df: pd.DataFrame, mapping: dict) -> pd.DataFrame:
    if df is None or df.empty: return df
    try: return df.rename(columns=mapping)
    except (TypeError, ValueError) as err: raise ValueError(f"Invalid column mapping: {err}") from err
