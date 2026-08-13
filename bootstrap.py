import sys
import os
import traceback
from pathlib import Path

from PySide6.QtWidgets import QApplication
from PySide6.QtCore import QUrl, QThreadPool, qInstallMessageHandler, QtMsgType
from PySide6.QtQml import QQmlApplicationEngine

from core.utils.logger import setup_logging, get_logger, log_directory
from core.controllers import MainBackendController

if getattr(sys, "frozen", False):
    BASE = Path(sys.executable).resolve().parent
else:
    BASE = Path(__file__).resolve().parent

logger = get_logger("Bootstrap")


def _startup_marker_path() -> Path:
    configured = os.environ.get("STORELENS_STARTUP_MARKER", "").strip()
    if configured:
        return Path(configured)
    return log_directory() / "startup.marker"


def _write_startup_marker() -> None:
    marker = _startup_marker_path()
    try:
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text("STORELENS_STARTUP_OK\n", encoding="utf-8")
    except OSError as exc:
        logger.error("Unable to write startup marker: %s", exc)
    if sys.stdout is not None:
        print("STORELENS_STARTUP_OK", flush=True)


def setup_exception_traps():
    def global_exception_trap(exctype, value, tb):
        err_text = "".join(traceback.format_exception(exctype, value, tb))
        logger.critical("[UNHANDLED EXCEPTION]:\n%s", err_text)
        if sys.stdout is not None:
            sys.stdout.flush()

    def qt_message_trap(mode, context, message):
        if mode == QtMsgType.QtFatalMsg:
            logger.critical("[QT FATAL]: %s", message)
        elif mode == QtMsgType.QtCriticalMsg:
            logger.error("[QT CRITICAL]: %s", message)
        if sys.stdout is not None:
            sys.stdout.flush()

    sys.excepthook = global_exception_trap
    qInstallMessageHandler(qt_message_trap)


def create_application(sys_argv):
    setup_logging()
    setup_exception_traps()
    marker = _startup_marker_path()
    try:
        marker.unlink(missing_ok=True)
    except OSError:
        pass

    logger.info("Starting StoreLens initialization")
    app = QApplication(sys_argv)
    engine = QQmlApplicationEngine()

    def handle_qml_warnings(warnings):
        for warning in warnings:
            url = warning.url().toLocalFile() if hasattr(warning.url(), "toLocalFile") else warning.url().toString()
            message = f"QML: {url}:{warning.line()}:{warning.column()} - {warning.description()}"
            logger.error(message)
            if sys.stderr is not None:
                print(message, file=sys.stderr, flush=True)

    engine.warnings.connect(handle_qml_warnings)

    threadpool = QThreadPool.globalInstance()
    threadpool.setMaxThreadCount(max(2, os.cpu_count() or 4))
    backend = MainBackendController(threadpool=threadpool)
    engine.rootContext().setContextProperty("backend", backend)

    def cleanup_resources():
        logger.info("Application shutting down; waiting for background workers")
        threadpool.clear()
        if not threadpool.waitForDone(3000):
            logger.warning("Background workers did not finish within shutdown grace period")

    app.aboutToQuit.connect(cleanup_resources)

    possible_paths = [
        BASE / "qml" / "Main.qml",
        BASE / "_internal" / "qml" / "Main.qml",
        Path(sys.executable).resolve().parent / "qml" / "Main.qml" if getattr(sys, "frozen", False) else None,
        Path(sys.executable).resolve().parent / "_internal" / "qml" / "Main.qml" if getattr(sys, "frozen", False) else None,
    ]
    main_qml = next((path for path in possible_paths if path and path.exists()), None)
    if not main_qml:
        logger.critical("Main.qml not found. Checked: %s", [str(path) for path in possible_paths if path])
        return app, engine, 1

    engine.addImportPath(str(main_qml.parent))
    logger.info("Loading Main.qml from %s", main_qml)
    engine.load(QUrl.fromLocalFile(str(main_qml)))

    if not engine.rootObjects():
        logger.critical("Main.qml failed to create a root object")
        return app, engine, 1

    if os.environ.get("STORELENS_CI_STARTUP_TEST") == "1":
        app.processEvents()
        _write_startup_marker()
        return app, engine, 0

    return app, engine, None


def main():
    app, engine, exit_code = create_application(sys.argv)
    if exit_code is not None:
        sys.exit(exit_code)
    logger.info("Entering Qt event loop")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
