# Store Data Assistant 6.1

Complete local-first PySide6/QML project.

## Files
- `app.py`
- `Main.qml`
- `requirements.txt`
- `.github/workflows/build-windows.yml`

## Main capabilities
- Smart matching of country-specific headers to the approved 14 store fields.
- Master-vs-mapping validation, SID checks, date/flag checks, and report export.
- CSV/TXT inspection with quoted-comma-aware parsing and conservative repaired-copy export.
- General structured-data health statistics.
- Local read-only SQL in Explore & Analyze only.
- CSV/XLSX/JSON export.
- Production Windows build uses `--windowed`, so no terminal window is shown.
- Qt Quick Controls uses the Basic style to avoid the native-style customization warnings previously seen.

## Supported structured formats
CSV, TSV/TXT, XLSX/XLS/XLSM, JSON, XML.

## Run locally
`pip install -r requirements.txt`
`python app.py`

## Debugging
If a future packaged build fails before showing the UI, temporarily replace `--windowed` with `--console` in the workflow to expose the startup error, then restore `--windowed` after fixing it.
