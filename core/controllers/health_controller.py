import json

from PySide6.QtCore import (
    QObject,
    Slot,
    Signal,
)

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

    def _emit_table(self, df):
        if df is None:
            return

        columns = [
            str(column)
            for column in df.columns
        ]

        total = len(df)
        displayed = min(
            100,
            total,
        )

        rows = (
            df.head(displayed)
            .fillna("")
            .astype(str)
            .to_dict(
                orient="records"
            )
        )

        self.tableReady.emit(
            json.dumps({
                "columns": columns,
                "rows": rows,
                "total": total,
                "displayed": displayed,
                "truncated": total > displayed,
            })
        )

    @Slot(str)
    def load_data(self, path):

        def task():
            local = local_path(path)
            dataframe = read_table(local)
            return local, dataframe

        def success(result):
            self.current_file, self.df = result

            self._emit_table(
                self.df
            )

            def profile_task():
                return profile(self.df)

            def profile_success(data):
                self.healthReady.emit(
                    json.dumps(data)
                )

            def profile_error(error):
                if self.notify:
                    self.notify(
                        "Health Error",
                        str(error),
                        "error",
                    )

            self.async_runner.run(
                profile_task,
                profile_success,
                profile_error,
            )

        def error(exc):
            if self.notify:
                self.notify(
                    "Load Error",
                    str(exc),
                    "error",
                )

        self.async_runner.run(
            task,
            success,
            error,
        )

    @Slot(str, str)
    def search(self, query, col):

        def task():
            if self.df is None:
                raise ValueError(
                    "Load a dataset first."
                )

            query_text = str(
                query or ""
            ).lower()

            if col and col in self.df.columns:
                mask = (
                    self.df[col]
                    .astype(str)
                    .str.lower()
                    .str.contains(
                        query_text,
                        na=False,
                        regex=False,
                    )
                )

            else:
                mask = (
                    self.df
                    .astype(str)
                    .apply(
                        lambda series:
                        series.str.lower()
                        .str.contains(
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

        def error(exc):
            if self.notify:
                self.notify(
                    "Search Error",
                    str(exc),
                    "error",
                )

        self.async_runner.run(
            task,
            success,
            error,
        )

    @Slot(str)
    def sql(self, query):

        def task():
            if self.df is None:
                raise ValueError(
                    "Load a dataset first."
                )

            # IMPORTANT:
            # run_sql signature is run_sql(df, query)
            return run_sql(
                self.df,
                query,
            )

        def success(result):
            self._emit_table(result)

        def error(exc):
            if self.notify:
                self.notify(
                    "SQL Error",
                    str(exc),
                    "error",
                )

        self.async_runner.run(
            task,
            success,
            error,
        )

    @Slot(str, str, str)
    def stats(
        self,
        col,
        op,
        group,
    ):

        def task():
            if self.df is None:
                raise ValueError(
                    "Load a dataset first."
                )

            return statistic(
                self.df,
                col,
                op,
                group,
            )

        def success(result):
            self.statsReady.emit(
                json.dumps(
                    result,
                    default=str,
                )
            )

        def error(exc):
            if self.notify:
                self.notify(
                    "Stats Error",
                    str(exc),
                    "error",
                )

        self.async_runner.run(
            task,
            success,
            error,
        )

    @Slot(str)
    def export_health_report(self, dst):

        def task():
            if self.df is None:
                raise ValueError(
                    "Load a dataset first."
                )

            data = check_dataframe_health(
                self.df
            )

            export_html_report(
                data,
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
                self.notify(
                    "Export Error",
                    str(exc),
                    "error",
                )

        self.async_runner.run(
            task,
            success,
            error,
        )
