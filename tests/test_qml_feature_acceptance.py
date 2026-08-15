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

# These are deliberately stable source-level contracts: the pages must expose
# their core user workflow and call the real backend controller. We do not
# assert implementation-specific signal handler spellings here because QML
# signal connections may be expressed through Connections handlers without the
# raw signal name appearing in the page source.
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
    assert "contextProperty(\"backend\"" not in text  # backend is injected by bootstrap, not QML
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
