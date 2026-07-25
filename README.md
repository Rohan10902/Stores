# Store Data Assistant 6.0

Functional V6 consolidation.

## Included
- Modern PySide6 + QML interface
- Strict 14-field store Master comparison
- Smart header aliases
- Store rule validation for dates, 1/0 fields, Updated By timestamp
- Duplicate/missing SID detection
- Broken delimited-file inspection with physical line and unplaced values
- General Data Health Check for CSV/TSV/TXT/XLSX/XLS/JSON/XML
- Horizontal/key-value/line-oriented structure hints
- Missing values, duplicates, mixed types, numeric outliers
- General column calculations
- DuckDB read-only SQL ONLY in Explore & Analyze Data
- Local processing architecture
- Windows GitHub Actions build

## Repository layout
Put app.py, Main.qml, requirements.txt and README.md in the repository root.
Put build-windows.yml at .github/workflows/build-windows.yml.

## Important safety behavior
The repair reader does not overwrite the original file. Extra fields are reported as unplaced values rather than silently becoming new business columns.
