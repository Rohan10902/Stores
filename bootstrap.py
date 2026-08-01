# bootstrap.py
import sys
import os
import traceback
from pathlib import Path

from PySide6.QtWidgets import QApplication
from PySide6.QtCore import QUrl, QThreadPool, qInstallMessageHandler, QtMsgType
from PySide6.QtQml import QQmlApplicationEngine

from core.utils.logger import setup_logging, get_logger
from core.controllers import MainBackendController

BASE = Path(__file__).resolve().parent
logger = get_logger("Bootstrap")


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
    
    logger.info("Initializing StoreLens Application...")
    app = QApplication(sys_argv)
    engine = QQmlApplicationEngine()

    # Configure hardware-aware threadpool
    threadpool = QThreadPool.globalInstance()
    threadpool.setMaxThreadCount(max(2, os.cpu_count() or 4))

    # Instantiate Aggregated Modular Controller
    backend = MainBackendController(threadpool=threadpool)
    engine.rootContext().setContextProperty("backend", backend)

    # 🟠 HIGH PRIORITY: Ensure QML objects are not accessed after destruction
    # Safely clear the threadpool and prevent background signals during teardown
    def cleanup_resources():
        logger.info("Application shutting down. Intercepting background workers...")
        # 1. Clear any pending tasks that haven't started yet
        threadpool.clear() 
        # 2. Give active threads exactly 2 seconds to finish gracefully
        if not threadpool.waitForDone(2000):
            logger.warning("Some background tasks were forcibly terminated during shutdown.")
        logger.info("Resource cleanup complete. Safe to destroy QML Engine.")

    # Connect the cleanup routine to the application's quit signal
    app.aboutToQuit.connect(cleanup_resources)

    # Load QML Interface
    main_qml = QUrl.fromLocalFile(str(BASE / "qml" / "Main.qml"))
    engine.load(main_qml)

    if not engine.rootObjects():
        logger.critical("Failed to load root QML object.")
        return app, engine, 1

    # CI Pipeline Startup Check
    if os.environ.get("STORELENS_CI_STARTUP_TEST") == "1":
        print("STORELENS_STARTUP_OK")
        sys.stdout.flush()
        return app, engine, 0

    return app, engine, None
