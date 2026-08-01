# core/utils/logger.py
import logging
import sys


def setup_logging(level: int = logging.INFO) -> logging.Logger:
    logger = logging.getLogger("StoreLens")
    logger.setLevel(level)

    if not logger.handlers:
        formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] [%(name)s.%(funcName)s:%(lineno)d] - %(message)s'
        )
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    return logger


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(f"StoreLens.{name}")
