# core/common.py
"""Shared data-model, normalization, and safe table-loading primitives."""

from __future__ import annotations

import csv
import json
import os
from pathlib import Path

import pandas as pd

from core.utils.logger import get_logger

logger = get_logger("Common")

# Canonical Store Builder / creator export schema.
# Keep this list authoritative: UI, validation, creator, and export all consume it.
STORE_FIELDS = [
    "Store Name",
    "SID",
    "Banner",
    "Nielsen Store Code",
    "Trip Received",
    "Last Trip",
    "Address 1",
    "Address 2",
    "City",
    "State",
    "Pincode",
    "Phone",
]

# Fields that can participate in identity matching. The canonical schema remains
# the source of truth; matching only uses fields that are present in both files.
MATCH_FIELDS = [
    "SID",
    "Nielsen Store Code",
]

ALIASES = {
    "Store Name": ["store name", "store", "name", "store_name"],
    "SID": ["sid", "store id", "storeid", "store code", "store_id", "id"],
    "Banner": ["banner", "brand"],
    "Nielsen Store Code": ["nielsen store code", "nielsen code", "nielsen store", "nielsen"],
    "Trip Received": ["trip received", "trip_received"],
    "Last Trip": ["last trip", "last_trip"],
    "Address 1": ["address 1", "address1", "address", "addr", "street"],
    "Address 2": ["address 2", "address2", "address line 2"],
    "City": ["city", "town"],
    "State": ["state", "province"],
    "Pincode": ["pincode", "pin code", "postal code", "zip", "zipcode", "postcode"],
    "Phone": ["phone", "mobile", "contact", "telephone"],
}

# Legacy aliases retained for datasets created by earlier StoreLens versions.
LEGACY_ALIASES = {
    "store_code": "SID",
    "store_name": "Store Name",
    "address": "Address 1",
    "city": "City",
    "state": "State",
    "pincode": "Pincode",
    "phone": "Phone",
    "status": "Banner",
    "email": "Phone",
}


def _normal_header(value: object) -> str:
    return " ".join(str(value or "").strip().lower().replace("_", " ").replace("-", " ").split())


def canonical_field(value: object) -> str:
    """Return the canonical field name for a header, or an empty string."""
    normalized = _normal_header(value)
    if not normalized:
        return ""
    for field in STORE_FIELDS:
        if normalized == _normal_header(field):
            return field
        if any(normalized == _normal_header(alias) for alias in ALIASES.get(field, [])):
            return field
    legacy = LEGACY_ALIASES.get(normalized)
    return legacy or ""


def canonicalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Rename recognizable columns to the canonical schema without dropping unknowns."""
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
    # Let pandas surface malformed CSV instead of silently dropping records.
    try:
        return pd.read_csv(
            path,
            encoding="utf-8-sig",
            dtype=str,
            keep_default_na=False,
            on_bad_lines="error",
        )
    except UnicodeDecodeError:
        return pd.read_csv(
            path,
            encoding="cp1252",
            dtype=str,
            keep_default_na=False,
            on_bad_lines="error",
        )


def read_table(file_path: str) -> pd.DataFrame:
    """Read supported tabular formats without silently losing malformed rows."""
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
        if ext == ".csv":
            return _read_csv_strict(str(path))
        if ext == ".tsv":
            return pd.read_csv(str(path), sep="\t", encoding="utf-8-sig", dtype=str, keep_default_na=False, on_bad_lines="error")
        if ext == ".txt":
            return pd.read_csv(str(path), sep=None, engine="python", encoding="utf-8-sig", dtype=str, keep_default_na=False, on_bad_lines="error")
        if ext in {".xls", ".xlsx", ".xlsm"}:
            return pd.read_excel(str(path), dtype=str).fillna("")
        if ext == ".json":
            data = pd.read_json(str(path))
            return data.fillna("")
        if ext == ".xml":
            return pd.read_xml(str(path)).fillna("")
        raise ValueError("Unsupported file format. Use CSV, TSV/TXT, Excel, JSON, or XML.")
    except PermissionError as exc:
        logger.error("File locked or inaccessible: %s", file_path)
        raise PermissionError("The file is currently open or inaccessible. Close it and try again.") from exc
    except (pd.errors.EmptyDataError, pd.errors.ParserError, ValueError) as exc:
        logger.error("Malformed input %s: %s", file_path, exc)
        raise ValueError(f"The file could not be read safely: {exc}") from exc


def json_value(val):
    try:
        if pd.isna(val):
            return ""
        if isinstance(val, (int, float, str, bool)):
            return val
        return str(val)
    except (ValueError, TypeError):
        return str(val)


def map_columns(df: pd.DataFrame, mapping: dict) -> pd.DataFrame:
    if df is None or df.empty:
        return df
    try:
        return df.rename(columns=mapping)
    except (TypeError, ValueError) as err:
        logger.error("Error mapping columns: %s", err)
        raise ValueError(f"Invalid column mapping: {err}") from err


def clean_value(val) -> str:
    """Trim a value without changing case or identifier leading zeroes."""
    if val is None:
        return ""
    try:
        if pd.isna(val):
            return ""
    except (TypeError, ValueError):
        pass
    return str(val).strip()


def norm_value(val) -> str:
    return clean_value(val).casefold()


def norm_name(val) -> str:
    return norm_value(val)


def date_ok(val) -> bool:
    text = clean_value(val)
    if not text:
        return False
    try:
        parsed = pd.to_datetime(text, errors="raise")
        return not pd.isna(parsed)
    except (ValueError, TypeError):
        return False


def binary_ok(val) -> bool:
    norm = norm_value(val)
    return norm in {"1", "0", "true", "false", "yes", "no", "y", "n"}


def parse_delimited_text(text: str) -> list[list[str]]:
    """Parse clipboard text with the stdlib CSV parser, including quoted commas."""
    text = str(text or "").replace("\r\n", "\n").replace("\r", "\n")
    if not text.strip():
        return []
    sample = text[:4096]
    delimiter = "\t" if "\t" in sample else ","
    return [row for row in csv.reader(text.splitlines(), delimiter=delimiter)]
