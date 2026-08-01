# app.py
import sys
import logging
from bootstrap import create_application

logger = logging.getLogger("StoreLens")

def main():
    try:
        app, engine, exit_code = create_application(sys.argv)
        if exit_code is not None:
            sys.exit(exit_code)
        sys.exit(app.exec())
    except Exception as e:
        logger.critical(f"Unhandled startup error: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
