# Store Data Assistant 7.0.3 — Stabilization Test

Only the two confirmed findings are changed.

## SQL
Run without CAST:
SELECT * FROM data WHERE Amount > 1000;

Then:
SELECT Region, SUM(Amount) AS Total_Amount
FROM data
GROUP BY Region
ORDER BY Total_Amount DESC;

Verify SUM, AVG, MIN, MAX, numeric ORDER BY, blank numeric cells as NULL, quoted column names, duplicate detection, and SELECT/WITH-only enforcement.

## Repair
- Exact-width quoted multiline reconstruction => AUTO FIXED / HIGH.
- Extra fields => REVIEW REQUIRED / LOW; values shown as PRESERVED EXTRA.
- Missing fields => REVIEW REQUIRED / LOW.
- Unclosed quote => UNRECOVERABLE.
- No ambiguous value may be silently deleted, merged or reassigned.
- Original file remains unchanged.

## Regression
Re-test Compare, Statistics, Search, dynamic headers, maximize/resize and EXE restart.
