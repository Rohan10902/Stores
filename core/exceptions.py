# core/exceptions.py

class StoreAppException(Exception):
    """Base exception for all application errors."""
    pass


class InvalidCSVFormatException(StoreAppException):
    """Raised when CSV structure is unparseable, malformed, or missing headers."""
    pass


class StoreValidationError(StoreAppException):
    """Raised when row data or mapping rules fail quality checks."""
    pass


class RepairFailedException(StoreAppException):
    """Raised when auto-repair or smart-repair heuristics cannot recover data."""
    pass


class StateConflictError(StoreAppException):
    """Raised when an action is attempted during an incompatible worker state."""
    pass
