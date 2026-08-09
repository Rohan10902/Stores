import json

from PySide6.QtCore import (
    QObject,
    Slot,
    Signal,
)

from ..csv_repair import CSVRepairTool
from core.utils.helpers import local_path


class RepairController(QObject):
    repairReady = Signal(str)

    def __init__(
        self,
        async_runner,
        notify_cb,
        fail_cb,
        parent=None,
    ):
        super().__init__(parent)

        self.async_runner = async_runner
        self.notify = notify_cb
        self.fail = fail_cb

        self.tool = CSVRepairTool()
        self.current_file = ""

    def _emit_state(self, payload):
        self.repairReady.emit(
            json.dumps(
                payload,
                default=str,
            )
        )

    @Slot(str)
    def inspect_repair(self, path):
        try:
            self.current_file = local_path(
                path
            )

            payload = self.tool.inspect_csv(
                self.current_file
            )

            self._emit_state(payload)

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Repair Load Error",
                    str(exc),
                )

    @Slot(int)
    def join_repair_rows(
        self,
        issue_index,
    ):
        try:
            self._emit_state(
                self.tool.join_shifted_rows(
                    issue_index
                )
            )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Join Rows Error",
                    str(exc),
                )

    @Slot(int, int, str, bool)
    def apply_repair_mapping(
        self,
        issue_index,
        col_index,
        target,
        remember,
    ):
        try:
            self._emit_state(
                self.tool.apply_mapping(
                    issue_index,
                    col_index,
                    target,
                    remember,
                )
            )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Mapping Error",
                    str(exc),
                )

    @Slot(int, int)
    def keep_repair_unresolved(
        self,
        issue_index,
        col_index,
    ):
        try:
            self._emit_state(
                self.tool.keep_unresolved(
                    issue_index,
                    col_index,
                )
            )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Keep Unresolved Error",
                    str(exc),
                )

    @Slot(int)
    def keep_repair_issue(
        self,
        issue_index,
    ):
        try:
            self._emit_state(
                self.tool.keep_issue_as_is(
                    issue_index
                )
            )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Keep Issue Error",
                    str(exc),
                )

    @Slot(int, str)
    def create_repair_record(
        self,
        issue_index,
        mapping_json,
    ):
        try:
            self._emit_state(
                self.tool.create_record_from_extras(
                    issue_index,
                    mapping_json,
                )
            )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Create Record Error",
                    str(exc),
                )

    @Slot(str)
    def delete_repair_record(
        self,
        record_id,
    ):
        try:
            self._emit_state(
                self.tool.delete_created_record(
                    record_id
                )
            )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Delete Record Error",
                    str(exc),
                )

    @Slot()
    def undo_repair_action(self):
        try:
            self._emit_state(
                self.tool.undo_action()
            )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Undo Error",
                    str(exc),
                )

    @Slot(str, str)
    def repair(self, src, dst):
        try:
            src_path = local_path(src)
            dst_path = local_path(dst)

            if (
                not self.tool.rows
                or self.current_file
                != src_path
            ):
                payload = self.tool.inspect_csv(
                    src_path
                )

                self.current_file = src_path

                # Keep the QML synchronized even
                # when repair() implicitly loads.
                self._emit_state(payload)

            self.tool.export_csv(
                dst_path
            )

            if self.notify:
                self.notify(
                    "Success",
                    "Repaired CSV exported successfully.",
                    "success",
                )

        except Exception as exc:
            if self.fail:
                self.fail(
                    "Export Error",
                    str(exc),
                )
