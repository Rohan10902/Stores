"""Headless Qt/QML acceptance checks for StoreLens workspace pages."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest
from PySide6.QtCore import QUrl
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest

from core.controllers import MainBackendController


PAGE_NAMES = [
    "Dashboard",
    "Compare & Validate",
    "Record Repair",
    "Single File Review",
    "Store Builder",
    "Explore / Data",
    "Health",
]


@pytest.fixture(scope="session")
def qml_app():
    """Keep one Qt application alive for the complete QML acceptance session."""
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    return QApplication.instance() or QApplication([])


def _load_main(qml_app):
    """Create and load one Main.qml instance and return its objects."""
    engine = QQmlApplicationEngine()
    backend = MainBackendController()
    engine.rootContext().setContextProperty("backend", backend)
    root_path = Path(__file__).resolve().parents[1] / "qml" / "Main.qml"
    engine.addImportPath(str(root_path.parent))
    engine.load(QUrl.fromLocalFile(str(root_path)))
    if not engine.rootObjects():
        warnings = "\n".join(str(item) for item in engine.warnings())
        engine.deleteLater()
        qml_app.processEvents()
        pytest.fail(f"Main.qml did not create a root object. QML warnings:\n{warnings}")
    root = engine.rootObjects()[0]
    return engine, root, backend


def _wait_for_page(qml_app, root, index, timeout_ms=1500):
    root.setProperty("currentPage", index)
    deadline = timeout_ms
    while deadline > 0:
        qml_app.processEvents()
        if bool(root.pageLoaded(index)):
            return
        QTest.qWait(25)
        deadline -= 25
    pytest.fail(f"{PAGE_NAMES[index]} page failed to load within {timeout_ms} ms")


@pytest.mark.parametrize("index,name", list(enumerate(PAGE_NAMES)))
def test_every_workspace_page_loads_without_qml_runtime_errors(qml_app, index, name):
    engine, root, _backend = _load_main(qml_app)
    try:
        _wait_for_page(qml_app, root, index)
        assert root.pageItem(index) is not None, f"{name} page has no loaded QML item"
    finally:
        engine.clearComponentCache()
        engine.deleteLater()
        qml_app.processEvents()


def test_compare_preview_payload_reaches_main_qml_model(qml_app):
    engine, root, backend = _load_main(qml_app)
    try:
        _wait_for_page(qml_app, root, 1)
        payload = json.dumps(
            {
                "columns": ["SID", "Store Name", "City"],
                "rows": [["S100", "Alpha Store", "Pune"]],
                "total": 1,
            }
        )
        backend.validate.masterPreviewReady.emit(payload)
        _wait_for_page(qml_app, root, 1)
        assert list(root.property("masterPreviewColumns")) == ["SID", "Store Name", "City"]
        assert list(root.property("masterPreviewRows"))[0] == ["S100", "Alpha Store", "Pune"]
        assert root.property("masterPreviewTotal") == 1
        assert root.property("previewVisible") is True
        assert root.property("previewError") == ""
    finally:
        engine.clearComponentCache()
        engine.deleteLater()
        qml_app.processEvents()


def test_explore_table_payload_reaches_page_model(qml_app):
    engine, root, backend = _load_main(qml_app)
    try:
        _wait_for_page(qml_app, root, 5)
        payload = json.dumps(
            {
                "columns": ["SID", "Store Name", "City"],
                "rows": [
                    {"SID": "100", "Store Name": "Alpha Store", "City": "Pune"},
                    {"SID": "200", "Store Name": "Beta Store", "City": "Mumbai"},
                ],
                "total": 2,
                "displayed": 2,
                "truncated": False,
            }
        )
        backend.health.tableReady.emit(payload)
        qml_app.processEvents()
        page = root.pageItem(5)
        assert page is not None
        assert list(page.property("columns")) == ["SID", "Store Name", "City"]
        rows = list(page.property("rows"))
        assert rows[0]["SID"] == "100"
        assert rows[0]["Store Name"] == "Alpha Store"
        assert page.property("totalRows") == 2
    finally:
        engine.clearComponentCache()
        engine.deleteLater()
        qml_app.processEvents()


def test_health_payload_and_statistics_reach_page_models(qml_app):
    engine, root, backend = _load_main(qml_app)
    try:
        _wait_for_page(qml_app, root, 6)
        health_payload = {
            "rows": 2,
            "columns": 3,
            "completeness": 100,
            "duplicateRows": 0,
            "score": 100,
            "columnNames": ["SID", "Store Name", "City"],
            "columnTypes": {"SID": "text", "Store Name": "text", "City": "text"},
            "columnStats": [
                {"column": "SID", "type": "text", "blank": 0, "unique": 2, "nonBlank": 2}
            ],
            "profile": {"rowCount": 2, "columnCount": 3},
        }
        stats_payload = {
            "column": "City",
            "operation": "count",
            "group": "",
            "rows": [{"label": "count — City", "result": 2}],
            "insight": "count calculated for City.",
        }
        backend.health.healthReady.emit(json.dumps(health_payload))
        backend.health.statsReady.emit(json.dumps(stats_payload))
        qml_app.processEvents()
        page = root.pageItem(6)
        assert page is not None
        health_data = page.property("healthData")
        stats_data = page.property("statsData")
        assert health_data["columnTypes"]["SID"] == "text"
        assert health_data["profile"]["rowCount"] == 2
        assert stats_data["rows"][0]["result"] == 2
    finally:
        engine.clearComponentCache()
        engine.deleteLater()
        qml_app.processEvents()
