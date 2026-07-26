# Store Data Assistant 7.1.2 — Correctness / Stability

## Compare
1. Shuffle uploaded rows completely. Results must remain identical.
2. Repeated SID + different Nielsen Store Code must be treated as distinct identities when using SID + Nielsen Store Code.
3. Same SID + same Nielsen Store Code twice:
   - identical full records => EXACT DUPLICATE / ERROR
   - differing records => POTENTIAL DUPLICATE / REVIEW
4. Duplicate composite key in Master => MASTER KEY CONFLICT / ERROR.
5. Error-aware inspector must explain the row-level problem even when field values otherwise match.

## Repair
1. 411004 should suggest ZIP when the file profile supports it.
2. Apply must map the preserved extra into an EMPTY destination only.
3. A non-empty destination must never be overwritten silently.
4. Keep leaves the value unresolved.
5. Saving is blocked while preserved extra values remain unresolved.
6. Original source is never overwritten by the repair engine.

## Data Health
1. Numeric columns: Sum/Average/Median/Min/Max.
2. Text/Boolean: frequency/common values and percentages.
3. Smart Insight must explain blanks and notable distribution information.
4. Statistics columns must remain aligned when maximized.

## Regression
Explore SQL, search, dynamic headers, resize/maximize, startup and Windows EXE build.
`.github/workflows/build-windows.yml` remains unchanged.
