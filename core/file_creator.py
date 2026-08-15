"""Store Builder data preparation, validation, and export."""

from __future__ import annotations

import csv
import os
import tempfile
from pathlib import Path

import pandas as pd

from .common import (
    STORE_FIELDS,
    REQUIRED_STORE_FIELDS,
    BINARY_STORE_FIELDS,
    binary_ok,
    canonical_field,
    clean_value,
    date_ok,
    normalize_binary_value,
    normalize_nielsen_code,
    norm_value,
    parse_delimited_text,
    suggested_numeric_width,
)

REQUIRED_FIELDS = REQUIRED_STORE_FIELDS


def empty_rows(n: int = 10) -> list[dict[str, str]]:
    return [{field: "" for field in STORE_FIELDS} for _ in range(max(1, int(n)))]


def parse_clipboard(text: str) -> list[list[str]]:
    return parse_delimited_text(text)


def normalize_nielsen(value, width: int) -> str:
    return normalize_nielsen_code(value, width)


def _detect_structure(df: pd.DataFrame) -> dict:
    columns = [str(column) for column in df.columns]
    horizontal = sum(1 for column in columns if canonical_field(column))
    vertical = []
    for column in df.columns:
        matches = []
        for ix, value in df[column].items():
            field = canonical_field(value)
            if field:
                matches.append((int(ix) + 2, field))
        if len(matches) >= 2:
            vertical.append((column, matches))
    if horizontal >= 2:
        return {"kind": "HORIZONTAL", "confidence": "HIGH", "message": "Standard row-based table detected."}
    if vertical:
        key_col, matches = max(vertical, key=lambda item: len(item[1]))
        fields = list(dict.fromkeys(field for _, field in matches))
        return {"kind": "VERTICAL", "confidence": "HIGH" if len(fields) >= 3 else "MEDIUM", "message": f"Vertical key/value layout detected in '{key_col}'. Review the structure before treating rows as store records.", "fields": fields, "keyColumn": str(key_col)}
    return {"kind": "UNKNOWN", "confidence": "LOW", "message": "The file does not look like a standard horizontal store table."}


def _suggested_width(codes) -> int:
    return suggested_numeric_width(codes)


def _row_has_data(row: dict) -> bool:
    return any(clean_value(row.get(field, "")) for field in STORE_FIELDS)


def _normalize_row(row: dict, nielsen_width: int = 0) -> dict[str, str]:
    values = {field: clean_value(row.get(field, "")) for field in STORE_FIELDS}
    for field in BINARY_STORE_FIELDS:
        values[field] = normalize_binary_value(values[field])
    values["Nielsen Store Code"] = normalize_nielsen_code(values["Nielsen Store Code"], nielsen_width)
    return values


def _validate_choice(findings, row_no, field, value):
    if value and not binary_ok(value):
        findings.append({
            "row": row_no,
            "field": field,
            "value": value,
            "message": "Allowed values: 1 or 0. Use Yes/No, True/False, or 1/0 on input.",
            "severity": "ERROR",
        })


def creator_validate(rows: list[dict]) -> list[dict]:
    """Validate Store Builder rows using the canonical 14-column schema."""
    findings = []
    seen_nielsen: dict[str, int] = {}
    seen_composite: dict[tuple[str, str], int] = {}
    nielsen_width = _suggested_width([row.get("Nielsen Store Code", "") for row in rows if isinstance(row, dict)])

    for index, row in enumerate(rows):
        row_no = index + 1
        if not isinstance(row, dict):
            findings.append({"row": row_no, "field": "ROW", "value": "", "message": "Invalid row structure", "severity": "ERROR"})
            continue
        if not _row_has_data(row):
            continue

        values = _normalize_row(row, nielsen_width)
        for field in REQUIRED_FIELDS:
            if not values[field]:
                findings.append({"row": row_no, "field": field, "value": "", "message": "Required value is empty", "severity": "ERROR"})

        sid_key = norm_value(values["SID"])
        nielsen_key = norm_value(values["Nielsen Store Code"])
        composite = (sid_key, nielsen_key)

        if nielsen_key:
            if nielsen_key in seen_nielsen:
                findings.append({"row": row_no, "field": "Nielsen Store Code", "value": values["Nielsen Store Code"], "message": f"Duplicate Nielsen Store Code; first seen on row {seen_nielsen[nielsen_key]}", "severity": "ERROR"})
            else:
                seen_nielsen[nielsen_key] = row_no

        if sid_key and nielsen_key:
            if composite in seen_composite:
                findings.append({"row": row_no, "field": "SID + Nielsen Store Code", "value": f"{values['SID']} + {values['Nielsen Store Code']}", "message": f"Duplicate composite identity; first seen on row {seen_composite[composite]}", "severity": "ERROR"})
            else:
                seen_composite[composite] = row_no

        zip_value = values["ZIP"]
        if zip_value and (not zip_value.isdigit() or not 3 <= len(zip_value) <= 12):
            findings.append({"row": row_no, "field": "ZIP", "value": zip_value, "message": "ZIP must contain 3–12 digits", "severity": "ERROR"})

        for field in BINARY_STORE_FIELDS:
            _validate_choice(findings, row_no, field, values[field])

        for field in ("Trip Received", "Last Trip"):
            if values[field] and not date_ok(values[field]):
                findings.append({"row": row_no, "field": field, "value": values[field], "message": "Invalid date", "severity": "ERROR"})

    return findings


def review_dataframe(df: pd.DataFrame) -> dict:
    """Profile a dataset without inventing missing schema columns as review failures."""
    structure = _detect_structure(df)
    if structure["kind"] != "HORIZONTAL":
        return {"rows": [{"row": 1, "severity": "REVIEW", "issues": [structure["message"]]}], "issueCount": 1, "findingCount": 1, "suggestedNielsenWidth": 0, "columns": [str(c) for c in df.columns], "structure": structure, "recordCount": 1 if structure["kind"] == "VERTICAL" else int(len(df))}
    canonical = df.rename(columns={c: canonical_field(c) or str(c) for c in df.columns})
    codes = [clean_value(value) for value in canonical.get("Nielsen Store Code", []) if clean_value(value)]
    suggested = _suggested_width(codes)
    rows = []
    present_required = [field for field in REQUIRED_FIELDS if field in canonical.columns]
    for ix, record in canonical.iterrows():
        item = {"row": int(ix) + 2, "severity": "OK", "issues": []}
        for field in present_required:
            if not clean_value(record.get(field, "")):
                item["issues"].append(f"{field}: required value is blank")
        if "Nielsen Store Code" in canonical.columns and suggested:
            code = clean_value(record.get("Nielsen Store Code", ""))
            if code.isdigit() and len(code) != suggested:
                item["issues"].append(f"Nielsen Store Code: {code} has width {len(code)}; dominant width is {suggested}")
        for field in BINARY_STORE_FIELDS:
            if field in canonical.columns:
                raw = clean_value(record.get(field, ""))
                if raw and not binary_ok(raw):
                    item["issues"].append(f"{field}: use 1 or 0")
        for field in ("Trip Received", "Last Trip"):
            if field in canonical.columns:
                value = clean_value(record.get(field, ""))
                if value and not date_ok(value):
                    item["issues"].append(f"{field}: invalid date '{value}'")
        if "ZIP" in canonical.columns:
            value = clean_value(record.get("ZIP", ""))
            if value and (not value.isdigit() or not 3 <= len(value) <= 12):
                item["issues"].append(f"ZIP: invalid value '{value}'")
        if item["issues"]:
            item["severity"] = "REVIEW"
        rows.append(item)
    return {"rows": rows, "issueCount": sum(bool(item["issues"]) for item in rows), "findingCount": sum(len(item["issues"]) for item in rows), "suggestedNielsenWidth": suggested, "columns": [str(c) for c in df.columns], "structure": structure, "recordCount": int(len(df))}


def export_creator(rows: list[dict], dst: str) -> str:
    """Atomically write a canonical CSV without overwriting the source on failure."""
    path = Path(dst)
    if path.suffix.lower() != ".csv":
        path = path.with_suffix(".csv")
    path.parent.mkdir(parents=True, exist_ok=True)
    nielsen_width = _suggested_width([row.get("Nielsen Store Code", "") for row in rows if isinstance(row, dict)])
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.stem}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", newline="", encoding="utf-8-sig") as file:
            writer = csv.DictWriter(file, fieldnames=STORE_FIELDS, extrasaction="ignore")
            writer.writeheader()
            for row in rows:
                if _row_has_data(row):
                    writer.writerow(_normalize_row(row, nielsen_width))
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp_name, path)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise
    return str(path)
