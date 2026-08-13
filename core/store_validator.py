"""Identity-aware StoreLens comparison and validation."""

from __future__ import annotations

from collections import defaultdict
import os

import pandas as pd

from .common import MATCH_FIELDS, STORE_FIELDS, canonicalize_columns, clean_value, norm_value


def _load_table(path: str) -> pd.DataFrame:
    if not path:
        raise ValueError("File path cannot be empty.")
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")
    ext = os.path.splitext(path)[1].lower()
    if ext == ".csv":
        frame = pd.read_csv(path, encoding="utf-8-sig", dtype=str, keep_default_na=False, on_bad_lines="error")
    elif ext in (".tsv", ".txt"):
        frame = pd.read_csv(path, sep="\t", encoding="utf-8-sig", dtype=str, keep_default_na=False, on_bad_lines="error")
    elif ext in (".xls", ".xlsx", ".xlsm"):
        frame = pd.read_excel(path, dtype=str).fillna("")
    elif ext == ".json":
        frame = pd.read_json(path).fillna("")
    elif ext == ".xml":
        frame = pd.read_xml(path).fillna("")
    else:
        raise ValueError(f"Unsupported file format: {ext}")
    return canonicalize_columns(frame.fillna(""))


def _get(row, mapping, field):
    column = mapping.get(field, {}).get("column", "")
    if not column or column not in row.index:
        return ""
    return norm_value(row[column])


def _key(row, mapping, fields):
    return tuple(_get(row, mapping, field) for field in fields)


def _column_map(columns):
    return {field: {"column": field if field in columns else ""} for field in STORE_FIELDS}


def _available_match_fields(master, uploaded):
    return [field for field in MATCH_FIELDS if field in master.columns and field in uploaded.columns]


def suggest_keys(master, uploaded):
    available = _available_match_fields(master, uploaded)
    if "SID" not in available:
        raise ValueError("SID could not be detected in one or both files.")
    candidates = [["SID"]]
    if "Nielsen Store Code" in available:
        candidates.append(["SID", "Nielsen Store Code"])

    def unique(df, fields):
        mapping = _column_map(df.columns)
        keys = [_key(row, mapping, fields) for _, row in df.iterrows()]
        keys = [key for key in keys if any(key)]
        return len(keys) == len(set(keys))

    for fields in candidates:
        if unique(master, fields) and unique(uploaded, fields):
            return fields
    # A non-unique identity is still useful for diagnosis, but comparison will
    # explicitly report ambiguity instead of selecting the first record.
    return candidates[-1]


def _comparison_fields(master, uploaded):
    fields = [field for field in STORE_FIELDS if field in master.columns or field in uploaded.columns]
    # Keep common legacy comparison fields visible where present.
    for field in ("Email", "Status"):
        if field in master.columns or field in uploaded.columns:
            fields.append(field)
    return list(dict.fromkeys(fields))


def compare(master, uploaded, key_fields=None):
    master_map = _column_map(master.columns)
    upload_map = _column_map(uploaded.columns)
    key_fields = key_fields or suggest_keys(master, uploaded)
    if not key_fields or "SID" not in key_fields:
        raise ValueError("A valid identity key containing SID is required.")

    master_groups = defaultdict(list)
    for index, row in master.iterrows():
        key = _key(row, master_map, key_fields)
        if not any(key):
            continue
        master_groups[key].append((int(index) + 2, row))

    records = []
    fields = _comparison_fields(master, uploaded)

    for index, upload_row in uploaded.iterrows():
        row_number = int(index) + 2
        key_tuple = _key(upload_row, upload_map, key_fields)
        key_values = [_get(upload_row, upload_map, field) for field in key_fields]
        key_string = " | ".join(value for value in key_values if value) or "No Key"
        masters = master_groups.get(key_tuple, [])
        master_dict = {}
        upload_dict = {}
        comparisons = []
        problems = []

        if not any(key_tuple):
            status = "ERROR"
            match_type = "INVALID_KEY"
            message = "Store identity key is blank."
            for field in fields:
                upload_value = _get(upload_row, upload_map, field)
                master_dict[field] = ""
                upload_dict[field] = upload_value
                comparisons.append({"field": field, "master": "", "uploaded": upload_value, "result": "INVALID KEY", "severity": "ERROR"})
        elif len(masters) > 1:
            status = "REVIEW"
            match_type = "AMBIGUOUS"
            master_lines = ", ".join(str(item[0]) for item in masters[:10])
            message = f"Ambiguous identity: {len(masters)} master records match key ({master_lines}). No master record was selected automatically."
            for field in fields:
                upload_value = _get(upload_row, upload_map, field)
                master_dict[field] = ""
                upload_dict[field] = upload_value
                comparisons.append({"field": field, "master": "", "uploaded": upload_value, "result": "AMBIGUOUS MASTER", "severity": "REVIEW"})
        elif len(masters) == 1:
            master_row = masters[0][1]
            for field in fields:
                master_value = _get(master_row, master_map, field)
                upload_value = _get(upload_row, upload_map, field)
                master_dict[field] = master_value
                upload_dict[field] = upload_value
                same = master_value == upload_value
                comparisons.append({
                    "field": field,
                    "master": master_value,
                    "uploaded": upload_value,
                    "result": "MATCH" if same else "DIFFERENT",
                    "severity": "OK" if same else "REVIEW",
                })
                if not same:
                    problems.append(f"{field}: master='{master_value}' uploaded='{upload_value}'")
            status = "CORRECT" if not problems else "REVIEW"
            match_type = "EXACT"
            message = "Exact identity match with Master." if status == "CORRECT" else "; ".join(problems)
        else:
            status = "ERROR"
            match_type = "NO_MATCH"
            message = "Store key not found in Master file."
            for field in fields:
                upload_value = _get(upload_row, upload_map, field)
                master_dict[field] = ""
                upload_dict[field] = upload_value
                comparisons.append({"field": field, "master": "", "uploaded": upload_value, "result": "MISSING MASTER", "severity": "ERROR"})

        records.append({
            "row": row_number,
            "key": key_string,
            "status": status,
            "matchType": match_type,
            "message": message,
            "master": master_dict,
            "upload": upload_dict,
            "diffs": sum(1 for item in comparisons if item["severity"] != "OK"),
            "comparisons": comparisons,
        })

    return records, key_fields


class StoreValidator:
    def __init__(self):
        self.master = None
        self.upload = None

    def load_master(self, path):
        self.master = _load_table(path)

    def load_upload(self, path):
        self.upload = _load_table(path)

    def detect_keys(self):
        if self.master is None or self.upload is None:
            return ["SID", "Nielsen Store Code"]
        return suggest_keys(self.master, self.upload)

    def validate(self, keys):
        if self.master is None:
            raise ValueError("Master dataset has not been loaded.")
        if self.upload is None:
            raise ValueError("Uploaded dataset has not been loaded.")
        records, key_fields = compare(self.master, self.upload, keys or None)
        return {"total": len(records), "rows": records, "keys": key_fields}
