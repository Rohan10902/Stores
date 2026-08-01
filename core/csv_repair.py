import os
import csv
from core.utils.logger import get_logger

logger = get_logger("CSVRepair")

def save_repaired(audit: dict, dst_path: str) -> None:
    """
    Exports the repaired records to a new CSV file.
    Includes defensive directory checks and write-permission validation.
    """
    if not audit or 'headers' not in audit or 'rows' not in audit:
        raise ValueError("Audit data is empty or corrupted. Cannot save.")

    if not dst_path:
        raise ValueError("Destination path cannot be empty.")

    # 🟠 HIGH PRIORITY: Defensive directory check (create if missing)
    target_dir = os.path.dirname(dst_path)
    if target_dir and not os.path.exists(target_dir):
        try:
            os.makedirs(target_dir, exist_ok=True)
        except OSError as e:
            logger.error(f"Failed to create target directory: {target_dir}")
            raise OSError(f"Could not access or create the target directory: {target_dir}") from e

    # 🟠 HIGH PRIORITY: Explicit write-permission check
    if os.path.exists(dst_path):
        if not os.access(dst_path, os.W_OK):
            raise PermissionError("Permission denied. The file is likely open in another program (like Excel). Please close it and try again.")

    try:
        # 🟠 HIGH PRIORITY: Replace manual open() with a 'with open(...)' context manager
        # newline='' prevents double-spacing issues in Windows CSV exports
        with open(dst_path, mode='w', encoding='utf-8-sig', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(audit['headers'])
            
            for row in audit['rows']:
                # Ensure all elements are strings to prevent write errors
                clean_row = [str(cell) if cell is not None else "" for cell in row]
                writer.writerow(clean_row)
                
        logger.info(f"Successfully saved repaired CSV to {dst_path}")
        
    except PermissionError as pe:
        logger.error(f"File locked during write: {dst_path}")
        raise PermissionError("The file is currently open in another program. Please close it before saving.") from pe
    except Exception as e:
        logger.exception("Failed to write repaired CSV.")
        raise RuntimeError("An unexpected error occurred while saving the file.") from e
