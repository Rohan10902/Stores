class StoreImportError(Exception):
    """Base exception for store import operations."""


class MissingFileError(StoreImportError, FileNotFoundError):
    """Raised when an expected file is missing."""


class UnsupportedFormatError(StoreImportError, ValueError):
    """Raised when the file extension/format is not supported by the importer."""
