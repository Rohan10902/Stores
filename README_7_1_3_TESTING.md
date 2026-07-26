# Store Data Assistant 7.1.3 — Smart Validation Test Plan

## 1. Validation Intelligence
Load Master + Upload and validate with SID + Nielsen Store Code.
Confirm the new Validation Intelligence strip groups:
- identities not found in Master
- field-level mismatches
- exact duplicates
- potential duplicates
- Master key conflicts
Click a group card and confirm Validation Results filters to matching rows. Use Show All to clear the filter.

## 2. Missing Master
Select an uploaded identity absent from Master.
Expected: one grouped `Values / identities not found in Master` finding, not one fake field mismatch per column.
Inspector still shows the uploaded record and MISSING MASTER state.

## 3. Smart Record Reconstruction
Open a CSV with extra delimiter-separated values.
Select the issue. Confirm per-value controls are hidden initially.
Test:
- Repair Current Record: mapping controls appear.
- Keep Entire Record: values remain explicitly unresolved.
- Split / Create New Record: enter a new SID, map only extras that belong to the new record, then Create New Record Candidate.
The application must never invent an SID and must not overwrite an occupied destination.

## 4. Numeric Statistics
Load a dataset with a numeric column such as Amount or Units.
Select the numeric column.
Confirm operations include:
Quick Summary, Count, Distinct Count, Blank Count, Sum, Average, Minimum, Maximum, Median.
Test Sum both ungrouped and grouped by another column.
Quick Summary must show Records, Valid Numeric, Blank, Sum, Average, Minimum, Maximum, Median.

## 5. Regression
Re-test row-order-independent comparison, composite identity matching, SQL, search, CSV quoted-line reconstruction, save blocking for unresolved extras, and Windows maximized layout.
