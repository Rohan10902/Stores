import sys
import os
import re
import csv
import json
import sqlite3
import traceback
from pathlib import Path
from datetime import datetime
from difflib import SequenceMatcher

import pandas as pd

from PySide6.QtCore import (
    QObject,
    Signal,
    Slot,
    Property,
    QUrl,
)
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


# ============================================================
# APPLICATION CONFIGURATION
# ============================================================

APP_NAME = "Store Data Assistant"
APP_VERSION = "6.1"


# ============================================================
# STANDARD STORE SCHEMA
# ============================================================

STANDARD_FIELDS = [
    "Store Name",
    "SID",
    "Banner",
    "Nielsen Store Code",
    "Trip Received",
    "Last Trip",
    "Address 1",
    "Address 2",
    "Address 3",
    "ZIP",
    "Active / Inactive",
    "Is Census",
    "Is Exceptions",
    "Updated By",
]


# ============================================================
# COLUMN ALIASES
# Used for automatic mapping between countries/files
# ============================================================

COLUMN_ALIASES = {
    "Store Name": [
        "store name",
        "storename",
        "store",
        "outlet name",
        "location name",
        "shop name",
        "store_name",
    ],

    "SID": [
        "sid",
        "store id",
        "storeid",
        "store identifier",
        "store_id",
        "site id",
        "siteid",
    ],

    "Banner": [
        "banner",
        "brand",
        "chain",
        "retailer",
        "store banner",
    ],

    "Nielsen Store Code": [
        "nielsen store code",
        "nielsen code",
        "nielsen store",
        "nielsen id",
        "nielsenstorecode",
    ],

    "Trip Received": [
        "trip received",
        "trip received date",
        "received date",
        "tripreceived",
    ],

    "Last Trip": [
        "last trip",
        "last trip date",
        "previous trip",
        "lasttrip",
    ],

    "Address 1": [
        "address 1",
        "address1",
        "address line 1",
        "addressline1",
        "street address",
        "street",
    ],

    "Address 2": [
        "address 2",
        "address2",
        "address line 2",
        "addressline2",
    ],

    "Address 3": [
        "address 3",
        "address3",
        "address line 3",
        "addressline3",
    ],

    "ZIP": [
        "zip",
        "zipcode",
        "zip code",
        "postal",
        "postal code",
        "postcode",
        "pin",
        "pin code",
    ],

    "Active / Inactive": [
        "active inactive",
        "active/inactive",
        "active",
        "status",
        "active flag",
        "is active",
    ],

    "Is Census": [
        "is census",
        "census",
        "census flag",
        "iscensus",
    ],

    "Is Exceptions": [
        "is exceptions",
        "is exception",
        "exceptions",
        "exception",
        "exception flag",
        "isexceptions",
    ],

    "Updated By": [
        "updated by",
        "updatedby",
        "last updated",
        "last updated date",
        "modified",
        "modified date",
        "updated date",
        "timestamp",
    ],
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def clean_text(value):
    if value is None:
        return ""

    try:
        if pd.isna(value):
            return ""
    except Exception:
        pass

    return str(value).strip()


def normalize_column_name(value):
    value = clean_text(value).lower()

    value = re.sub(r"[_\-\/]+", " ", value)
    value = re.sub(r"[^a-z0-9 ]+", "", value)
    value = re.sub(r"\s+", " ", value)

    return value.strip()


def normalize_compare_value(value):
    value = clean_text(value).lower()
    value = re.sub(r"\s+", " ", value)

    return value.strip()


def fuzzy_score(a, b):
    a = normalize_column_name(a)
    b = normalize_column_name(b)

    if not a or not b:
        return 0.0

    if a == b:
        return 1.0

    return SequenceMatcher(None, a, b).ratio()


def safe_json(value):
    return json.dumps(
        value,
        ensure_ascii=False,
        default=str,
    )


def is_empty(value):
    return clean_text(value) == ""


def is_binary_flag(value):
    value = clean_text(value)

    if value == "":
        return True

    return value in {"0", "1"}


def is_valid_date(value):
    value = clean_text(value)

    if not value:
        return True

    try:
        parsed = pd.to_datetime(
            value,
            errors="coerce",
            dayfirst=False,
        )

        return not pd.isna(parsed)

    except Exception:
        return False


def word_count(value):
    value = clean_text(value)

    if not value:
        return 0

    return len(value.split())


def resource_path(relative_path):
    """
    Works both in normal Python execution and PyInstaller.
    """

    if hasattr(sys, "_MEIPASS"):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.abspath(
            os.path.dirname(__file__)
        )

    return os.path.join(
        base_path,
        relative_path,
    )


# ============================================================
# FILE LOADER
# ============================================================

class FileLoader:

    EXCEL_EXTENSIONS = {
        ".xlsx",
        ".xls",
        ".xlsm",
    }

    CSV_EXTENSIONS = {
        ".csv",
        ".txt",
        ".tsv",
    }

    JSON_EXTENSIONS = {
        ".json",
    }

    XML_EXTENSIONS = {
        ".xml",
    }

    @staticmethod
    def detect_delimiter(path):

        delimiters = [
            ",",
            ";",
            "\t",
            "|",
        ]

        try:
            with open(
                path,
                "r",
                encoding="utf-8-sig",
                errors="replace",
            ) as file:

                sample = file.read(10000)

            try:
                dialect = csv.Sniffer().sniff(
                    sample,
                    delimiters="".join(delimiters),
                )

                return dialect.delimiter

            except Exception:
                pass

            counts = {
                delimiter: sample.count(delimiter)
                for delimiter in delimiters
            }

            return max(
                counts,
                key=counts.get,
            )

        except Exception:
            return ","

    @staticmethod
    def load_csv(path):

        delimiter = FileLoader.detect_delimiter(path)

        encodings = [
            "utf-8-sig",
            "utf-8",
            "cp1252",
            "latin1",
        ]

        last_error = None

        for encoding in encodings:

            try:
                df = pd.read_csv(
                    path,
                    sep=delimiter,
                    dtype=str,
                    encoding=encoding,
                    keep_default_na=False,
                    engine="python",
                    quotechar='"',
                    on_bad_lines="error",
                )

                return df, {
                    "delimiter": delimiter,
                    "encoding": encoding,
                    "repaired": False,
                }

            except Exception as exc:
                last_error = exc

        raise RuntimeError(
            f"Unable to read CSV/TXT file: {last_error}"
        )

    @staticmethod
    def load_excel(path):

        df = pd.read_excel(
            path,
            dtype=str,
            keep_default_na=False,
        )

        return df, {
            "delimiter": None,
            "encoding": None,
            "repaired": False,
        }

    @staticmethod
    def load_json(path):

        try:
            df = pd.read_json(path)

        except Exception:

            with open(
                path,
                "r",
                encoding="utf-8",
            ) as file:

                data = json.load(file)

            if isinstance(data, dict):
                data = [data]

            df = pd.json_normalize(data)

        df = df.fillna("").astype(str)

        return df, {
            "delimiter": None,
            "encoding": "utf-8",
            "repaired": False,
        }

    @staticmethod
    def load_xml(path):

        df = pd.read_xml(path)

        if df is None:
            raise RuntimeError(
                "No tabular records were found in the XML file."
            )

        df = df.fillna("").astype(str)

        return df, {
            "delimiter": None,
            "encoding": None,
            "repaired": False,
        }

    @staticmethod
    def load(path):

        if not path:
            raise ValueError(
                "No file was selected."
            )

        path = os.path.abspath(path)

        if not os.path.exists(path):
            raise FileNotFoundError(
                f"File does not exist:\n{path}"
            )

        extension = Path(path).suffix.lower()

        if extension in FileLoader.EXCEL_EXTENSIONS:
            df, meta = FileLoader.load_excel(path)

        elif extension in FileLoader.CSV_EXTENSIONS:
            df, meta = FileLoader.load_csv(path)

        elif extension in FileLoader.JSON_EXTENSIONS:
            df, meta = FileLoader.load_json(path)

        elif extension in FileLoader.XML_EXTENSIONS:
            df, meta = FileLoader.load_xml(path)

        else:
            raise ValueError(
                f"Unsupported file type: {extension}"
            )

        df.columns = [
            clean_text(column)
            for column in df.columns
        ]

        df = df.fillna("")

        meta["path"] = path
        meta["extension"] = extension

        return df, meta


# ============================================================
# COLUMN DETECTOR
# ============================================================

class ColumnDetector:

    @staticmethod
    def score_column(
        standard_field,
        actual_column,
    ):

        actual_normalized = normalize_column_name(
            actual_column
        )

        standard_normalized = normalize_column_name(
            standard_field
        )

        if actual_normalized == standard_normalized:
            return 1.0

        aliases = COLUMN_ALIASES.get(
            standard_field,
            [],
        )

        best = fuzzy_score(
            standard_field,
            actual_column,
        )

        for alias in aliases:

            alias_normalized = normalize_column_name(
                alias
            )

            if actual_normalized == alias_normalized:
                return 0.99

            score = fuzzy_score(
                alias,
                actual_column,
            )

            best = max(
                best,
                score,
            )

        return best

    @staticmethod
    def detect(columns):

        results = {}

        used_columns = set()

        for standard_field in STANDARD_FIELDS:

            best_column = None
            best_score = 0.0

            for column in columns:

                if column in used_columns:
                    continue

                score = ColumnDetector.score_column(
                    standard_field,
                    column,
                )

                if score > best_score:
                    best_score = score
                    best_column = column

            if best_score < 0.45:
                best_column = ""

            else:
                used_columns.add(best_column)

            results[standard_field] = {
                "column": best_column,
                "confidence": round(
                    best_score * 100,
                    1,
                ),
            }

        return results


# ============================================================
# DATA PROFILER
# ============================================================

class DataProfiler:

    @staticmethod
    def analyse(df):

        rows = len(df)
        columns = len(df.columns)

        total_cells = rows * columns

        empty_cells = 0

        duplicate_rows = int(
            df.astype(str).duplicated().sum()
        )

        column_stats = []

        for column in df.columns:

            series = (
                df[column]
                .fillna("")
                .astype(str)
                .map(str.strip)
            )

            blanks = int(
                (series == "").sum()
            )

            empty_cells += blanks

            unique_values = int(
                series[
                    series != ""
                ].nunique()
            )

            duplicate_values = int(
                series[
                    series != ""
                ].duplicated().sum()
            )

            column_stats.append({
                "column": column,
                "rows": rows,
                "blank": blanks,
                "nonBlank": rows - blanks,
                "unique": unique_values,
                "duplicateValues": duplicate_values,
            })

        completeness = 100.0

        if total_cells > 0:

            completeness = (
                (
                    total_cells
                    - empty_cells
                )
                / total_cells
            ) * 100

        return {
            "rows": rows,
            "columns": columns,
            "cells": total_cells,
            "emptyCells": empty_cells,
            "completeCells": (
                total_cells
                - empty_cells
            ),
            "completeness": round(
                completeness,
                2,
            ),
            "duplicateRows": duplicate_rows,
            "columnStats": column_stats,
        }


# ============================================================
# CSV REPAIR ENGINE
# ============================================================

class CSVRepairEngine:

    @staticmethod
    def inspect(path):

        delimiter = FileLoader.detect_delimiter(path)

        problems = []

        with open(
            path,
            "r",
            encoding="utf-8-sig",
            errors="replace",
            newline="",
        ) as file:

            lines = file.readlines()

        if not lines:

            return {
                "delimiter": delimiter,
                "expectedColumns": 0,
                "problems": [],
            }

        try:
            header = next(
                csv.reader(
                    [lines[0]],
                    delimiter=delimiter,
                )
            )

            expected = len(header)

        except Exception:

            expected = (
                lines[0].count(delimiter)
                + 1
            )

        for index, line in enumerate(
            lines[1:],
            start=2,
        ):

            try:

                parsed = next(
                    csv.reader(
                        [line],
                        delimiter=delimiter,
                    )
                )

                count = len(parsed)

                if count != expected:

                    problems.append({
                        "line": index,
                        "expectedColumns": expected,
                        "actualColumns": count,
                        "content": line.rstrip(
                            "\r\n"
                        ),
                    })

            except Exception as exc:

                problems.append({
                    "line": index,
                    "expectedColumns": expected,
                    "actualColumns": -1,
                    "content": line.rstrip(
                        "\r\n"
                    ),
                    "error": str(exc),
                })

        return {
            "delimiter": delimiter,
            "expectedColumns": expected,
            "problems": problems,
        }

    @staticmethod
    def repair(path, output_path):

        delimiter = FileLoader.detect_delimiter(path)

        with open(
            path,
            "r",
            encoding="utf-8-sig",
            errors="replace",
            newline="",
        ) as source:

            reader = csv.reader(
                source,
                delimiter=delimiter,
                quotechar='"',
            )

            rows = list(reader)

        if not rows:
            raise RuntimeError(
                "The file is empty."
            )

        expected = len(rows[0])

        repaired_rows = []

        repair_log = []

        repaired_rows.append(
            rows[0]
        )

        for row_number, row in enumerate(
            rows[1:],
            start=2,
        ):

            original_count = len(row)

            if original_count == expected:

                repaired_rows.append(row)
                continue

            if original_count < expected:

                repaired = row + (
                    [""] * (
                        expected
                        - original_count
                    )
                )

                repaired_rows.append(
                    repaired
                )

                repair_log.append({
                    "row": row_number,
                    "problem": "Missing columns",
                    "before": original_count,
                    "after": expected,
                })

                continue

            # More fields than expected.
            # Preserve information by combining overflow
            # into the final expected field.
            repaired = (
                row[: expected - 1]
                + [
                    delimiter.join(
                        row[
                            expected - 1:
                        ]
                    )
                ]
            )

            repaired_rows.append(
                repaired
            )

            repair_log.append({
                "row": row_number,
                "problem": "Extra columns",
                "before": original_count,
                "after": expected,
            })

        with open(
            output_path,
            "w",
            encoding="utf-8-sig",
            newline="",
        ) as destination:

            writer = csv.writer(
                destination,
                delimiter=delimiter,
                quotechar='"',
                quoting=csv.QUOTE_MINIMAL,
            )

            writer.writerows(
                repaired_rows
            )

        return {
            "output": output_path,
            "repairs": repair_log,
            "repairCount": len(
                repair_log
            ),
        }


# ============================================================
# STORE VALIDATOR
# ============================================================

class StoreValidator:

    @staticmethod
    def value(
        row,
        mapping,
        field,
    ):

        column = mapping.get(
            field,
            "",
        )

        if not column:
            return ""

        if column not in row.index:
            return ""

        return clean_text(
            row[column]
        )

    @staticmethod
    def compare_field(
        master_value,
        mapping_value,
    ):

        return (
            normalize_compare_value(
                master_value
            )
            ==
            normalize_compare_value(
                mapping_value
            )
        )

    @staticmethod
    def validate(
        master_df,
        mapping_df,
        master_mapping,
        mapping_mapping,
    ):

        results = []

        master_sid_column = master_mapping.get(
            "SID",
            "",
        )

        mapping_sid_column = mapping_mapping.get(
            "SID",
            "",
        )

        if not master_sid_column:
            raise RuntimeError(
                "SID could not be identified in the master file."
            )

        if not mapping_sid_column:
            raise RuntimeError(
                "SID could not be identified in the mapping file."
            )

        master_sid_lookup = {}

        for index, row in master_df.iterrows():

            sid = clean_text(
                row.get(
                    master_sid_column,
                    "",
                )
            )

            if not sid:
                continue

            key = normalize_compare_value(
                sid
            )

            master_sid_lookup.setdefault(
                key,
                [],
            ).append(
                (index, row)
            )

        mapping_sid_counts = (
            mapping_df[
                mapping_sid_column
            ]
            .fillna("")
            .astype(str)
            .map(
                normalize_compare_value
            )
            .value_counts()
            .to_dict()
        )

        compare_fields = [
            "Store Name",
            "Banner",
            "Nielsen Store Code",
            "Trip Received",
            "Last Trip",
            "Address 1",
            "Address 2",
            "Address 3",
            "ZIP",
            "Active / Inactive",
            "Is Census",
            "Is Exceptions",
        ]

        for row_index, row in mapping_df.iterrows():

            source_row = row_index + 2

            sid = StoreValidator.value(
                row,
                mapping_mapping,
                "SID",
            )

            store_name = StoreValidator.value(
                row,
                mapping_mapping,
                "Store Name",
            )

            problems = []
            checks = {}

            status = "CORRECT"

            sid_key = normalize_compare_value(
                sid
            )

            if not sid:

                status = "ERROR"

                problems.append(
                    "SID is empty"
                )

                results.append({
                    "row": source_row,
                    "sid": sid,
                    "storeName": store_name,
                    "status": status,
                    "problem": "; ".join(
                        problems
                    ),
                    "checks": checks,
                })

                continue

            duplicate_mapping_sid = (
                mapping_sid_counts.get(
                    sid_key,
                    0,
                )
                > 1
            )

            if duplicate_mapping_sid:

                status = "ERROR"

                problems.append(
                    "Duplicate SID in Mapping"
                )

            if sid_key not in master_sid_lookup:

                status = "ERROR"

                problems.append(
                    "SID not found in Master"
                )

                results.append({
                    "row": source_row,
                    "sid": sid,
                    "storeName": store_name,
                    "status": status,
                    "problem": "; ".join(
                        problems
                    ),
                    "checks": checks,
                })

                continue

            master_records = (
                master_sid_lookup[
                    sid_key
                ]
            )

            if len(master_records) > 1:

                status = "ERROR"

                problems.append(
                    "Duplicate SID in Master"
                )

            master_row = (
                master_records[0][1]
            )

            for field in compare_fields:

                master_column = (
                    master_mapping.get(
                        field,
                        "",
                    )
                )

                mapping_column = (
                    mapping_mapping.get(
                        field,
                        "",
                    )
                )

                if (
                    not master_column
                    or not mapping_column
                ):
                    checks[field] = (
                        "NOT MAPPED"
                    )
                    continue

                master_value = clean_text(
                    master_row.get(
                        master_column,
                        "",
                    )
                )

                mapping_value = clean_text(
                    row.get(
                        mapping_column,
                        "",
                    )
                )

                matched = (
                    StoreValidator.compare_field(
                        master_value,
                        mapping_value,
                    )
                )

                checks[field] = (
                    "MATCH"
                    if matched
                    else "MISMATCH"
                )

                if not matched:

                    if status != "ERROR":
                        status = "REVIEW"

                    problems.append(
                        f"{field} mismatch"
                    )

            # -------------------------------
            # Data-quality rules
            # -------------------------------

            for field in [
                "Trip Received",
                "Last Trip",
            ]:

                value = StoreValidator.value(
                    row,
                    mapping_mapping,
                    field,
                )

                if (
                    value
                    and not is_valid_date(value)
                ):

                    if status != "ERROR":
                        status = "REVIEW"

                    problems.append(
                        f"{field} has an invalid/unrecognized date"
                    )

            for field in [
                "Active / Inactive",
                "Is Census",
                "Is Exceptions",
            ]:

                value = StoreValidator.value(
                    row,
                    mapping_mapping,
                    field,
                )

                if not is_binary_flag(value):

                    if status != "ERROR":
                        status = "REVIEW"

                    problems.append(
                        f"{field} expected 1 or 0"
                    )

            updated_by = StoreValidator.value(
                row,
                mapping_mapping,
                "Updated By",
            )

            if updated_by:

                if status != "ERROR":
                    status = "REVIEW"

                problems.append(
                    "Updated By contains a value"
                )

            # Maximum 60-word text check
            for field in [
                "Store Name",
                "Banner",
                "Address 1",
                "Address 2",
                "Address 3",
            ]:

                value = StoreValidator.value(
                    row,
                    mapping_mapping,
                    field,
                )

                if word_count(value) > 60:

                    if status != "ERROR":
                        status = "REVIEW"

                    problems.append(
                        f"{field} exceeds 60 words"
                    )

            results.append({
                "row": source_row,
                "sid": sid,
                "storeName": store_name,
                "status": status,
                "problem": (
                    "; ".join(problems)
                    if problems
                    else "No issues"
                ),
                "checks": checks,
            })

        return results


# ============================================================
# SQL ANALYSIS ENGINE
# ============================================================

class SQLAnalysisEngine:

    @staticmethod
    def execute(df, query):

        if not query.strip():
            raise ValueError(
                "Enter a SQL query."
            )

        connection = sqlite3.connect(
            ":memory:"
        )

        try:

            safe_df = df.copy()

            safe_df.columns = [
                clean_text(column)
                for column in safe_df.columns
            ]

            safe_df.to_sql(
                "data",
                connection,
                index=False,
                if_exists="replace",
            )

            result = pd.read_sql_query(
                query,
                connection,
            )

            return result

        finally:
            connection.close()


# ============================================================
# BACKEND
# ============================================================

class Backend(QObject):

    messageChanged = Signal()
    busyChanged = Signal()
    progressChanged = Signal()

    fileLoaded = Signal(str)
    analysisReady = Signal(str)
    columnMappingReady = Signal(str)
    validationReady = Signal(str)
    csvInspectionReady = Signal(str)
    repairCompleted = Signal(str)
    sqlResultReady = Signal(str)
    exportCompleted = Signal(str)

    def __init__(self):
        super().__init__()

        self._message = "Ready"
        self._busy = False
        self._progress = 0

        self.current_df = None
        self.current_path = ""

        self.master_df = None
        self.mapping_df = None

        self.master_path = ""
        self.mapping_path = ""

        self.master_detected = {}
        self.mapping_detected = {}

        self.validation_results = []

    # ========================================================
    # PROPERTIES
    # ========================================================

    @Property(
        str,
        notify=messageChanged,
    )
    def message(self):
        return self._message

    @Property(
        bool,
        notify=busyChanged,
    )
    def busy(self):
        return self._busy

    @Property(
        int,
        notify=progressChanged,
    )
    def progress(self):
        return self._progress

    def set_message(
        self,
        value,
    ):

        self._message = value
        self.messageChanged.emit()

    def set_busy(
        self,
        value,
    ):

        self._busy = value
        self.busyChanged.emit()

    def set_progress(
        self,
        value,
    ):

        self._progress = int(value)
        self.progressChanged.emit()

    # ========================================================
    # URL/PATH HANDLING
    # ========================================================

    def local_path(
        self,
        value,
    ):

        if not value:
            return ""

        value = str(value)

        if value.startswith(
            "file:"
        ):

            return QUrl(
                value
            ).toLocalFile()

        return value

    # ========================================================
    # GENERIC FILE LOAD
    # ========================================================

    @Slot(str)
    def loadFile(
        self,
        path,
    ):

        try:

            self.set_busy(True)
            self.set_progress(10)

            path = self.local_path(
                path
            )

            df, meta = FileLoader.load(
                path
            )

            self.current_df = df
            self.current_path = path

            self.set_progress(60)

            profile = DataProfiler.analyse(
                df
            )

            profile["fileName"] = (
                os.path.basename(path)
            )

            profile["filePath"] = path

            profile["fileType"] = (
                meta.get(
                    "extension",
                    "",
                )
            )

            profile["delimiter"] = (
                meta.get(
                    "delimiter"
                )
            )

            profile["encoding"] = (
                meta.get(
                    "encoding"
                )
            )

            profile["columnsList"] = (
                list(df.columns)
            )

            self.set_progress(100)

            self.set_message(
                f"Loaded {len(df):,} rows from "
                f"{os.path.basename(path)}"
            )

            self.fileLoaded.emit(
                safe_json(profile)
            )

            self.analysisReady.emit(
                safe_json(profile)
            )

        except Exception as exc:

            self.report_error(
                "Unable to load file",
                exc,
            )

        finally:

            self.set_busy(False)

    # ========================================================
    # FILE ANALYSIS
    # ========================================================

    @Slot()
    def analyseCurrentFile(self):

        try:

            if self.current_df is None:
                raise RuntimeError(
                    "Load a file first."
                )

            profile = DataProfiler.analyse(
                self.current_df
            )

            profile["fileName"] = (
                os.path.basename(
                    self.current_path
                )
            )

            profile["columnsList"] = list(
                self.current_df.columns
            )

            self.analysisReady.emit(
                safe_json(profile)
            )

        except Exception as exc:

            self.report_error(
                "Analysis failed",
                exc,
            )

    # ========================================================
    # MASTER FILE
    # ========================================================

    @Slot(str)
    def loadMaster(
        self,
        path,
    ):

        try:

            self.set_busy(True)

            path = self.local_path(
                path
            )

            df, meta = FileLoader.load(
                path
            )

            self.master_df = df
            self.master_path = path

            self.master_detected = (
                ColumnDetector.detect(
                    df.columns
                )
            )

            payload = {
                "type": "master",
                "path": path,
                "rows": len(df),
                "columns": list(
                    df.columns
                ),
                "mapping": self.master_detected,
            }

            self.columnMappingReady.emit(
                safe_json(payload)
            )

            self.set_message(
                "Master file loaded."
            )

        except Exception as exc:

            self.report_error(
                "Unable to load master file",
                exc,
            )

        finally:
            self.set_busy(False)

    # ========================================================
    # MAPPING FILE
    # ========================================================

    @Slot(str)
    def loadMapping(
        self,
        path,
    ):

        try:

            self.set_busy(True)

            path = self.local_path(
                path
            )

            df, meta = FileLoader.load(
                path
            )

            self.mapping_df = df
            self.mapping_path = path

            self.mapping_detected = (
                ColumnDetector.detect(
                    df.columns
                )
            )

            payload = {
                "type": "mapping",
                "path": path,
                "rows": len(df),
                "columns": list(
                    df.columns
                ),
                "mapping": self.mapping_detected,
            }

            self.columnMappingReady.emit(
                safe_json(payload)
            )

            self.set_message(
                "Mapping file loaded."
            )

        except Exception as exc:

            self.report_error(
                "Unable to load mapping file",
                exc,
            )

        finally:
            self.set_busy(False)

    # ========================================================
    # DETECT STORE COLUMNS
    # ========================================================

    @Slot()
    def detectStoreColumns(self):

        try:

            if self.master_df is None:
                raise RuntimeError(
                    "Select the master file."
                )

            if self.mapping_df is None:
                raise RuntimeError(
                    "Select the mapping file."
                )

            self.master_detected = (
                ColumnDetector.detect(
                    self.master_df.columns
                )
            )

            self.mapping_detected = (
                ColumnDetector.detect(
                    self.mapping_df.columns
                )
            )

            payload = {
                "standardFields": STANDARD_FIELDS,
                "master": self.master_detected,
                "mapping": self.mapping_detected,
            }

            self.columnMappingReady.emit(
                safe_json(payload)
            )

            self.set_message(
                "Columns detected."
            )

        except Exception as exc:

            self.report_error(
                "Column detection failed",
                exc,
            )

    # ========================================================
    # VALIDATE STORES
    # ========================================================

    @Slot()
    def validateStores(self):

        try:

            self.set_busy(True)
            self.set_progress(10)

            if self.master_df is None:
                raise RuntimeError(
                    "Select the master store file."
                )

            if self.mapping_df is None:
                raise RuntimeError(
                    "Select the mapping file."
                )

            if not self.master_detected:
                self.master_detected = (
                    ColumnDetector.detect(
                        self.master_df.columns
                    )
                )

            if not self.mapping_detected:
                self.mapping_detected = (
                    ColumnDetector.detect(
                        self.mapping_df.columns
                    )
                )

            master_mapping = {
                field: data.get(
                    "column",
                    "",
                )
                for field, data
                in self.master_detected.items()
            }

            mapping_mapping = {
                field: data.get(
                    "column",
                    "",
                )
                for field, data
                in self.mapping_detected.items()
            }

            self.set_progress(30)

            results = StoreValidator.validate(
                self.master_df,
                self.mapping_df,
                master_mapping,
                mapping_mapping,
            )

            self.validation_results = (
                results
            )

            self.set_progress(90)

            total = len(results)

            correct = sum(
                1
                for item in results
                if item["status"] == "CORRECT"
            )

            review = sum(
                1
                for item in results
                if item["status"] == "REVIEW"
            )

            errors = sum(
                1
                for item in results
                if item["status"] == "ERROR"
            )

            payload = {
                "total": total,
                "correct": correct,
                "review": review,
                "errors": errors,
                "results": results,
            }

            self.set_progress(100)

            self.validationReady.emit(
                safe_json(payload)
            )

            self.set_message(
                f"Validation complete: "
                f"{total} checked, "
                f"{correct} correct, "
                f"{review} review, "
                f"{errors} errors."
            )

        except Exception as exc:

            self.report_error(
                "Store validation failed",
                exc,
            )

        finally:

            self.set_busy(False)

    # ========================================================
    # CSV INSPECTION
    # ========================================================

    @Slot(str)
    def inspectCSV(
        self,
        path,
    ):

        try:

            path = self.local_path(
                path
            )

            result = (
                CSVRepairEngine.inspect(
                    path
                )
            )

            result["path"] = path

            self.csvInspectionReady.emit(
                safe_json(result)
            )

            count = len(
                result["problems"]
            )

            self.set_message(
                f"CSV inspection complete: "
                f"{count} suspicious line(s)."
            )

        except Exception as exc:

            self.report_error(
                "CSV inspection failed",
                exc,
            )

    # ========================================================
    # CSV REPAIR
    # ========================================================

    @Slot(str, str)
    def repairCSV(
        self,
        source_path,
        output_path,
    ):

        try:

            source_path = self.local_path(
                source_path
            )

            output_path = self.local_path(
                output_path
            )

            if not output_path:
                raise RuntimeError(
                    "Choose an output file."
                )

            result = CSVRepairEngine.repair(
                source_path,
                output_path,
            )

            self.repairCompleted.emit(
                safe_json(result)
            )

            self.set_message(
                f"CSV repair completed. "
                f"{result['repairCount']} row(s) repaired."
            )

        except Exception as exc:

            self.report_error(
                "CSV repair failed",
                exc,
            )

    # ========================================================
    # SQL - ANALYSIS WORKSPACE ONLY
    # ========================================================

    @Slot(str)
    def runSQL(
        self,
        query,
    ):

        try:

            if self.current_df is None:
                raise RuntimeError(
                    "Load a file in Data Analysis first."
                )

            result = SQLAnalysisEngine.execute(
                self.current_df,
                query,
            )

            payload = {
                "columns": list(
                    result.columns
                ),
                "rows": (
                    result
                    .fillna("")
                    .astype(str)
                    .to_dict(
                        orient="records"
                    )
                ),
                "rowCount": len(result),
            }

            self.sqlResultReady.emit(
                safe_json(payload)
            )

            self.set_message(
                f"SQL returned "
                f"{len(result):,} row(s)."
            )

        except Exception as exc:

            self.report_error(
                "SQL query failed",
                exc,
            )

    # ========================================================
    # EXPORT CURRENT DATA
    # ========================================================

    @Slot(str)
    def exportCurrentData(
        self,
        output_path,
    ):

        try:

            if self.current_df is None:
                raise RuntimeError(
                    "No data is loaded."
                )

            output_path = self.local_path(
                output_path
            )

            if not output_path:
                raise RuntimeError(
                    "Choose an output path."
                )

            extension = (
                Path(
                    output_path
                ).suffix.lower()
            )

            if extension == ".csv":

                self.current_df.to_csv(
                    output_path,
                    index=False,
                    encoding="utf-8-sig",
                )

            elif extension in {
                ".xlsx",
                ".xlsm",
            }:

                self.current_df.to_excel(
                    output_path,
                    index=False,
                )

            elif extension == ".json":

                self.current_df.to_json(
                    output_path,
                    orient="records",
                    indent=2,
                    force_ascii=False,
                )

            else:

                raise RuntimeError(
                    "Export as CSV, XLSX or JSON."
                )

            payload = {
                "path": output_path,
                "rows": len(
                    self.current_df
                ),
            }

            self.exportCompleted.emit(
                safe_json(payload)
            )

            self.set_message(
                "Data exported successfully."
            )

        except Exception as exc:

            self.report_error(
                "Export failed",
                exc,
            )

    # ========================================================
    # EXPORT VALIDATION REPORT
    # ========================================================

    @Slot(str)
    def exportValidationReport(
        self,
        output_path,
    ):

        try:

            if not self.validation_results:
                raise RuntimeError(
                    "Run store validation first."
                )

            output_path = self.local_path(
                output_path
            )

            rows = []

            for item in self.validation_results:

                row = {
                    "Source Row": item.get(
                        "row",
                        "",
                    ),
                    "SID": item.get(
                        "sid",
                        "",
                    ),
                    "Store Name": item.get(
                        "storeName",
                        "",
                    ),
                    "Status": item.get(
                        "status",
                        "",
                    ),
                    "Problem": item.get(
                        "problem",
                        "",
                    ),
                }

                checks = item.get(
                    "checks",
                    {}
                )

                for field, value in checks.items():

                    row[
                        f"{field} Check"
                    ] = value

                rows.append(row)

            report_df = pd.DataFrame(
                rows
            )

            extension = Path(
                output_path
            ).suffix.lower()

            if extension == ".csv":

                report_df.to_csv(
                    output_path,
                    index=False,
                    encoding="utf-8-sig",
                )

            else:

                if not output_path.lower().endswith(
                    ".xlsx"
                ):
                    output_path += ".xlsx"

                report_df.to_excel(
                    output_path,
                    index=False,
                )

            self.exportCompleted.emit(
                safe_json({
                    "path": output_path,
                    "rows": len(
                        report_df
                    ),
                })
            )

            self.set_message(
                "Validation report exported."
            )

        except Exception as exc:

            self.report_error(
                "Validation report export failed",
                exc,
            )

    # ========================================================
    # ERROR HANDLING
    # ========================================================

    def report_error(
        self,
        title,
        exception,
    ):

        message = (
            f"{title}: {exception}"
        )

        print(
            "\n"
            + "=" * 70
        )

        print(message)

        traceback.print_exc()

        print(
            "=" * 70
            + "\n"
        )

        self.set_message(
            message
        )


# ============================================================
# APPLICATION STARTUP
# ============================================================

def main():

    app = QGuiApplication(
        sys.argv
    )

    app.setApplicationName(
        APP_NAME
    )

    app.setApplicationVersion(
        APP_VERSION
    )

    engine = QQmlApplicationEngine()

    backend = Backend()

    engine.rootContext().setContextProperty(
        "backend",
        backend,
    )

    qml_path = resource_path(
        "Main.qml"
    )

    if not os.path.exists(
        qml_path
    ):

        print(
            "FATAL ERROR:"
        )

        print(
            f"Main.qml was not found:\n"
            f"{qml_path}"
        )

        return 1

    print(
        f"Starting {APP_NAME} "
        f"{APP_VERSION}"
    )

    print(
        f"Loading QML from: "
        f"{qml_path}"
    )

    engine.load(
        QUrl.fromLocalFile(
            qml_path
        )
    )

    if not engine.rootObjects():

        print(
            "\n"
            "ERROR: Main.qml failed to load.\n"
            "Read the QML errors printed above "
            "this message.\n"
        )

        return 1

    return app.exec()


if __name__ == "__main__":
    sys.exit(
        main()
    )
