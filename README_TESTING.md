# Store Data Assistant 7.0.1 — Test Build

This build consolidates fixes found during 7.0 testing.

## Regression tests

1. Compare & Validate
   - Load Master and uploaded/country files.
   - Validate.
   - Click a normal mismatch: confirm Field / Master Value / Uploaded Value / Result.
   - Click a missing SID: confirm the missing-master explanation appears.

2. Repair CSV / Text
   - Load a CSV with a quoted multiline record: it should show AUTO FIXED / HIGH confidence.
   - Load a row with too many/few fields: it must remain UNRESOLVED.
   - Confirm extra data is shown in Repair Preview and is never silently deleted.
   - Saving with unresolved issues must say "Reviewed copy", not claim the file is fully repaired.

3. Data Health & Statistics
   - Column list must come from the loaded file.
   - Operations must change based on detected type.
   - Text columns must not offer numeric Sum/Average/Maximum.
   - Numeric columns should support Sum/Average/Min/Max/Median.
   - Grouping should produce one result per group.

4. Explore & Analyze
   - Search dropdown must exactly follow the loaded file headers.
   - Result table headers must exactly follow the loaded file/query result.
   - Cells must show actual values, never QQmlDMAbstractItemModelData(...).
   - SQL is read-only and uses table name `data`.

## Privacy
All processing is local. Source files are not overwritten.
