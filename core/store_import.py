"""Store import helpers for StoreLens

This module implements robust import, detection and conversion helpers used by
the Store Builder feature set. It intentionally avoids side effects so it can be
imported and tested without changing application state.

Functions:
- read_any_file(path)
- detect_structure(df)
- map_columns(cols)
- convert_to_store_schema(df, mapping)
- preview_import(path, max_preview_rows=200)
- load_dataframe(path, mapping=None)
- export_builder(df, dst_path)

The implementation re-uses helpers from core.common where appropriate and
keeps pandas dtype=object to avoid surprising conversions.
"""

from pathlib import Path
import json
import pandas as pd
from typing import Dict, Any, List, Tuple

from .common import (
    read_table,
    STORE_FIELDS,
    ALIASES,
    norm_name,
    norm_value,
    map_columns as common_map_columns,
)

SUPPORTED_EXTENSIONS = {".csv", ".tsv", ".txt", ".xlsx", ".xls", ".xml", ".json"}


def read_any_file(path: str) -> pd.DataFrame:
    """Read a file path into a pandas DataFrame using existing readers.

    This wraps core.common.read_table so calling code can rely on a single
    import entrypoint for the Store Builder features.
    """
    p = str(path or "")
    if not p:
        return pd.DataFrame()
    ext = Path(p).suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise ValueError(f"Unsupported extension: {ext}")
    return read_table(p)


def detect_structure(df: pd.DataFrame) -> Dict[str, Any]:
    """Inspect a DataFrame and return a best-effort structure description.

    Returns a dict with keys:
    - columns: list of column names
    - mapped: result from map_columns (per STORE_FIELDS)
    - unmapped: list of input columns not assigned to STORE_FIELDS
    - sample: first few rows (up to 20) as lists for preview
    - row_count: total rows
    """
    if df is None:
        return {"columns": [], "mapped": {}, "unmapped": [], "sample": [], "row_count": 0}
    cols = [str(c) for c in df.columns]
    mapped = common_map_columns(cols)
    used = {v.get("column") for v in mapped.values() if v.get("column")}
    unmapped = [c for c in cols if c not in used]
    sample = df.head(20).fillna("").astype(object).values.tolist()
    return {"columns": cols, "mapped": mapped, "unmapped": unmapped, "sample": sample, "row_count": int(len(df))}


def _apply_mapping_to_df(df: pd.DataFrame, mapping: Dict[str, str]) -> pd.DataFrame:
    """Return a new DataFrame with columns renamed according to mapping.

    mapping: dict where keys are target STORE_FIELD names and values are source
    column names (may be empty strings for unmapped targets). The returned
    DataFrame will contain all STORE_FIELDS in order; missing columns are added
    as empty strings.
    """
    out = pd.DataFrame(dtype=object)
    for target in STORE_FIELDS:
        src = mapping.get(target, "")
        if src and src in df.columns:
            out[target] = df[src].astype(object)
        else:
            out[target] = ""
    return out


def map_columns(cols: List[str]) -> Dict[str, Dict[str, Any]]:
    """Wrapper around the canonical mapping algorithm.

    Returns the same structure as core.common.map_columns so callers can use it
    for UI mapping displays.
    """
    return common_map_columns(cols)


def convert_to_store_schema(df: pd.DataFrame, mapping: Dict[str, str]) -> pd.DataFrame:
    """Convert an arbitrary input dataframe into the canonical StoreLens schema.

    - mapping may be either the structure returned by `map_columns` (dict of
      {target: {"column": source, "confidence": n}}) or a simpler dict of
      {target: source}.
    - The returned DataFrame will have columns in the canonical STORE_FIELDS
      order and keep values as objects (no coercion).
    """
    if df is None:
        return pd.DataFrame(columns=STORE_FIELDS)

    # Normalize mapping input into {target: source}
    simple = {}
    if mapping:
        # mapping could be the rich form
        for k, v in mapping.items():
            if isinstance(v, dict):
                simple[k] = v.get("column", "")
            else:
                simple[k] = v or ""

    return _apply_mapping_to_df(df, simple)


def preview_import(path: str, max_preview_rows: int = 200) -> Dict[str, Any]:
    """Return a JSON-serialisable preview of an import.

    The preview contains:
    - row_count
    - preview_rows (up to max_preview_rows)
    - mapped_columns (list of targets which were confidently mapped)
    - unmapped_columns (list)
    - suggested_mapping (the raw mapping structure)
    """
    df = read_any_file(path)
    structure = detect_structure(df)

    # derive a simple list of mapped/unmapped
    mapped = [k for k, v in structure["mapped"].items() if v.get("column")]
    unmapped = structure["unmapped"]
    preview_rows = [ [norm_value(x) for x in row] for row in df.head(max_preview_rows).itertuples(index=False, name=None) ]
    return {
        "row_count": int(len(df)),
        "preview_rows": preview_rows,
        "mapped_columns": mapped,
        "unmapped_columns": unmapped,
        "suggested_mapping": structure["mapped"],
    }


def load_dataframe(path: str, mapping: Dict[str, str] | None = None) -> pd.DataFrame:
    """Load a file and optionally apply a mapping to return the canonical schema.

    If mapping is omitted the function will use the automatic mapping.
    """
    df = read_any_file(path)
    if mapping is None:
        mapping = common_map_columns([str(c) for c in df.columns])
    # Convert mapping to simple form if needed
    simple = {k: (v.get("column") if isinstance(v, dict) else v) for k, v in mapping.items()} if mapping else {}
    return convert_to_store_schema(df, simple)


def export_builder(df: pd.DataFrame, dst_path: str) -> str:
    """Export a DataFrame in canonical output form:

    - columns sorted to STORE_FIELDS order
    - UTF-8 with BOM to improve Excel compatibility on Windows
    - returns the path of the written file
    """
    if df is None:
        raise ValueError("Nothing to export")
    dst = Path(dst_path or "").expanduser()
    if not dst.suffix.lower() == ".csv":
        dst = dst.with_suffix(".csv")
    out = df.copy()
    # Ensure canonical column order and presence
    for c in STORE_FIELDS:
        if c not in out.columns:
            out[c] = ""
    out = out[STORE_FIELDS]
    # Replace NaN with empty strings to keep CSV tidy
    out = out.fillna("")
    # Write with BOM for UTF-8-sig
    out.to_csv(dst, index=False, encoding="utf-8-sig")
    return str(dst)
