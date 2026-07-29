"""Store import helpers for StoreLens

Robust import, detection and conversion helpers used by the Store Builder
feature set. Designed to be side-effect free and testable.

Public functions:
- read_any_file(path)
- detect_structure(df)
- map_columns(cols)
- convert_to_store_schema(df, mapping)
- preview_import(path, max_preview_rows=200)
- load_dataframe(path, mapping=None)
- export_builder(df, dst_path)

This module aims to be defensive about invalid paths and large files used only
for preview operations.
"""

from pathlib import Path
import json
import io
import pandas as pd
from typing import Dict, Any, List, Optional

from .common import (
    read_table,
    STORE_FIELDS,
    norm_value,
    map_columns as common_map_columns,
)

SUPPORTED_EXTENSIONS = {".csv", ".tsv", ".txt", ".xlsx", ".xls", ".xml", ".json"}

# soft limit for full-data operations during preview to avoid OOM; callers can
# still call load_dataframe() to force a full read
PREVIEW_ROW_LIMIT = 2000


def read_any_file(path: str) -> pd.DataFrame:
    """Read a file path into a pandas DataFrame using existing readers.

    Raises FileNotFoundError for missing paths and ValueError for unsupported
    extensions so callers can present clear messages to users.
    """
    p = str(path or "")
    if not p:
        raise ValueError("No path supplied")
    pth = Path(p)
    if not pth.exists() or not pth.is_file():
        raise FileNotFoundError(f"File not found: {p}")
    ext = pth.suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise ValueError(f"Unsupported extension: {ext}")
    # Delegate to common reader that already handles the supported types
    return read_table(p)


def _read_preview(path: str, nrows: int = 200) -> pd.DataFrame:
    """Read only the first nrows of a file where possible to keep previews
    lightweight. Falls back to read_any_file for types where partial reads are
    not easily supported.
    """
    p = Path(path)
    ext = p.suffix.lower()
    if ext in {".csv", ".txt", ".tsv"}:
        # For delimited files use pandas with nrows. Let pandas infer delimiter
        sep = "\t" if ext == ".tsv" else None
        try:
            return pd.read_csv(p, dtype=object, nrows=nrows, sep=sep, encoding="utf-8-sig", keep_default_na=False)
        except Exception:
            # Fallback to the robust common reader for ragged files
            df = read_table(p)
            return df.head(nrows)
    if ext in {".xlsx", ".xls", ".xlsm"}:
        try:
            return pd.read_excel(p, sheet_name=0, dtype=object, nrows=nrows)
        except Exception:
            df = read_table(p)
            return df.head(nrows)
    if ext == ".json":
        # Try a conservative JSON preview: read first chunk of text and parse
        try:
            text = p.read_text(encoding="utf-8-sig")
            obj = json.loads(text)
            # If it's list-like, normalise and head
            if isinstance(obj, list):
                df = pd.json_normalize(obj)
                return df.head(nrows)
            if isinstance(obj, dict):
                # try to find a list inside dict
                lists = [v for v in obj.values() if isinstance(v, list)]
                if lists:
                    df = pd.json_normalize(lists[0])
                    return df.head(nrows)
            # Fallback to full read_table
        except Exception:
            pass
        df = read_table(p)
        return df.head(nrows)
    # xml and other types: defer to read_table which may read whole file
    df = read_table(p)
    return df.head(nrows)


def get_headers(path: str) -> List[str]:
    """Return the column headers for a file without necessarily loading all
    rows. This is used to compute mappings based only on headers.
    """
    p = Path(path)
    ext = p.suffix.lower()
    if ext in {".csv", ".txt", ".tsv"}:
        sep = "\t" if ext == ".tsv" else None
        try:
            df = pd.read_csv(p, nrows=0, sep=sep, encoding="utf-8-sig")
            return [str(c) for c in df.columns]
        except Exception:
            # Last-resort: lightweight manual sniff of the first line
            text = p.read_text(encoding="utf-8-sig", errors="replace")
            first = text.splitlines()[0] if text.splitlines() else ""
            if "\t" in first:
                return [s.strip() for s in first.split("\t")]
            if "," in first:
                return [s.strip() for s in first.split(",")]
            return [s.strip() for s in first.split() if s.strip()]
    if ext in {".xlsx", ".xls", ".xlsm"}:
        try:
            df = pd.read_excel(p, sheet_name=0, nrows=0)
            return [str(c) for c in df.columns]
        except Exception:
            df = read_table(p)
            return [str(c) for c in df.columns]
    if ext == ".json":
        try:
            text = p.read_text(encoding="utf-8-sig")
            obj = json.loads(text)
            if isinstance(obj, list) and obj:
                # union of keys in the first few objects
                keys = set()
                for item in obj[:50]:
                    if isinstance(item, dict):
                        keys.update(item.keys())
                return [str(k) for k in keys]
            if isinstance(obj, dict):
                lists = [v for v in obj.values() if isinstance(v, list) and v]
                if lists:
                    keys = set()
                    for item in lists[0][:50]:
                        if isinstance(item, dict):
                            keys.update(item.keys())
                    return [str(k) for k in keys]
        except Exception:
            pass
        df = read_table(p)
        return [str(c) for c in df.columns]
    # XML and other: fall back to full read
    df = read_table(p)
    return [str(c) for c in df.columns]


def detect_structure(df: Optional[pd.DataFrame]) -> Dict[str, Any]:
    """Inspect a DataFrame and return a best-effort structure description.

    Returns:
    - columns: list of column names
    - mapped: result from map_columns (per STORE_FIELDS)
    - unmapped: list of input columns not assigned to STORE_FIELDS
    - sample: first few rows (up to 20) as lists for preview
    - row_count: total rows
    - mapping_conflicts: list of conflicts where multiple targets map to same source
    """
    if df is None:
        return {"columns": [], "mapped": {}, "unmapped": [], "sample": [], "row_count": 0, "mapping_conflicts": []}
    cols = [str(c) for c in df.columns]
    mapped = common_map_columns(cols)
    # Determine which source columns are used and whether they map to multiple targets
    inv: Dict[str, List[str]] = {}
    for target, info in mapped.items():
        src = info.get("column")
        if src:
            inv.setdefault(src, []).append(target)
    mapping_conflicts = [{"source": src, "targets": targets} for src, targets in inv.items() if len(targets) > 1]
    used = {src for src in inv.keys()}
    unmapped = [c for c in cols if c not in used]
    sample = [] if df.empty else df.head(20).fillna("").astype(object).values.tolist()
    return {"columns": cols, "mapped": mapped, "unmapped": unmapped, "sample": sample, "row_count": int(len(df)), "mapping_conflicts": mapping_conflicts}


def _apply_mapping_to_df(df: pd.DataFrame, mapping: Dict[str, str]) -> pd.DataFrame:
    """Return a new DataFrame with columns selected/renamed according to mapping.

    The returned DataFrame will contain all STORE_FIELDS in canonical order and
    use dtype object for every column to avoid surprising coercions.
    """
    # Ensure df is a DataFrame
    if df is None:
        df = pd.DataFrame()
    out = pd.DataFrame(dtype=object)
    length = len(df)
    for target in STORE_FIELDS:
        src = mapping.get(target, "")
        if src and src in df.columns:
            out[target] = df[src].astype(object)
        else:
            out[target] = pd.Series([""] * length, dtype=object)
    return out


def map_columns(cols: List[str]) -> Dict[str, Dict[str, Any]]:
    """Wrapper around the canonical mapping algorithm in core.common."""
    return common_map_columns(cols)


def convert_to_store_schema(df: Optional[pd.DataFrame], mapping: Optional[Dict[str, Any]] = None) -> pd.DataFrame:
    """Convert an arbitrary input dataframe into the canonical StoreLens schema.

    mapping may be either the rich structure returned by `map_columns` or a
    simple dict of {target: source}.
    """
    if df is None:
        # empty frame with correct columns and object dtype
        return pd.DataFrame({c: pd.Series(dtype=object) for c in STORE_FIELDS})

    # Normalize mapping into simple {target: source}
    simple: Dict[str, str] = {}
    if mapping:
        for k, v in mapping.items():
            if isinstance(v, dict):
                simple[k] = v.get("column", "") or ""
            else:
                simple[k] = v or ""

    return _apply_mapping_to_df(df, simple)


def preview_import(path: str, max_preview_rows: int = 200) -> Dict[str, Any]:
    """Return a lightweight preview of an import suitable for UI presentation.

    The preview contains row_count (estimated cheaply where possible), preview_rows,
    mapped_columns, unmapped_columns, suggested_mapping and mapping_conflicts.
    """
    # Get a light preview DataFrame and headers where possible
    preview_df = _read_preview(path, nrows=max_preview_rows)
    headers = get_headers(path)
    suggested = common_map_columns(headers)
    # Prefer to estimate row_count cheaply for delimited files
    p = Path(path)
    ext = p.suffix.lower()
    row_count = None
    if ext in {".csv", ".txt", ".tsv"}:
        try:
            # count lines and subtract header if present
            with p.open("r", encoding="utf-8-sig", errors="replace") as fh:
                lines = 0
                for _ in fh:
                    lines += 1
            row_count = max(0, lines - 1)
        except Exception:
            row_count = int(len(read_table(p)))
    else:
        try:
            row_count = int(len(read_table(p)))
        except Exception:
            row_count = int(len(preview_df))

    mapped_columns = [k for k, v in suggested.items() if v.get("column")]
    unmapped_columns = [h for h in headers if h not in {v.get("column") for v in suggested.values() if v.get("column")}]
    preview_rows = [] if preview_df is None or preview_df.empty else [[norm_value(x) for x in row] for row in preview_df.itertuples(index=False, name=None)]
    # Add mapping_conflicts
    inv: Dict[str, List[str]] = {}
    for target, info in suggested.items():
        src = info.get("column")
        if src:
            inv.setdefault(src, []).append(target)
    mapping_conflicts = [{"source": src, "targets": t} for src, t in inv.items() if len(t) > 1]

    return {
        "row_count": int(row_count or 0),
        "preview_rows": preview_rows,
        "mapped_columns": mapped_columns,
        "unmapped_columns": unmapped_columns,
        "suggested_mapping": suggested,
        "mapping_conflicts": mapping_conflicts,
    }


def load_dataframe(path: str, mapping: Optional[Dict[str, Any]] = None) -> pd.DataFrame:
    """Load a file and optionally apply a mapping to return the canonical schema.

    If mapping is omitted the function will compute the mapping from file
    headers only and then load the full file contents before applying the mapping.
    """
    # Get headers-only mapping to avoid reading full file just to infer columns
    if mapping is None:
        headers = get_headers(path)
        mapping = common_map_columns(headers)
    # Now read the full data and convert
    df = read_any_file(path)
    # Convert mapping to simple form if needed
    simple = {k: (v.get("column") if isinstance(v, dict) else v) for k, v in mapping.items()} if mapping else {}
    return convert_to_store_schema(df, simple)


def export_builder(df: Optional[pd.DataFrame], dst_path: str) -> str:
    """Export a DataFrame in canonical output form.

    - columns sorted to STORE_FIELDS order
    - UTF-8 with BOM to improve Excel compatibility on Windows
    - returns the path of the written file
    """
    if df is None:
        raise ValueError("Nothing to export")
    if not str(dst_path or "").strip():
        raise ValueError("Destination path required")
    dst = Path(dst_path).expanduser()
    if dst.exists() and dst.is_dir():
        raise ValueError("Destination must be a file path, not an existing directory")
    if dst.suffix.lower() != ".csv":
        dst = dst.with_suffix(".csv")
    # Ensure parent directory exists
    if dst.parent and not dst.parent.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
    out = df.copy()
    # Ensure canonical column order and presence
    for c in STORE_FIELDS:
        if c not in out.columns:
            out[c] = ""
    out = out[STORE_FIELDS]
    # Replace NaN with empty strings to keep CSV tidy and ensure object dtype
    out = out.fillna("")
    out = out.astype(object)
    # Write with BOM for UTF-8-sig
    out.to_csv(dst, index=False, encoding="utf-8-sig")
    return str(dst)
