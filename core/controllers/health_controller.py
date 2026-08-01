# core/controllers/health_controller.py
import json
import os
import pandas as pd
from pathlib import Path
from PySide6.QtCore import QObject, Signal

from core.common import read_table
from core.explorer import run_sql
from core.health import profile, statistic, export_html_report
from core.utils.helpers import local_path, free_memory
from core.utils.logger import get_logger

logger = get_logger("HealthController")


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

        l_path = local_path(path)
        # 🔴 CRITICAL: Verify file exists before passing to Pandas
        if not l_path or not os.path.exists(l_path):
            return self.notify("Load Failed", f"File not found at: {l_path}", "error")

        def task():
            try:
                df = read_table(l_path)
                # 🔴 CRITICAL: Check for empty datasets gracefully
                if df is None or df.empty:
                    raise ValueError("The loaded dataset is empty or corrupted.")
                    
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
            except Exception as e:
                # 🔴 CRITICAL: Log unexpected parsing/profiling errors
                logger.exception("Unexpected error during data loading and profiling.")
                raise

        def on_complete(result):
            self._df, prof_json, table_json = result
            self.healthReady.emit(prof_json)
            self.tableReady.emit(table_json)
            self.notify("Dataset Active", f"Loaded {len(self._df):,} rows into workspace.", "info")

        self.async_runner.run_async("load_data", task, on_complete)

    def export_health_report(self, dst_path):
        if self._df is None or self._df.empty:
            return self.notify("Export Failed", "No active dataset to export.", "warning")

        l_path = local_path(dst_path)
        
        def task():
            try:
                # 🔴 CRITICAL: Verify the target directory exists before writing
                target_dir = os.path.dirname(l_path)
                if target_dir and not os.path.exists(target_dir):
                    raise FileNotFoundError(f"Target directory does not exist: {target_dir}")
                    
                return export_html_report(self._df, l_path)
            except Exception as e:
                logger.exception("Unexpected error exporting health report.")
                raise

        self.async_runner.run_async(
            "health_report", 
            task, 
            lambda p: self.notify("Report Generated", f"Executive HTML report saved to {Path(p).name}", "success")
        )

    def search(self, query, col):
        if self._df is None or self._df.empty:
            return

        def task():
            try:
                df = self._df
                if query:
                    if col and col != "All columns":
                        # 🔴 CRITICAL: Ensure the imported dataset contains the required column
                        if col not in df.columns:
                            raise KeyError(f"Cannot search. Column '{col}' does not exist.")
                            
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
                
            except KeyError as ke:
                logger.error(str(ke))
                raise
            except Exception as e:
                logger.exception("Unexpected error during search operation.")
                raise

        def on_complete(result):
            table_json, count = result
            self.tableReady.emit(table_json)
            self.say(f"Search found {count:,} matches.")

        self.async_runner.run_async("search", task, on_complete)

    def sql(self, query):
        if self._df is None or self._df.empty:
            return

        # 🔴 CRITICAL: Validate input string before running SQL engine
        if not query or not str(query).strip():
            return

        def task():
            try:
                res_df = run_sql(self._df, query)
                if res_df is None:
                    res_df = pd.DataFrame()
                    
                view = res_df.head(1000).fillna("")
                return json.dumps({
                    "columns": [str(c) for c in view.columns],
                    "rows": view.to_dict(orient="records"),
                    "total": len(res_df)
                })
            except Exception as e:
                logger.exception("Unexpected error executing SQL query.")
                raise

        self.async_runner.run_async("sql_query", task, lambda p: self.tableReady.emit(p))

    def stats(self, col, op, group):
        if self._df is None or self._df.empty:
            return

        def task():
            try:
                # 🔴 CRITICAL: Prevent KeyError by checking column existence before calculations
                if col and col not in self._df.columns:
                    raise KeyError(f"Target column '{col}' not found in dataset.")
                if group and group not in self._df.columns:
                    raise KeyError(f"Group column '{group}' not found in dataset.")
                    
                return json.dumps(statistic(self._df, col, op, group))
            except KeyError as ke:
                logger.error(str(ke))
                raise
            except Exception as e:
                logger.exception("Unexpected error calculating statistics.")
                raise

        self.async_runner.run_async("stats", task, lambda p: self.statsReady.emit(p))
