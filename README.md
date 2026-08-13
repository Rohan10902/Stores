# StoreLens 7.3.0

StoreLens is a local-first Windows desktop application for reviewing, validating, repairing, comparing, analysing, and creating structured store datasets.

## Production principles

- Source files remain unchanged unless the user explicitly exports a new file.
- Processing is local to the workstation.
- The canonical Store Builder export schema is defined once in `core/common.py` and reused by validation and export.
- Repeated SIDs are never silently resolved to the first Master row; ambiguous identity matches are surfaced for review.
- Malformed input rows are never silently discarded by the core table reader.
- Clipboard import uses a real CSV parser so quoted commas and tabs are preserved.
- Validation failures remain visible and block Store Builder export until resolved.
- CSV repair preserves unresolved values and requires explicit review before export.
- Exports are written to a temporary file and atomically renamed after the write is flushed.

## Canonical Store Builder schema

The Store Builder produces exactly these 12 columns, in this order:

1. Store Name
2. SID
3. Banner
4. Nielsen Store Code
5. Trip Received
6. Last Trip
7. Address 1
8. Address 2
9. City
10. State
11. Pincode
12. Phone

The authoritative definition is `core/common.py::STORE_FIELDS`. Legacy input aliases are accepted where they can be mapped safely.

## Supported input

The application core supports CSV, TSV/text, Excel (`.xlsx`, `.xls`, `.xlsm`), JSON, and XML where the required pandas reader is available.

## Development

Requires Python 3.12.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
python app.py
```

## Tests

```powershell
python -m pytest tests/ -v
```

CI compiles the Python source, runs correctness linting, lints every QML file, executes the full test suite, starts the real StoreLens UI offscreen, builds the Windows executable, launches the packaged executable, verifies the startup marker, and generates SHA-256 checksums before publishing the artifact.

## Windows build

The release-candidate workflow is `.github/workflows/build-windows.yml`. A successful PyInstaller command alone is not a pass: both source and packaged startup probes must succeed.

The packaged application is named `StoreLens.exe` and carries version metadata from `version_info.txt`.

## Logs

Runtime diagnostics are stored under the user's StoreLens log directory (on Windows, `%LOCALAPPDATA%\StoreLens\Logs\`) with rotation so logs do not grow without bound.

## Release policy

`main` is the stable StoreLens source line. A production release should follow a successful end-to-end Windows CI run and hands-on testing of the generated artifact.
