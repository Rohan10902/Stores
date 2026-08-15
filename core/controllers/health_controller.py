import json

from PySide6.QtCore import QObject, Slot, Signal

from core.common import read_table
from core.explorer import run_sql
from core.health import (
    profile,
    statistic,
    export_html_report,
    check_dataframe_health,
)
from core.utils.helpers import local_path


class HealthController(QObject):
    healthReady = Signal(str)
    tableReady = Signal(str)
    statsReady = Signal(str)

    def __init__(
        self,
        async_runner,
        notify_cb,
        say_cb,
        parent=None,
    ):
        super().__init__(parent)

        self.async_runner = async_runner
        self.notify = notify_cb
        self.say = say_cb
        self.current_file = ""
        self.df = None

    @staticmethod
    def _column_type(series):
        dtype = str(series.dtype).lower()
        if "bool" in dtype:
            return "boolean"
        if "datetime" in dtype or "date" in dtype:
            return "date"
        if any(token in dtype for token in ("int", "float", "double", "decimal")):
            return "numeric"
        return "text"

    def _health_payload(self, dataframe):
        if dataframe is None:
            return {
                "rows": 0,
                "columns": 0,
                "completeness": 0,
                "duplicateRows": 0,
                "score": 0,
                "columnNames": [],
                "columnTypes": {},
                "operations": {},
                "columnStats": [],
            }

        total_rows = len(dataframe)
        total_columns = len(dataframe.columns)
        total_cells = max(1, total_rows * total_columns)
        missing_cells = int(dataframe.isna().sum().sum())
        duplicate_rows = int(dataframe.duplicated().sum())
        completeness = round(
            max(0.0, 100.0 * (1.0 - missing_cells / total_cells)),
            1,
        )
        duplicate_rate = (
            duplicate_rows / max(1, total_rows) * 100.0
        )
        score = round(
            max(0.0, min(100.0, completeness - duplicate_rate)),
            1,
        )

        column_names = [str(column) for column in dataframe.columns]
        column_types = {}
        operations = {}
        column_stats = []

        for column in dataframe.columns:
            name = str(column)
            series = dataframe[column]
            kind = self._column_type(series)
            column_types[name] = kind

            if kind == "numeric":
                ops = [
                    "count",
                    "sum",
                    "mean",
                    "min",
                    "max",
                    "median",
                    "nunique",
                    "nulls",
                ]
            else:
                ops = ["count", "nunique", "nulls"]

            operations[kind] = ops

            blank = int(series.isna().sum())
            non_blank = int(total_rows - blank)
            unique = int(series.nunique(dropna=True))

            column_stats.append({
                "column": name,
                "type": kind,
                "blank": blank,
                "unique": unique,
                "nonBlank": non_blank,
            })

        # Keep one deterministic operation list for each detected type.
        operations.setdefault("text", ["count", "nunique", "nulls"])
        operations.setdefault("boolean", ["count", "nunique", "nulls"])
        operations.setdefault("date", ["count", "nunique", "nulls"])
        operations.setdefault(
            "numeric",
            [
                "count",
                "sum",
                "mean",
                "min",
                "max",
                "median",
                "nunique",
                "nulls",
            ],
        )

        return {
            "rows": total_rows,
            "columns": total_columns,
            "completeness": completeness,
            "duplicateRows": duplicate_rows,
            "score": score,
            "columnNames": column_names,
            "columnTypes": column_types,
            "operations": operations,
            "columnStats": column_stats,
            "missingCells": missing_cells,
            "profile": profile(dataframe),
        }

    @staticmethod
    def _emit_table_payload(dataframe):
        if dataframe is None:
            return None

        columns = [str(column) for column in dataframe.columns]
        total = len(dataframe)

        # Do not artificially truncate in-app data views. The application already
        # owns the loaded dataframe, so Explore and Health should expose the full
        # result set rather than advertising a 100-row limitation.
        displayed = total
        rows = (
            dataframe
            .fillna("")
            .astype(str)
            .to_dict(orient="records")
        )

        return {
            "columns": columns,
            "rows": rows,
            "total": total,
            "displayed": displayed,
            "truncated": False,
        }

    def _emit_table(self, dataframe):
        payload = self._emit_table_payload(dataframe)
        if payload is not None:
            self.tableReady.emit(json.dumps(payload, default=str))

    @staticmethod
    def _stats_payload(dataframe, column, operation, group):
        result = statistic(
            dataframe,
            column,
            operation,
            group,
        )

        rows = []

        if isinstance(result, dict) and isinstance(result.get("rows"), list):
            raw_rows = result["rows"]
            group_name = str(group or "")
            value_name = str(operation or "value")

            for raw in raw_rows:
                if group_name and group_name in raw:
                    label = raw.get(group_name, "")
                    value = raw.get(value_name, "")
                else:
                    keys = list(raw.keys())
                    label = raw.get(keys[0], "") if keys else ""
                    value = raw.get(keys[1], "") if len(keys) > 1 else ""

                rows.append({
                    "label": "(blank)" if label is None else str(label),
                    "result": "" if value is None else value,
                    "count": "",
                    "percent": "",
                    "interpretation": operation,
                })
        elif isinstance(result, dict):
            value = result.get("value", "")
            rows.append({
                "label": f"{operation} — {column}",
                "result": "" if value is None else value,
                "count": "",
                "percent": "",
                "interpretation": operation,
            })

        return {
            "column": column,
            "operation": operation,
            "group": group,
            "rows": rows,
            "insight": (
                f"{operation} calculated for {column}"
                + (f" grouped by {group}" if group else "")
                + "."
            ),
        }

    @Slot(str)
    def load_data(self, path):
        def task():
            local = local_path(path)
            dataframe = read_table(local)
            return local, dataframe

        def success(result):
            self.current_file, self.df = result

            self._emit_table(self.df)
            self.healthReady.emit(
                json.dumps(
                    self._health_payload(self.df),
                    default=str,
                )
            )

        def error(exc):
            if self.notify:
                self.notify("Load Error", str(exc), "error")

        self.async_runner.run(task, success, error)

    @Slot(str, str)
    def search(self, query, col):
        def task():
            if self.df is None:
                raise ValueError("Load a dataset first.")

            query_text = str(query or "").lower()

            if col and col in self.df.columns:
                mask = (
                    self.df[col]
                    .astype(str)
                    .str.lower()
                    .str.contains(query_text, na=False, regex=False)
                )
            else:
                mask = (
                    self.df
                    .astype(str)
                    .apply(
                        lambda series: series.str.lower().str.contains(
                            query_text,
                            na=False,
                            regex=False,
                        )
                    )
                    .any(axis=1)
                )

            return self.df[mask]

        def success(result):
            self._emit_table(result)
            if self.say:
                self.say(f"Search returned {len(result):,} rows")

        def error(exc):
            if self.notify:
                self.notify("Search Error", str(exc), "error")

        self.async_runner.run(task, success, error)

    @Slot(str)
    def sql(self, query):
        def task():
            if self.df is None:
                raise ValueError("Load a dataset first.")
            return run_sql(self.df, query)

        def success(result):
            self._emit_table(result)
            if self.say:
                self.say(f"Query returned {len(result):,} rows")

        def error(exc):
            if self.notify:
                self.notify("SQL Error", str(exc), "error")

        self.async_runner.run(task, success, error)

    @Slot(str, str, str)
    def stats(self, col, op, group):
        def task():
            if self.df is None:
                raise ValueError("Load a dataset first.")
            return self._stats_payload(
                self.df,
                col,
                op,
                group,
            )

        def success(result):
            self.statsReady.emit(
                json.dumps(result, default=str)
            )

        def error(exc):
            if self.notify:
                self.notify("Stats Error", str(exc), "error")

        self.async_runner.run(task, success, error)

    @Slot(str)
    def export_health_report(self, dst):
        def task():
            if self.df is None:
                raise ValueError("Load a dataset first.")

            health_data = check_dataframe_health(self.df)
            export_html_report(
                health_data,
                local_path(dst),
            )

        def success(_result):
            if self.notify:
                self.notify(
                    "Success",
                    "Health report exported.",
                    "success",
                )

        def error(exc):
            if self.notify:
                self.notify("Export Error", str(exc), "error")

        self.async_runner.run(task, success, error)
