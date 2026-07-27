import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from app import Backend

TARGETS = [
    "qml/components/AppButton.qml",
    "qml/components/PrimaryButton.qml",
    "qml/components/Card.qml",
    "qml/components/PageTitle.qml",
    "qml/pages/HomePage.qml",
    "qml/pages/ComparePage.qml",
    "qml/pages/SingleReviewPage.qml",
    "qml/pages/RepairPage.qml",
    "qml/pages/CreateStorePage.qml",
    "qml/pages/HealthPage.qml",
    "qml/pages/ExplorePage.qml",
    "qml/Main.qml",
]


def errors(component):
    return "\n".join(e.toString() for e in component.errors())


def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlEngine()
    engine.addImportPath(str(ROOT / "qml"))
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    failed = []
    live_objects = []

    for rel in TARGETS:
        component = QQmlComponent(engine)
        component.loadUrl(QUrl.fromLocalFile(str(ROOT / rel)))
        if component.isError():
            detail = errors(component) or "QML component load failed"
            failed.append((rel, detail))
            print(f"FAIL {rel}\n{detail}", flush=True)
            continue

        obj = component.create()
        if obj is None:
            detail = errors(component) or "component.create() returned None"
            failed.append((rel, detail))
            print(f"FAIL {rel}\n{detail}", flush=True)
            continue

        live_objects.append(obj)
        app.processEvents()
        runtime_errors = errors(component)
        if runtime_errors:
            failed.append((rel, runtime_errors))
            print(f"FAIL {rel}\n{runtime_errors}", flush=True)
        else:
            print(f"PASS {rel}", flush=True)

    for obj in reversed(live_objects):
        obj.deleteLater()
    app.processEvents()

    if failed:
        print("\n===== QML RUNTIME FAILURE SUMMARY =====", flush=True)
        for rel, detail in failed:
            print(f"\n{rel}\n{detail}", flush=True)
        print(f"\n{len(failed)} QML runtime component(s) failed.", flush=True)
        return 1

    print("\nAll QML runtime components instantiated successfully using the real Backend contract.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
