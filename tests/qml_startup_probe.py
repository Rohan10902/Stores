import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

ROOT = Path(__file__).resolve().parents[1]
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

class DummyBackend(QObject):
    @Property(str, constant=True)
    def message(self):
        return "CI probe"


def errors(component):
    return "\n".join(e.toString() for e in component.errors())


def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlEngine()
    engine.addImportPath(str(ROOT / "qml"))
    backend = DummyBackend()
    engine.rootContext().setContextProperty("backend", backend)
    failed = []
    for rel in TARGETS:
        path = ROOT / rel
        component = QQmlComponent(engine)
        component.loadUrl(QUrl.fromLocalFile(str(path)))
        if component.isError():
            failed.append((rel, errors(component)))
            print(f"FAIL {rel}\n{errors(component)}", flush=True)
            continue
        obj = component.create()
        if obj is None:
            failed.append((rel, errors(component) or "component.create() returned None"))
            print(f"FAIL {rel}\n{failed[-1][1]}", flush=True)
            continue
        print(f"PASS {rel}", flush=True)
        obj.deleteLater()
        app.processEvents()
    if failed:
        print(f"\n{len(failed)} QML runtime component(s) failed.", flush=True)
        return 1
    print("\nAll QML runtime components instantiated successfully.", flush=True)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
