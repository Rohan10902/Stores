# core/utils/logger.py
import logging
import sys
from typing import Optional


def setup_logging(level: int = logging.INFO) -> logging.Logger:
    """Configures structured logging across the application."""
    logger = logging.getLogger("StoreApp")
    logger.setLevel(level)

    if not logger.handlers:
        formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] [%(name)s.%(funcName)s:%(lineno)d] - %(message)s'
        )
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

    return logger


def get_logger(module_name: str) -> logging.Logger:
    """Returns a logger instance scoped to a specific module."""
    return logging.getLogger(f"StoreApp.{module_name}")
