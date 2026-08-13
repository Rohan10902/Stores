# core/store_import.py
import os

from core.common import read_table
from core.utils.logger import get_logger

logger = get_logger("StoreImport")


def import_stores(file_path: str) -> list:
    if not file_path or not os.path.exists(file_path):
        raise FileNotFoundError(f"Import file not found: {file_path}")
    try:
        df = read_table(file_path)
        if df.empty:
            return []
        return df.to_dict(orient="records")
    except FileNotFoundError:
        raise
    except Exception as exc:
        logger.exception("Failed to import stores")
        raise ValueError(f"The import file could not be read safely: {exc}") from exc
