# core/controllers/health_controller.py
import json
from pathlib import Path
from PySide6.QtCore import QObject, Signal

from core.common import read_table
from core.explorer import run_sql
from core.health import profile, statistic, export_html_report
from core.utils.helpers import local_path, free_memory


class HealthController(QObject):
    healthReady = Signal(str)
    tableReady = Signal(str)
    statsReady = Signal(str)

    def __init__(self, async_runner, notify_cb, say_cb):
        super().__init__()
        self.async_runner = async_runner
        self.notify = notify_cb
        self.say = say_cb
        self._df = None

    def load_data(self, path):
        self._df = None
        free_memory()

        def task():
            local = local_path(path)
            df = read_table(local)
            prof = profile(df)
            df_view = df.head(1000).fillna("")
            table_data = {
                "columns": [str(c) for c in df_view.columns],
                "rows": df_view.to_dict(orient="records"),
                "total": len(df),
                "displayed": len(df_view),
                "truncated": len(df) > 1000
            }
            return df, json.dumps(prof), json.dumps(table_data)

        def on_complete(result):
            self._df, prof_json, table_json = result
            self.healthReady.emit(prof_json)
            self.tableReady.emit(table_json)
            self.notify("Dataset Active", f"Loaded {len(self._df):,} rows into workspace.", "info")

        self.async_runner.run_async("load_data", task, on_complete)

    def export_health_report(self, dst_path):
        if self._df is None:
            return self.notify("Export Failed", "No dataset active.", "warning")

        def task():
            return export_html_report(self._df, local_path(dst_path))

        self.async_runner.run_async("health_report", task, lambda p: self.notify("Report Generated", f"Executive HTML report saved to {Path(p).name}", "success"))

    def search(self, query, col):
        if self._df is None:
            return

        def task():
            df = self._df
            if query:
                if col and col != "All columns" and col in df.columns:
                    df = df[df[col].astype(str).str.contains(query, case=False, na=False)]
                else:
                    mask = df.astype(str).apply(lambda x: x.str.contains(query, case=False, na=False)).any(axis=1)
                    df = df[mask]
            view = df.head(1000).fillna("")
            return json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.to_dict(orient="records"),
                "total": len(df)
            }), len(df)

        def on_complete(result):
            table_json, count = result
            self.tableReady.emit(table_json)
            self.say(f"Search found {count:,} matches.")

        self.async_runner.run_async("search", task, on_complete)

    def sql(self, query):
        if self._df is None:
            return

        def task():
            res_df = run_sql(self._df, query)
            view = res_df.head(1000).fillna("")
            return json.dumps({
                "columns": [str(c) for c in view.columns],
                "rows": view.to_dict(orient="records"),
                "total": len(res_df)
            })

        self.async_runner.run_async("sql_query", task, lambda p: self.tableReady.emit(p))

    def stats(self, col, op, group):
        if self._df is None:
            return

        def task():
            return json.dumps(statistic(self._df, col, op, group))

        self.async_runner.run_async("stats", task, lambda p: self.statsReady.emit(p))
