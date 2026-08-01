# core/mapping_store.py
import json
import os
from core.utils.logger import get_logger

logger = get_logger("MappingStore")

def load_mappings(file_path: str) -> dict:
    """
    Safely loads saved column mapping profiles from disk.
    """
    if not file_path or not os.path.exists(file_path):
        return {}

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        logger.warning(f"Mapping file not found at {file_path}. Returning empty mappings.")
        return {}
    except json.JSONDecodeError as jde:
        logger.error(f"Mapping file is corrupted or malformed JSON: {jde}")
        return {}
    except OSError as oe:
        logger.error(f"OS error reading mapping file {file_path}: {oe}")
        return {}
    except Exception as e:
        # Final boundary catch with full traceback logging
        logger.exception(f"Unexpected error loading mappings from {file_path}")
        return {}

def save_mappings(file_path: str, data: dict) -> bool:
    """
    Safely saves column mapping profiles to disk.
    """
    if not file_path:
        return False

    try:
        target_dir = os.path.dirname(file_path)
        if target_dir and not os.path.exists(target_dir):
            os.makedirs(target_dir, exist_ok=True)

        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)
        return True
        
    except (OSError, TypeError, ValueError) as err:
        logger.error(f"Failed to save mappings to {file_path}: {err}")
        return False
    except Exception as e:
        logger.exception(f"Unexpected error saving mappings to {file_path}")
        return False
