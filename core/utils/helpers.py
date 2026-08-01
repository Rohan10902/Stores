# core/utils/helpers.py
import gc


def local_path(path: str) -> str:
    """Normalizes file URLs from QML (file:// / file:///) to local paths."""
    if not path:
        return ""
    p = str(path).strip()
    if p.startswith("file:///"):
        return p[8:]
    elif p.startswith("file://"):
        return p[7:]
    return p


def free_memory():
    """Forces Python garbage collection to release unreferenced DataFrames."""
    gc.collect()
