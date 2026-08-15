"""QML feature acceptance checks that are safe on the Windows CI runner.

Qt Quick Controls can terminate the Python process with a native access
violation when individual pages are instantiated without a real top-level
window on the Windows hosted runner. QML syntax/semantic validation is already
performed by qmllint in CI, while application-level startup is covered by the
startup smoke test. These checks therefore validate the workspace contract
without constructing native Qt Quick objects in pytest.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
QML_DIR = ROOT / "qml"
MAIN_QML = QML_DIR / "Main.qml"

PAGE_FILES = [
    "HomePage.qml",
    "ComparePage.qml",
    "RepairPage.qml",
    "SingleReviewPage.qml",
    "CreateStorePage.qml",
    "ExplorePage.qml",
    "HealthPage.qml",
]

PAGE_EXPECTATIONS = {
    "HomePage.qml": [
        "Dashboard",
        "Compare & Validate",
        "Review One File",
        "Repair CSV / Text",
        "Create Store File",
    ],
    "ComparePage.qml": [
        "backend.validate.validate",
        "backend.validate.detail",
        "backend.validate.load_master",
        "backend.validate.load_upload",
    ],
    "RepairPage.qml": [
        "backend.repair.inspect_repair",
        "backend.repair.repair",
        "backend.repair.create_repair_record",
    ],
    "SingleReviewPage.qml": [
        "backend.review.review_single_file",
        "backend.review.export_single_review",
    ],
    "CreateStorePage.qml": [
        "backend.creator.validate_creator",
        "backend.creator.export_builder_file",
        "backend.creator.load_creator_file",
        "backend.creator.load_creator_text",
    ],
    "ExplorePage.qml": [
        "backend.health.load_data",
        "backend.health.search",
        "backend.health.sql",
    ],
    "HealthPage.qml": [
        "backend.health.load_data",
        "backend.health.stats",
        "backend.health.export_health_report",
    ],
}


@pytest.mark.parametrize("page_file", PAGE_FILES)
def test_workspace_page_exists_and_has_expected_contract(page_file):
    page = QML_DIR / "pages" / page_file
    assert page.is_file(), f"Missing workspace page: {page_file}"
    text = page.read_text(encoding="utf-8")
    for expected in PAGE_EXPECTATIONS[page_file]:
        assert expected in text, f"{page_file} is missing expected contract: {expected}"


def test_main_maps_every_workspace_page():
    main_text = MAIN_QML.read_text(encoding="utf-8")
    for page_file in PAGE_FILES:
        assert f'source: "pages/{page_file}"' in main_text, f"Main.qml is missing {page_file}"


def test_main_has_backend_and_workspace_navigation_contract():
    text = MAIN_QML.read_text(encoding="utf-8")
    assert "contextProperty(\"backend\"" not in text
    assert "StackLayout" in text
    assert "Loader" in text
    for page_id in ["home", "compare", "repair", "review", "create", "explore", "health"]:
        assert page_id in text


def test_pages_use_theme_and_shared_components():
    for page_file in PAGE_FILES:
        text = (QML_DIR / "pages" / page_file).read_text(encoding="utf-8")
        assert '"../components"' in text or '"../theme"' in text, f"{page_file} bypasses shared UI infrastructure"


def test_qml_files_have_balanced_basic_braces():
    files = list(QML_DIR.rglob("*.qml"))
    assert files, "No QML files found"
    for path in files:
        text = re.sub(r'//.*', '', path.read_text(encoding="utf-8"))
        assert text.count("{") == text.count("}"), f"Unbalanced braces in {path.relative_to(ROOT)}"


def test_store_builder_source_preview_uses_real_rows_not_numeric_repeater_model():
    text = (QML_DIR / "pages" / "CreateStorePage.qml").read_text(encoding="utf-8")
    assert "model: root.importedRows.slice(0, root.previewRowCount)" in text
    assert "model: Math.min(root.previewRowCount, root.importedRows.length)" not in text
    assert "readonly property var previewRow: modelData" in text


def test_repair_qml_mapping_call_has_matching_controller_slot():
    qml = (QML_DIR / "pages" / "RepairPage.qml").read_text(encoding="utf-8")
    controller = (ROOT / "core" / "controllers" / "repair_controller.py").read_text(encoding="utf-8")
    assert "backend.repair.map_repair_column" in qml
    assert "def map_repair_column(" in controller
    assert "@Slot(int, int, int)" in controller


def test_health_ui_statistics_have_backend_compatible_operation_contract():
    qml = (QML_DIR / "pages" / "HealthPage.qml").read_text(encoding="utf-8")
    health = (ROOT / "core" / "health.py").read_text(encoding="utf-8")
    assert '"unique"' in qml
    assert 'if operation == "unique":' in health
    assert 'operation = "nunique"' in health


def test_backend_data_preview_contracts_preserve_actual_row_values():
    explore = (QML_DIR / "pages" / "ExplorePage.qml").read_text(encoding="utf-8")
    health = (QML_DIR / "pages" / "HealthPage.qml").read_text(encoding="utf-8")
    review = (QML_DIR / "pages" / "SingleReviewPage.qml").read_text(encoding="utf-8")
    assert "root.rowValue(rowDelegate.rowData" in explore
    assert "root.rowValue(rowDelegate.rowData" in health
    assert "root.cellValue(rowDelegate.rowData" in review


def test_no_known_stale_repair_mapping_api_remains_in_controller_contract():
    controller = (ROOT / "core" / "controllers" / "repair_controller.py").read_text(encoding="utf-8")
    assert "def apply_repair_mapping(" in controller
    assert "def map_repair_column(" in controller
    assert "self.apply_repair_mapping(int(issue_index), int(col_index), target, False)" in controller


def test_explore_controls_keep_storelens_dark_theme_and_sql_is_not_auto_inserted():
    text = (QML_DIR / "pages" / "ExplorePage.qml").read_text(encoding="utf-8")
    assert 'property string sqlText: ""' in text
    assert 'placeholderText: "Enter SQL query..."' in text
    assert 'text: "Use Example"' in text
    assert 'text: "Example: SELECT * FROM data LIMIT 100"' in text
    assert 'background: Rectangle {' in text
    assert 'color: Theme.background' in text
    assert 'color: "white"' not in text
