import csv
import logging
from typing import List, Dict
from core.utils.text_processing import clean_cell_text
from core.exceptions import InvalidCSVFormatException

logger = logging.getLogger("StoreLens.CSVRepair")

def robust_csv_parse(file_path: str) -> Dict[str, List]:
    """Reads CSVs while recovering from empty rows, malformed headers, and padding mismatched columns."""
    rows = []
    headers = []
    
    try:
        with open(file_path, mode='r', encoding='utf-8-sig', errors='replace') as f:
            reader = csv.reader(f)
            raw_headers = next(reader, None)
            
            if not raw_headers:
                raise InvalidCSVFormatException("File appears empty.")
                
            headers = [clean_cell_text(h) for h in raw_headers]
            expected_cols = len(headers)
            
            for line_num, row in enumerate(reader, start=2):
                # 1. Skip completely empty rows
                if not row or all(not str(c).strip() for c in row):
                    continue
                    
                # 2. Clean individual cells
                cleaned_row = [clean_cell_text(c) for c in row]
                
                # 3. Handle inconsistent column counts
                if len(cleaned_row) < expected_cols:
                    # Pad missing columns with empty strings
                    cleaned_row.extend([""] * (expected_cols - len(cleaned_row)))
                elif len(cleaned_row) > expected_cols:
                    # Truncate extra orphaned data and log
                    logger.warning(f"Row {line_num}: Truncated extra columns. Expected {expected_cols}, got {len(cleaned_row)}.")
                    cleaned_row = cleaned_row[:expected_cols]
                    
                rows.append(cleaned_row)
                
        return {"headers": headers, "rows": rows}
        
    except UnicodeDecodeError as e:
        raise InvalidCSVFormatException("Unsupported file encoding. Please save as UTF-8.") from e
