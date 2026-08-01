# app.py
import sys
import os
from bootstrap import create_application
from core.utils.logger import get_logger

logger = get_logger("App")


def main():
    """
    Main application entry point.
    """
    try:
        app, engine, exit_code = create_application(sys.argv)
        
        if exit_code is not None:
            sys.exit(exit_code)
            
        sys.exit(app.exec())
        
    except FileNotFoundError as fnf:
        logger.critical(f"Critical startup file missing: {fnf}")
        print(f"Error: Required application file missing. Details: {fnf}", file=sys.stderr)
        sys.exit(1)
    except PermissionError as pe:
        logger.critical(f"Permission denied during startup: {pe}")
        print(f"Error: Permission denied. Please check your file permissions. Details: {pe}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        # Top-level boundary catch for the entire application process
        logger.exception("Application crashed due to an unhandled critical exception.")
        print(f"Critical Error: An unexpected application error occurred. Check logs for details.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
