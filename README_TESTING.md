# Store Data Assistant 7.0.2 — Stabilization Test

Test at 1366x768, 1920x1080 and maximized window.

## Required regression tests
1. Compare: tables must expand vertically; resize the splitter; field comparison must remain readable.
2. Repair: inspect extra-field and quoted multiline samples. Ambiguous values must show UNRESOLVED with diagnosis and no silent deletion.
3. Statistics: verify known numeric answers (10,20,30,40 => Sum 100, Average 25, Min 10, Max 40, Median 25).
4. Text statistics: Most/Least Common and Frequency Distribution must return meaningful values/counts.
5. Grouping: verify one result per group and record counts.
6. Explore: uploaded headers must drive dropdown/table; no QQmlDMAbstractItemModelData text.
7. SQL remains read-only and only visible in Explore & Analyze.
8. Original files must never be overwritten.
