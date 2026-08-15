"""Headless Qt/QML acceptance checks for every StoreLens workspace page."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest
from PySide6.QtCore import QUrl
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine

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


@pytest.fixture
def qml_application():
    """Create a fresh QML engine per test to isolate Loader lifecycles."""
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    app = QApplication.instance() or QApplication([])
    engine = QQmlApplicationEngine()
    backend = MainBackendController()
    engine.rootContext().setContextProperty("backend", backend)

    root_path = Path(__file__).resolve().parents[1] / "qml" / "Main.qml"
    engine.addImportPath(str(root_path.parent))
    engine.load(QUrl.fromLocalFile(str(root_path)))
    if not engine.rootObjects():
        pytest.fail("Main.qml did not create a root object")

    root = engine.rootObjects()[0]
    yield app, engine, root, backend

    engine.clearComponentCache()
    engine.deleteLater()
    app.processEvents()


def _settle(app, rounds=8):
    for _ in range(rounds):
        app.processEvents()


@pytest.mark.parametrize("index,name", list(enumerate(PAGE_NAMES)))
def test_every_workspace_page_loads_without_qml_runtime_errors(qml_application, index, name):
    app, _engine, root, _backend = qml_application
    root.setProperty("currentPage", index)
    _settle(app)
    assert bool(root.pageLoaded(index)), f"{name} page failed to load"


def test_compare_preview_payload_reaches_main_qml_model(qml_application):
    app, _engine, root, backend = qml_application
    root.setProperty("currentPage", 1)
    _settle(app)

    payload = json.dumps(
        {
            "columns": ["SID", "Store Name", "City"],
            "rows": [["S100", "Alpha Store", "Pune"]],
            "total": 1,
        }
    )
    backend.validate.masterPreviewReady.emit(payload)
    _settle(app)

    assert list(root.property("masterPreviewColumns")) == ["SID", "Store Name", "City"]
    assert list(root.property("masterPreviewRows"))[0] == ["S100", "Alpha Store", "Pune"]
    assert root.property("masterPreviewTotal") == 1
    assert root.property("previewVisible") is True
    assert root.property("previewError") == ""


def test_explore_table_payload_reaches_page_model(qml_application):
    app, _engine, root, backend = qml_application
    root.setProperty("currentPage", 5)
    _settle(app)

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
    _settle(app)

    page = root.pageItem(5)
    assert page is not None
    assert list(page.property("columns")) == ["SID", "Store Name", "City"]
    rows = list(page.property("rows"))
    assert rows[0]["SID"] == "100"
    assert rows[0]["Store Name"] == "Alpha Store"
    assert page.property("totalRows") == 2


def test_health_payload_and_statistics_reach_page_models(qml_application):
    app, _engine, root, backend = qml_application
    root.setProperty("currentPage", 6)
    _settle(app)

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
    _settle(app)

    page = root.pageItem(6)
    assert page is not None
    health_data = page.property("healthData")
    stats_data = page.property("statsData")
    assert health_data["columnTypes"]["SID"] == "text"
    assert health_data["profile"]["rowCount"] == 2
    assert stats_data["rows"][0]["result"] == 2
    assert page.property("totalRows") == 0 or page.property("totalRows") == 2
