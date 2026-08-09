import os
from collections import defaultdict

import pandas as pd

from .common import norm_value


def _load_table(path):
    if not path:
        raise ValueError("File path cannot be empty.")

    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")

    ext = os.path.splitext(path)[1].lower()

    if ext == ".csv":
        return pd.read_csv(
            path,
            encoding="utf-8-sig",
            on_bad_lines="skip",
            dtype=str,
        ).fillna("")

    if ext in (".xls", ".xlsx"):
        return pd.read_excel(path, dtype=str).fillna("")

    raise ValueError(f"Unsupported file format: {ext}")


def _normal_name(value):
    return (
        str(value)
        .strip()
        .lower()
        .replace("_", " ")
        .replace("-", " ")
    )


def _find_column(columns, candidates):
    normalized = {
        _normal_name(column): column
        for column in columns
    }

    for candidate in candidates:
        key = _normal_name(candidate)
        if key in normalized:
            return normalized[key]

    for column in columns:
        n = _normal_name(column)
        for candidate in candidates:
            c = _normal_name(candidate)
            if c and (c in n or n in c):
                return column

    return ""


def _column_map(columns):
    aliases = {
        "SID": [
            "SID",
            "Store ID",
            "StoreID",
            "Store Id",
            "Store Code",
            "store_code",
            "ID",
        ],
        "Nielsen Store Code": [
            "Nielsen Store Code",
            "Nielsen Code",
            "Nielsen Store",
            "Nielsen",
        ],
        "Store Name": [
            "Store Name",
            "Store",
            "Name",
            "store_name",
        ],
        "Address": [
            "Address",
            "address",
        ],
        "City": [
            "City",
            "city",
        ],
        "State": [
            "State",
            "state",
        ],
        "Pincode": [
            "Pincode",
            "Pin Code",
            "Postal Code",
            "ZIP",
            "Zip Code",
            "pincode",
        ],
        "Phone": [
            "Phone",
            "Mobile",
            "Contact",
            "phone",
        ],
        "Email": [
            "Email",
            "Mail",
            "email",
        ],
        "Status": [
            "Status",
            "status",
        ],
    }

    result = {}

    for logical_name, candidates in aliases.items():
        result[logical_name] = {
            "column": _find_column(columns, candidates)
        }

    return result


def _get(row, mapping, field):
    column = mapping.get(field, {}).get("column", "")

    if not column or column not in row.index:
        return ""

    return norm_value(row[column])


def _key(row, mapping, fields):
    return tuple(
        _get(row, mapping, field)
        for field in fields
    )


def suggest_keys(master, uploaded):
    master_map = _column_map(master.columns)
    upload_map = _column_map(uploaded.columns)

    available = [
        field
        for field in ("SID", "Nielsen Store Code")
        if master_map.get(field, {}).get("column")
        and upload_map.get(field, {}).get("column")
    ]

    if "SID" not in available:
        raise ValueError(
            "SID could not be detected in one or both files."
        )

    candidates = [["SID"]]

    if "Nielsen Store Code" in available:
        candidates.append(
            ["SID", "Nielsen Store Code"]
        )

    def unique(df, mapping, fields):
        keys = [
            _key(row, mapping, fields)
            for _, row in df.iterrows()
        ]

        keys = [
            key for key in keys
            if any(key)
        ]

        return len(keys) == len(set(keys))

    for fields in candidates:
        if (
            unique(master, master_map, fields)
            and unique(uploaded, upload_map, fields)
        ):
            return fields

    return candidates[-1]


def compare(master, uploaded, key_fields=None):
    master_map = _column_map(master.columns)
    upload_map = _column_map(uploaded.columns)

    key_fields = key_fields or suggest_keys(
        master,
        uploaded,
    )

    master_groups = defaultdict(list)

    for index, row in master.iterrows():
        key = _key(
            row,
            master_map,
            key_fields,
        )

        master_groups[key].append(
            (int(index) + 2, row)
        )

    records = []

    for index, upload_row in uploaded.iterrows():
        row_number = int(index) + 2

        key_tuple = _key(
            upload_row,
            upload_map,
            key_fields,
        )

        key_values = [
            _get(upload_row, upload_map, field)
            for field in key_fields
        ]

        key_string = " | ".join(
            value for value in key_values
            if value
        ) or "No Key"

        masters = master_groups.get(
            key_tuple,
            []
        )

        master_dict = {}
        upload_dict = {}
        comparisons = []
        problems = []

        if masters:
            master_row = masters[0][1]

            fields = [
                "SID",
                "Nielsen Store Code",
                "Store Name",
                "Address",
                "City",
                "State",
                "Pincode",
                "Phone",
                "Email",
                "Status",
            ]

            for field in fields:
                master_value = _get(
                    master_row,
                    master_map,
                    field,
                )

                upload_value = _get(
                    upload_row,
                    upload_map,
                    field,
                )

                master_dict[field] = master_value
                upload_dict[field] = upload_value

                same = (
                    master_value.casefold()
                    == upload_value.casefold()
                )

                if same:
                    result = "MATCH"
                    severity = "OK"
                else:
                    result = "DIFFERENT"
                    severity = "REVIEW"
                    problems.append(
                        f"{field}: master='{master_value}' "
                        f"uploaded='{upload_value}'"
                    )

                comparisons.append({
                    "field": field,
                    "master": master_value,
                    "uploaded": upload_value,
                    "result": result,
                    "severity": severity,
                })

            status = (
                "CORRECT"
                if not problems
                else "REVIEW"
            )

            message = (
                "Exact match with Master."
                if status == "CORRECT"
                else "; ".join(problems)
            )

        else:
            fields = [
                "SID",
                "Nielsen Store Code",
                "Store Name",
                "Address",
                "City",
                "State",
                "Pincode",
                "Phone",
                "Email",
                "Status",
            ]

            for field in fields:
                upload_value = _get(
                    upload_row,
                    upload_map,
                    field,
                )

                master_dict[field] = ""
                upload_dict[field] = upload_value

                comparisons.append({
                    "field": field,
                    "master": "",
                    "uploaded": upload_value,
                    "result": "MISSING MASTER",
                    "severity": "ERROR",
                })

            status = "ERROR"
            message = (
                "Store key not found in Master file."
            )

        diff_count = sum(
            1
            for item in comparisons
            if item["severity"] != "OK"
        )

        records.append({
            "row": row_number,
            "key": key_string,
            "status": status,
            "message": message,
            "master": master_dict,
            "upload": upload_dict,
            "diffs": diff_count,
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

        return suggest_keys(
            self.master,
            self.upload,
        )

    def validate(self, keys):
        if self.master is None:
            raise ValueError("Master dataset has not been loaded.")

        if self.upload is None:
            raise ValueError("Uploaded dataset has not been loaded.")

        records, key_fields = compare(
            self.master,
            self.upload,
            keys or None,
        )

        return {
            "total": len(records),
            "rows": records,
            "keys": key_fields,
        }
