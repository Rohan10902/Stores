# core/mapping_store.py
import json
import os
from core.utils.logger import get_logger

logger = get_logger("MappingStore")

def load_mappings(file_path: str) -> dict:
    if not file_path or not os.path.exists(file_path):
        return {}

    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_mappings(file_path: str, data: dict) -> bool:
    if not file_path:
        return False

    target_dir = os.path.dirname(file_path)
    if target_dir and not os.path.exists(target_dir):
        os.makedirs(target_dir, exist_ok=True)

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4)
    return True
