# Store Data Assistant — Production Release Qualification

This checklist is the release gate for Store Data Assistant 7.2.1 and later production candidates.

A green CI build is necessary but does not by itself authorize a production release. The packaged Windows application must pass the applicable checks below.

## 1. Packaged application functional test

Test the packaged EXE/artifact rather than the source/development environment.

- [ ] Home page opens and every workspace route opens without QML/runtime errors.
- [ ] Compare & Validate: load supported files, compare, review findings, and export results.
- [ ] Review One File: analyze CSV/XLSX, show findings and descriptions, preview padding, apply SID/Nielsen padding, and export reviewed copy.
- [ ] Repair CSV/Text: detect broken records, inspect reconstruction, map/keep values, create a new record, confirm it appears in Repaired Data Preview, and export a clean CSV.
- [ ] Create Store File: paste, edit, add/delete rows, undo, validate, bulk-pad selected columns, Find/Replace, and export CSV.
- [ ] Data Health & Statistics: load supported datasets and run text and numeric statistics.
- [ ] Explore & Analyze: search, run allowed read-only SQL, use suggestions, and verify result tables.

## 2. Latest-fix regression test

- [ ] Review One File structural findings are visible.
- [ ] Finding descriptions/previews are not clipped or hidden.
- [ ] Nielsen Store Code padding preview shows before/after values.
- [ ] SID leading-zero padding works without changing non-digit identifiers.
- [ ] Repair-created records appear in the resulting-data preview before export.
- [ ] Repair export is blocked while unresolved values remain.
- [ ] Clean repair export contains no malformed/broken record structure.
- [ ] Create Store File supports SID/Nielsen/ZIP bulk padding.
- [ ] Find/Replace reports how many cells changed.
- [ ] Large Create Store tables remain scrollable/responsive through virtualized rendering.

## 3. Invalid and hostile input test

Verify that each case produces a useful error/review state and does not crash the application.

- [ ] Empty file.
- [ ] Header-only file.
- [ ] Malformed CSV delimiters/quotes.
- [ ] Extra and missing fields.
- [ ] Duplicate headers.
- [ ] Unicode/non-ASCII data.
- [ ] Embedded commas, quotes and newlines.
- [ ] Very long cell values.
- [ ] Mixed numeric/text columns.
- [ ] Invalid dates.
- [ ] Corrupted or unsupported workbook.
- [ ] Locked/read-only destination.
- [ ] Cancelled file dialogs.
- [ ] Invalid or unwritable export path.

## 4. Data-integrity gate

For representative datasets compare source, preview and exported output.

- [ ] Source file is never silently modified.
- [ ] No row is silently deleted.
- [ ] No extra repair value is silently discarded.
- [ ] Row counts are correct after intentional split/new-record operations.
- [ ] Column order/schema is correct.
- [ ] Leading zeros survive export where requested.
- [ ] Unicode survives round-trip export.
- [ ] Repair output matches the approved preview.
- [ ] Create Store output contains exactly the fixed schema.
- [ ] SQL/analysis operations do not mutate source data.

## 5. Large-file performance gate

Use realistic datasets where possible. Record elapsed time, peak memory and UI responsiveness.

| Rows | Load | Analyze/Validate | Scroll/UI | Export | Peak RAM | Result |
| ---: | --- | --- | --- | --- | --- | --- |
| 10,000 | | | | | | |
| 50,000 | | | | | | |
| 100,000 | | | | | | |
| 250,000 | | | | | | |
| 500,000+ | | | | | | |

Release blockers include crashes, data loss/corruption, uncontrolled memory growth, or a UI that remains unusable for the target production dataset size.

Do not impose an arbitrary maximum number of stores unless a business/schema requirement demands one. Practical limits should be governed by validated performance and available memory.

## 6. Code and packaging audit

- [ ] No hard-coded developer-machine paths.
- [ ] No debug-only behavior in the production executable.
- [ ] Exceptions shown to users are actionable and do not expose unnecessary internals.
- [ ] File writes use reviewed/explicit destinations.
- [ ] Read-only SQL restrictions remain enforced.
- [ ] No known expensive full-data UI rendering remains where virtualization/paging is appropriate.
- [ ] Avoid unnecessary dataframe/data copies on large operations where practical.
- [ ] Temporary files are cleaned up.
- [ ] Packaged dependencies are required by runtime or documented tooling.
- [ ] Production and diagnostic packages contain the expected Qt/QML runtime files.
- [ ] Startup gate passes against the packaged diagnostic executable.

## 7. Automated regression gate

- [ ] Python/regression suite passes.
- [ ] QML static/startup checks pass.
- [ ] Previously fixed startup/parser failures have regression coverage where feasible.
- [ ] Repair/new-record behavior has regression coverage where feasible.
- [ ] Export/data-integrity behavior has regression coverage where feasible.
- [ ] CI creates checksums for the candidate artifact.

## 8. Package-size review

Before production, inspect the artifact contents and identify the largest runtime components.

- Remove only files/dependencies demonstrated to be unnecessary.
- Do not trade startup reliability or application functionality for a smaller archive.
- Record final archive size and extracted size for the release notes.

## 9. Clean Windows machine test

Use a Windows machine or VM without the repository, Python development environment, Qt SDK, or project dependencies installed.

- [ ] Extract/install using only the release package.
- [ ] Production EXE starts by double-click.
- [ ] No terminal is required for normal use.
- [ ] All six workflows open.
- [ ] Representative CSV and XLSX files load.
- [ ] Representative exports succeed and reopen correctly.
- [ ] Application restarts successfully after normal use.

## 10. Release Candidate freeze

When sections 1–9 pass:

- Create `7.2.1-rc1` from the exact qualified commit.
- Freeze features.
- Accept only release-blocking fixes.
- Every fix requires CI plus targeted regression retest.
- A changed RC becomes a new RC; do not silently replace an already-qualified binary.

## 11. Production release

Production is authorized only when the final RC passes CI and clean-machine testing.

- [ ] Version metadata is correct everywhere visible to the user.
- [ ] Production icon/name are correct.
- [ ] Quick-start/readme is included or published.
- [ ] Required third-party notices/licenses are included.
- [ ] Windows code signing is completed if the distribution model requires it.
- [ ] Exact release commit is tagged.
- [ ] Final CI is green from the immutable release revision.
- [ ] SHA-256 checksum is published/archived.
- [ ] Final artifact and release source/build information are retained.

## Release decision

**Release:** all release-blocking gates pass and no unresolved data-integrity, startup, crash, or target-scale performance defect remains.

**Hold:** any startup failure, crash, silent data loss/change, incorrect export, unresolved packaging dependency, or unacceptable target-scale performance remains.
