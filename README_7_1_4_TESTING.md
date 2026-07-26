# Store Data Assistant 7.1.4 Trial Test Plan

## Review One File
- Load only one CSV/XLSX; no Master should be required.
- Confirm invalid Boolean/date values appear under Records Needing Attention.
- Confirm Nielsen Store Code width is suggested from numeric-looking codes.
- Apply padding to a chosen width and export a new reviewed CSV.
- Confirm source file is unchanged.

## Create Store File
Fixed columns and order:
Store Name, SID, Banner, Nielsen Store Code, Trip Received, Last Trip, Address 1, Address 2, Address 3, ZIP, Active / Inactive, Is Census, Is Exceptions, Updated By

### Clipboard paste
- Copy a rectangle from Excel/Google Sheets.
- Click the intended starting cell.
- Ctrl+V.
- Confirm rows/columns fill from that selected cell and new rows are created when required.
- Repeat using the visible Paste from Clipboard button.
- Paste Nielsen codes such as 001234 and confirm zeros remain visible.

### Editing / export
- Add Row, Delete Selected Row, Clear Table.
- Validate invalid Boolean/date values.
- Export CSV only after correcting invalid values.
- Confirm CSV contains only the predetermined columns in the predetermined order.

## Regression
Retest 7.1.3 Compare & Validate, Smart Repair, Data Health Sum/Quick Summary, Explore SQL/search, maximized window layout and Windows build.
Keep the existing `.github/workflows/build-windows.yml`.
