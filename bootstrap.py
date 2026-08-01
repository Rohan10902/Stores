# bootstrap.py
import sys
import os
import traceback
import logging
from pathlib import Path

from PySide6.QtWidgets import QApplication
from PySide6.QtCore import QUrl, QThreadPool, qInstallMessageHandler, QtMsgType
from PySide6.QtQml import QQmlApplicationEngine

from core.utils.logger import setup_logging, get_logger
from core.controllers import MainBackendController

# Handle path resolution correctly for compiled executables vs script execution
if getattr(sys, 'frozen', False):
    BASE = Path(sys.executable).resolve().parent
else:
    BASE = Path(__file__).resolve().parent

logger = get_logger("Bootstrap")

logging.basicConfig(
    filename='startup_debug.log',
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

def setup_exception_traps():
    def global_exception_trap(exctype, value, tb):
        err_text = "".join(traceback.format_exception(exctype, value, tb))
        logger.critical(f"[CRITICAL EXCEPTION PREVENTED]:\n{err_text}")
        sys.stdout.flush()

    def qt_message_trap(mode, context, message):
        if mode == QtMsgType.QtFatalMsg:
            logger.critical(f"[QT FATAL SUPPRESSED]: {message}")
        elif mode == QtMsgType.QtCriticalMsg:
            logger.error(f"[QT CRITICAL]: {message}")
        sys.stdout.flush()

    sys.excepthook = global_exception_trap
    qInstallMessageHandler(qt_message_trap)


def create_application(sys_argv):
    setup_logging()
    setup_exception_traps()
    
    logger.info("CHECKPOINT 1: Starting application initialization...")
    app = QApplication(sys_argv)
    engine = QQmlApplicationEngine()

    # Configure hardware-aware threadpool
    threadpool = QThreadPool.globalInstance()
    threadpool.setMaxThreadCount(max(2, os.cpu_count() or 4))

    logger.info("CHECKPOINT 2: Setting up QML engine and controllers...")
    backend = MainBackendController(threadpool=threadpool)
    engine.rootContext().setContextProperty("backend", backend)

    def cleanup_resources():
        logger.info("Application shutting down. Intercepting background workers...")
        threadpool.clear() 
        if not threadpool.waitForDone(2000):
            logger.warning("Some background tasks were forcibly terminated during shutdown.")
        logger.info("Resource cleanup complete. Safe to destroy QML Engine.")

    app.aboutToQuit.connect(cleanup_resources)

    logger.info("CHECKPOINT 3: Loading Main.qml...")
    
    # Robust multi-path search for Main.qml across build layouts
    possible_paths = [
        BASE / "qml" / "Main.qml",
        BASE / "_internal" / "qml" / "Main.qml",
        Path(sys.executable).resolve().parent / "qml" / "Main.qml" if getattr(sys, 'frozen', False) else None,
        Path(sys.executable).resolve().parent / "_internal" / "qml" / "Main.qml" if getattr(sys, 'frozen', False) else None,
    ]
    
    main_qml = next((p for p in possible_paths if p and p.exists()), None)
    
    if not main_qml:
        logger.critical(f"CRITICAL: Main.qml not found in any expected paths. Checked: {[str(p) for p in possible_paths if p]}")
        return app, engine, 1
        
    logger.info(f"Loading QML file from verified path: {main_qml}")
    engine.load(QUrl.fromLocalFile(str(main_qml)))

    if not engine.rootObjects():
        logger.critical("CRITICAL: Failed to load Main.qml root object. Check for QML syntax errors or missing module imports.")
        return app, engine, 1

    if os.environ.get("STORELENS_CI_STARTUP_TEST") == "1":
        print("STORELENS_STARTUP_OK")
        sys.stdout.flush()
        return app, engine, 0

    return app, engine, None


def main():
    app, engine, exit_code = create_application(sys.argv)
    
    if exit_code is not None:
        sys.exit(exit_code)
        
    logger.info("CHECKPOINT 4: Entering main event loop (app.exec())...")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
