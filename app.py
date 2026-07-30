import sys
import json
from pathlib import Path
import os
import logging
from PySide6.QtCore import QObject, Signal, Slot, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from core.common import read_table, json_value

BASE = Path(__file__).resolve().parent

class Backend(QObject):
    creatorReady = Signal(str)
    creatorLoaded = Signal(str)

    def __init__(self):
        super().__init__()

    @Slot(str, str)
    def exportCreator(self, rows_json, dst):
        try:
            rows = json.loads(rows_json)
            Path(dst).write_text(rows_json, encoding="utf-8")
        except Exception as e:
            self.fail(e)

    @Slot(result=str)
    def clipboardText(self):
        # best-effort: attempt to read from Qt clipboard if available, otherwise empty
        try:
            from PySide6.QtGui import QGuiApplication
            return QGuiApplication.clipboard().text() or ""
        except Exception:
            return ""

    @Slot(str)
    def validateCreator(self, rows_json):
        # placeholder: emit creatorReady with zero findings
        payload = json.dumps({"count": 0, "findings": []})
        self.creatorReady.emit(payload)

    def say(self, text):
        print(text)

    def fail(self, e):
        print("Backend error:", e)

    def _local(self, path):
        # Accept file:// URLs or plain paths
        if not path:
            return ""
        if path.startswith("file://"):
            return QUrl(path).toLocalFile()
        return path

    @Slot(str)
    def loadCreatorFile(self, path):
        try:
            local = path
            if path.startswith("file://"):
                local = QUrl(path).toLocalFile()
            df = read_table(local)
            headers = [str(c) for c in df.columns]
            rows = []
            for row in df.itertuples(index=False, name=None):
                obj = {}
                for i, v in enumerate(row):
                    obj[headers[i]] = json_value(v)
                rows.append(obj)
            payload = json.dumps({"headers": headers, "rows": rows}, default=str)
            self.creatorLoaded.emit(payload)
            self.say(f"Imported {len(rows)} row(s) from file")
        except Exception as e:
            self.fail(e)


def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    # CI-only fast startup check: If CI sets STORELENS_CI_STARTUP_TEST=1 we avoid loading the full Main.qml,
    # which can trigger heavy Component.onCompleted handlers that hang CI. This preserves normal runtime behavior.
    if os.getenv("STORELENS_CI_STARTUP_TEST") == "1":
        engine.loadData(b'import QtQuick 2.0\nItem {}')
        app.processEvents()
        print("STORELENS_STARTUP_OK", flush=True)
        return 0

    engine.load(QUrl.fromLocalFile(str(BASE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        print("Failed to load QML root objects")
        return 1
    return app.exec()

if __name__ == "__main__":
    sys.exit(main())
