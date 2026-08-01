# bootstrap.py
import sys
from typing import Tuple
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from core.utils.logger import setup_logging
from core.controllers.import_controller import ImportController
from core.controllers.repair_controller import RepairController


def create_application(sys_argv: list) -> Tuple[QGuiApplication, QQmlApplicationEngine]:
    """Initializes logging, Qt application, controllers, and QML engine."""
    logger = setup_logging()
    logger.info("Bootstrapping Application Engine...")

    app = QGuiApplication(sys_argv)
    engine = QQmlApplicationEngine()

    # Initialize Backend Controllers
    import_controller = ImportController()
    repair_controller = RepairController()

    # Connect Controller Cross-Talk
    import_controller.importCompleted.connect(
        lambda: repair_controller.load_dataset(
            import_controller.table_model._headers,
            import_controller.table_model._rows
        )
    )

    # Expose Controllers & Models to QML Context
    context = engine.rootContext()
    context.setContextProperty("importController", import_controller)
    context.setContextProperty("repairController", repair_controller)
    context.setContextProperty("storeTableModel", import_controller.table_model)

    # Load Root QML View
    qml_path = QUrl.fromLocalFile("qml/Main.qml")
    engine.load(qml_path)

    if not engine.rootObjects():
        logger.critical("Failed to load primary QML interface module.")
        sys.exit(-1)

    logger.info("Application bootstrap complete.")
    return app, engine
