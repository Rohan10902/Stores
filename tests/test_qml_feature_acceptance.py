"""Headless Qt/QML acceptance checks for StoreLens workspace pages.

The tests deliberately instantiate the individual workspace pages rather than
Main.qml. Main.qml is an ApplicationWindow and forces Qt's window/rendering
lifecycle into a test that only needs to validate page construction and data
binding. On Windows CI that can terminate the Qt process without a Python
exception. The page-level harness still exercises the real QML files, the real
backend QObject properties, and the real controller signals.
"""

from __future__ import annotations

# Qt reads these before the first QGuiApplication is created. Keep them at
# module import time so the same settings are used in both pytest phases.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_OPENGL", "software")

import json
import os
from pathlib import Path

import pytest
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

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
PAGE_FILES = [
    "HomePage.qml",
    "ComparePage.qml",
    "RepairPage.qml",
    "SingleReviewPage.qml",
    "CreateStorePage.qml",
    "ExplorePage.qml",
    "HealthPage.qml",
]


@pytest.fixture(scope="session")
def qml_runtime():
    """Create one non-windowed Qt/QML runtime for the complete acceptance run."""
    app = QGuiApplication.instance() or QGuiApplication([])
    engine = QQmlEngine()
    backend = MainBackendController()
    engine.rootContext().setContextProperty("backend", backend)
    engine.addImportPath(str(Path(__file__).resolve().parents[1] / "qml"))
    yield app, engine, backend
    engine.clearComponentCache()
    engine.deleteLater()
    app.processEvents()


def _load_page(qml_runtime, index):
    """Instantiate one real workspace page without creating a top-level window."""
    app, engine, _backend = qml_runtime
    qml_dir = Path(__file__).resolve().parents[1] / "qml" / "pages"
    source = qml_dir / PAGE_FILES[index]
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(source)))
    if component.status() == QQmlComponent.Error:
        errors = "\n".join(error.toString() for error in component.errors())
        pytest.fail(f"{PAGE_NAMES[index]} failed QML component compilation:\n{errors}")
    item = component.create()
    if item is None:
        errors = "\n".join(error.toString() for error in component.errors())
        pytest.fail(f"{PAGE_NAMES[index]} failed QML object creation:\n{errors}")
    app.processEvents()
    return component, item


def _delete_item(qml_runtime, item):
    app = qml_runtime[0]
    item.deleteLater()
    app.processEvents()


@pytest.mark.parametrize("index,name", list(enumerate(PAGE_NAMES)))
def test_every_workspace_page_loads_without_qml_runtime_errors(qml_runtime, index, name):
    _component, page = _load_page(qml_runtime, index)
    try:
        assert page is not None, f"{name} page has no QML object"
    finally:
        _delete_item(qml_runtime, page)


def test_compare_page_consumes_validation_and_detail_payloads(qml_runtime):
    _app, _engine, backend = qml_runtime
    _component, page = _load_page(qml_runtime, 1)
    try:
        validation = {
            "total": 2,
            "correct": 1,
            "review": 1,
            "errors": 0,
            "attention": 1,
            "rows": [
                {"row": 1, "key": "s100 | n100", "status": "CORRECT", "message": "Match"},
                {"row": 2, "key": "s200 | n200", "status": "REVIEW", "message": "Store Name differs"},
            ],
            "insights": [
                {"key": "REVIEW", "title": "Review", "count": 1, "severity": "WARNING", "action": "Inspect"}
            ],
        }
        backend.validate.validationReady.emit(json.dumps(validation))
        _app.processEvents()
        assert page.property("total") == 2
        rows = list(page.property("resultRows"))
        assert rows[1]["keyVal"] == "s200 | n200"
        assert rows[1]["statusVal"] == "REVIEW"
        assert list(page.property("insightRows"))[0]["count"] == "1"

        detail = {
            "status": "REVIEW",
            "message": "Store Name differs",
            "comparisons": [
                {"field": "Store Name", "master": "Alpha", "uploaded": "Alpha Updated", "result": "DIFF", "severity": "WARNING"}
            ],
        }
        backend.validate.detailReady.emit(json.dumps(detail))
        _app.processEvents()
        assert page.property("detailStatus") == "REVIEW"
        assert list(page.property("detailRows"))[0]["uploadedValue"] == "Alpha Updated"
    finally:
        _delete_item(qml_runtime, page)


def test_repair_page_consumes_real_inspection_payload(qml_runtime):
    _app, _engine, backend = qml_runtime
    _component, page = _load_page(qml_runtime, 2)
    try:
        payload = {
            "headers": ["SID", "Store Name", "City"],
            "rows": [["S1", "Alpha", "Pune"], ["S2", "Beta", ""]],
            "issues": [{"index": 0, "row": 2, "type": "Missing Field", "message": "Expected 3 fields."}],
            "history": 0,
        }
        backend.repair.repairReady.emit(json.dumps(payload))
        _app.processEvents()
        assert list(page.property("headers")) == ["SID", "Store Name", "City"]
        assert list(page.property("rows"))[1][1] == "Beta"
        assert list(page.property("issues"))[0]["type"] == "Missing Field"
        assert page.property("hasData") is True
    finally:
        _delete_item(qml_runtime, page)


def test_single_review_page_consumes_preview_payload(qml_runtime):
    _app, _engine, backend = qml_runtime
    _component, page = _load_page(qml_runtime, 3)
    try:
        payload = {
            "totalRecords": 2,
            "attentionCount": 1,
            "previewColumns": ["SID", "Store Name"],
            "previewRows": [["S1", "Alpha"], ["S2", "Beta"]],
            "findings": [{"message": "Missing value", "severity": "WARNING"}],
        }
        backend.review.singleReviewReady.emit(json.dumps(payload))
        _app.processEvents()
        assert page.property("totalRecords") == 2
        assert list(page.property("previewColumns")) == ["SID", "Store Name"]
        assert list(page.property("previewRows"))[1][1] == "Beta"
        assert list(page.property("findings"))[0]["severity"] == "WARNING"
    finally:
        _delete_item(qml_runtime, page)


def test_store_builder_page_consumes_import_and_validation_payloads(qml_runtime):
    _app, _engine, backend = qml_runtime
    _component, page = _load_page(qml_runtime, 4)
    try:
        imported = {
            "headers": ["Store Name", "SID", "Nielsen Store Code"],
            "rows": [["Alpha Store", "S100", "N100"]],
            "total": 1,
        }
        backend.creatorLoaded.emit(json.dumps(imported))
        _app.processEvents()
        assert list(page.property("importedHeaders")) == imported["headers"]
        assert list(page.property("importedRows"))[0][1] == "S100"
        assert page.property("importedTotal") == 1
        assert page.property("importPreviewVisible") is True

        ready = {"findings": []}
        backend.creatorReady.emit(json.dumps(ready))
        _app.processEvents()
        assert page.property("validated") is True
        assert list(page.property("findings")) == []
    finally:
        _delete_item(qml_runtime, page)


def test_explore_page_consumes_table_payload(qml_runtime):
    _app, _engine, backend = qml_runtime
    _component, page = _load_page(qml_runtime, 5)
    try:
        payload = {
            "columns": ["SID", "Store Name", "City"],
            "rows": [
                {"SID": "100", "Store Name": "Alpha Store", "City": "Pune"},
                {"SID": "200", "Store Name": "Beta Store", "City": "Mumbai"},
            ],
            "total": 2,
            "displayed": 2,
            "truncated": False,
        }
        backend.health.tableReady.emit(json.dumps(payload))
        _app.processEvents()
        assert list(page.property("columns")) == payload["columns"]
        rows = list(page.property("rows"))
        assert rows[0]["SID"] == "100"
        assert rows[1]["Store Name"] == "Beta Store"
        assert page.property("totalRows") == 2
        assert page.property("displayedRows") == 2
        assert page.property("truncated") is False
    finally:
        _delete_item(qml_runtime, page)


def test_health_page_consumes_health_statistics_and_table_payloads(qml_runtime):
    _app, _engine, backend = qml_runtime
    _component, page = _load_page(qml_runtime, 6)
    try:
        table = {"columns": ["SID", "City"], "rows": [{"SID": "S1", "City": "Pune"}], "total": 1, "displayed": 1, "truncated": False}
        health = {
            "rows": 1,
            "columns": 2,
            "completeness": 100,
            "duplicateRows": 0,
            "score": 100,
            "columnNames": ["SID", "City"],
            "columnTypes": {"SID": "text", "City": "text"},
            "columnStats": [{"column": "SID", "type": "text", "blank": 0, "unique": 1, "nonBlank": 1}],
            "profile": {"rowCount": 1, "columnCount": 2},
        }
        stats = {"column": "City", "operation": "count", "rows": [{"label": "count — City", "result": 1}], "insight": "count calculated for City."}
        backend.health.tableReady.emit(json.dumps(table))
        backend.health.healthReady.emit(json.dumps(health))
        backend.health.statsReady.emit(json.dumps(stats))
        _app.processEvents()
        assert page.property("totalRows") == 1
        assert page.property("healthData")["profile"]["rowCount"] == 1
        assert page.property("statsData")["rows"][0]["result"] == 1
        assert page.property("selectedColumn") == "SID"
    finally:
        _delete_item(qml_runtime, page)


def test_qml_page_map_matches_main_workspace_contract():
    main_text = (Path(__file__).resolve().parents[1] / "qml" / "Main.qml").read_text(encoding="utf-8")
    for page_file in PAGE_FILES:
        assert f'source: "pages/{page_file}"' in main_text, f"Main.qml is missing {page_file}"
