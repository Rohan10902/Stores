# core/csv_repair.py
import csv
import os
from core.utils.logger import get_logger

logger = get_logger("CSVRepair")

def inspect_csv(file_path: str) -> dict:
    """
    Inspects a CSV file for alignment issues, shifted rows, and formatting errors.
    """
    if not file_path or not os.path.exists(file_path):
        raise FileNotFoundError(f"CSV file not found: {file_path}")

    try:
        issues = []
        headers = []
        rows = []
        
        with open(file_path, mode='r', encoding='utf-8-sig', newline='') as f:
            reader = csv.reader(f)
            try:
                headers = next(reader)
            except StopIteration:
                raise ValueError("The CSV file is completely empty.")
                
            for row_idx, row in enumerate(reader, start=1):
                rows.append(row)
                if len(row) != len(headers):
                    issues.append({
                        "row": row_idx,
                        "type": "COLUMN_MISMATCH",
                        "message": f"Expected {len(headers)} columns, found {len(row)}."
                    })

        return {
            "headers": headers,
            "rows": rows,
            "issues": issues,
            "history": []
        }

    except FileNotFoundError as fnf:
        logger.error(f"File not found during inspection: {fnf}")
        raise
    except ValueError as ve:
        logger.error(f"Value/Structure error inspecting CSV: {ve}")
        raise
    except csv.Error as ce:
        logger.error(f"Standard CSV parsing error: {ce}")
        raise ValueError(f"Malformed CSV formatting: {ce}") from ce


# ⬇️ ADD ROBUST_CSV_PARSE HERE ⬇️
def robust_csv_parse(file_path: str) -> dict:
    """
    Robustly parses a CSV file handling irregular columns or malformed rows.
    Satisfies test suite dependencies.
    """
    if not file_path or not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")
        
    headers = []
    rows = []
    issues = []
    
    with open(file_path, mode='r', encoding='utf-8-sig', newline='') as f:
        reader = csv.reader(f)
        try:
            headers = next(reader)
        except StopIteration:
            raise ValueError("CSV file is empty.")
            
        for idx, row in enumerate(reader, start=1):
            rows.append(row)
            if len(row) != len(headers):
                issues.append({
                    "row": idx,
                    "type": "COLUMN_MISMATCH",
                    "message": f"Expected {len(headers)} columns, found {len(row)}."
                })
                
    return {
        "headers": headers,
        "rows": rows,
        "issues": issues,
        "recordCount": len(rows),
        "issueCount": len(issues)
    }
    
def join_shifted_rows(audit: dict, index: int) -> dict:
    try:
        if not audit or 'rows' not in audit:
            raise KeyError("Audit data is missing 'rows'.")
        rows = audit['rows']
        if not (0 <= index < len(rows)):
            raise IndexError(f"Index {index} out of range for rows list.")
        
        # Core joining logic...
        return audit
    except (KeyError, IndexError) as err:
        logger.error(f"Index or key error joining rows: {err}")
        raise
    except Exception as e:
        logger.exception("Unexpected error in join_shifted_rows")
        raise RuntimeError("Failed to join shifted rows.") from e

def apply_mapping(audit: dict, issue_index: int, col_index: int, target: str) -> dict:
    try:
        if not audit:
            raise ValueError("Audit object is empty.")
        # Mapping logic...
        return audit
    except (KeyError, IndexError, ValueError) as err:
        logger.error(f"Invalid parameters mapping repair: {err}")
        raise
    except Exception as e:
        logger.exception("Unexpected error in apply_mapping")
        raise RuntimeError("Failed to apply repair mapping.") from e

def keep_unresolved(audit: dict, issue_index: int, col_index: int) -> dict:
    try:
        return audit
    except Exception as e:
        logger.exception("Unexpected error in keep_unresolved")
        raise RuntimeError("Failed to mark item as unresolved.") from e

def keep_issue_as_is(audit: dict, issue_index: int) -> dict:
    try:
        return audit
    except Exception as e:
        logger.exception("Unexpected error in keep_issue_as_is")
        raise RuntimeError("Failed to keep issue as-is.") from e

def create_record_from_extras(audit: dict, issue_index: int, mapping: dict) -> dict:
    try:
        if not mapping:
            raise ValueError("Mapping dictionary cannot be empty.")
        return audit
    except (ValueError, KeyError) as err:
        logger.error(f"Invalid mapping data for record creation: {err}")
        raise
    except Exception as e:
        logger.exception("Unexpected error in create_record_from_extras")
        raise RuntimeError("Failed to create record from extras.") from e

def delete_created_record(audit: dict, record_id: str) -> dict:
    try:
        return audit
    except Exception as e:
        logger.exception("Unexpected error in delete_created_record")
        raise RuntimeError("Failed to delete created record.") from e

def undo_last_created_action(audit: dict) -> dict:
    try:
        if not audit or not audit.get('history'):
            raise ValueError("No actions available in history to undo.")
        return audit
    except ValueError as ve:
        logger.warning(str(ve))
        raise
    except Exception as e:
        logger.exception("Unexpected error in undo_last_created_action")
        raise RuntimeError("Failed to undo last repair action.") from e

def save_repaired(audit: dict, dst_path: str) -> None:
    if not audit or 'headers' not in audit or 'rows' not in audit:
        raise ValueError("Audit data is empty or corrupted. Cannot save.")

    if not dst_path:
        raise ValueError("Destination path cannot be empty.")

    target_dir = os.path.dirname(dst_path)
    if target_dir and not os.path.exists(target_dir):
        try:
            os.makedirs(target_dir, exist_ok=True)
        except OSError as e:
            logger.error(f"Failed to create target directory: {target_dir}")
            raise OSError(f"Could not access or create the target directory: {target_dir}") from e

    if os.path.exists(dst_path) and not os.access(dst_path, os.W_OK):
        raise PermissionError("Permission denied. The file is likely open in another program.")

    try:
        with open(dst_path, mode='w', encoding='utf-8-sig', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(audit['headers'])
            for row in audit['rows']:
                clean_row = [str(cell) if cell is not None else "" for cell in row]
                writer.writerow(clean_row)
        logger.info(f"Successfully saved repaired CSV to {dst_path}")
    except PermissionError as pe:
        logger.error(f"File locked during write: {dst_path}")
        raise PermissionError("The file is currently open in another program.") from pe
    except OSError as oe:
        logger.error(f"OS error writing file {dst_path}: {oe}")
        raise RuntimeError("An OS error occurred while trying to write the file.") from oe
    except Exception as e:
        logger.exception("Unexpected critical error saving repaired CSV.")
        raise RuntimeError("An unexpected error occurred while saving the file.") from e
