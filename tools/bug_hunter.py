from __future__ import annotations

import argparse
import re
from pathlib import Path


RULES: list[tuple[str, str, str, str]] = [
    ("qml-scope", r"unqualified access|missing-property", "QML delegate scope", "Audit the delegate under ComponentBehavior: Bound; add required properties and explicit delegate IDs instead of relying on implicit model/index/parent scope."),
    ("csv-tokenize", r"tokeniz|Expected \d+ fields|ParserError|Error tokenizing data", "CSV parsing", "Inspect CSV dialect/quoting/encoding handling and preserve a readable parse error; do not discard the file or leave the preview empty."),
    ("duplicate-dialog", r"popup|dialog|window.*twice|twice|duplicate.*dialog|multiple.*window", "Dialog lifecycle", "Check repeated signal connections, duplicate component creation, and stale modal objects. A browse action must create/trigger exactly one dialog."),
    ("stale-state", r"stale|previous.*dataset|old.*dataset|master.*preview|previous.*preview", "Dataset state isolation", "Clear and replace feature-local dataset/model state on every load. Do not keep global preview state shared across pages."),
    ("export", r"export.*fail|export.*failed|cannot.*export|permission.*denied|No such file", "Export pipeline", "Export to a new destination atomically, validate the output, and never write to the source dataset."),
    ("qml-performance", r"not responding|hang|timeout|10,000|10000|slow|lag", "UI performance", "Keep large datasets in a Qt model and use virtualized TableView; avoid creating one QML object per record/cell."),
    ("assertion", r"AssertionError|assert .*==", "Test contract", "Inspect the failing assertion and compare it with the canonical schema/model contract before changing application behavior."),
    ("python-exception", r"Traceback \(most recent call last\)|AttributeError|KeyError|TypeError|IndexError|ValueError|RuntimeError", "Python exception", "Fix the first application traceback at its source; add a regression test for the failing path."),
    ("object-render", r"\[object Object\]|object Object|item\(s\)", "Structured UI rendering", "Format dictionaries/lists into human-readable sections instead of binding raw JavaScript object representations to Text elements."),
]


def scan_text(text: str) -> list[dict[str, str]]:
    """Return one contextual finding per rule, not every textual occurrence."""
    findings: list[dict[str, str]] = []
    for rule_id, pattern, area, suggestion in RULES:
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            findings.append({"id": rule_id, "area": area, "line": str(line), "suggestion": suggestion})
    return findings


def collect_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for folder in (root / "core", root / "qml", root / "tests", root / ".github", root / "tools"):
        if folder.exists():
            files.extend(
                p for p in folder.rglob("*")
                if p.is_file() and p.suffix in {".py", ".qml", ".yml", ".yaml", ".txt", ".log"}
            )
    return files


def parse_ci_failures(text: str) -> list[dict[str, str]]:
    """Extract confirmed pytest failures from CI output.

    This is deliberately conservative: only explicit pytest FAILED lines are
    promoted to confirmed findings. Generic words in source code are never
    treated as proof of a bug.
    """
    failures: list[dict[str, str]] = []

    # Example:
    # FAILED tests/test_store_table_model.py::test_name - AssertionError: ...
    failed_re = re.compile(r"FAILED\s+([^\r\n]+?)(?:\s+-\s+(.+))?$", re.IGNORECASE | re.MULTILINE)
    for match in failed_re.finditer(text):
        target = match.group(1).strip()
        reason = (match.group(2) or "pytest reported a failure").strip()
        failures.append({
            "target": target,
            "reason": reason,
            "confidence": "Confirmed",
        })

    # Add the exact assertion/result when the summary line is less informative.
    assertion_re = re.compile(
        r"E\s+AssertionError:\s+assert\s+(.+?)\s+==\s+(.+?)(?=\r?$)",
        re.IGNORECASE | re.MULTILINE,
    )
    assertions = assertion_re.findall(text)
    if assertions and failures:
        actual, expected = assertions[-1]
        failures[-1]["detail"] = f"Actual {actual.strip()} != expected {expected.strip()}"

    # Capture the traceback location belonging to each failure when present.
    location_re = re.compile(r"(?m)^([^\r\n]+(?:tests|core)[^\r\n]*):([0-9]+): in .+$")
    locations = location_re.findall(text)
    if locations and failures:
        path, line = locations[-1]
        failures[-1]["location"] = f"{path}:{line}"

    # De-duplicate repeated GitHub log sections.
    unique: dict[str, dict[str, str]] = {}
    for failure in failures:
        unique[failure["target"]] = failure
    return list(unique.values())


def referenced_paths(root: Path, log_text: str) -> set[Path]:
    """Find repository files explicitly named in CI logs for contextual scanning."""
    paths: set[Path] = set()
    pattern = re.compile(r"(?:[A-Za-z]:[\\/])?([^\r\n]*?(?:core|qml|tests|tools)[\\/][^\r\n:]+\.(?:py|qml|yml|yaml))", re.IGNORECASE)
    for match in pattern.finditer(log_text):
        raw = match.group(1).replace("\\", "/").strip()
        raw = raw.split(" ")[0]
        candidate = root / raw
        if candidate.exists() and candidate.is_file():
            paths.add(candidate)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--logs", default="")
    parser.add_argument("--output", default="bug-hunter-report.md")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    files = collect_files(root)
    ci_text = ""
    if args.logs:
        log_path = Path(args.logs)
        if log_path.exists():
            ci_text = log_path.read_text(encoding="utf-8", errors="replace")

    confirmed = parse_ci_failures(ci_text) if ci_text else []

    # With CI logs available, only scan files explicitly referenced by the
    # failure log. This prevents unrelated source strings from becoming fake
    # bug reports. Without logs, retain the broader static scan as a fallback.
    if ci_text:
        scan_targets = referenced_paths(root, ci_text)
    else:
        scan_targets = set(files)

    contextual: list[dict[str, str]] = []
    for path in sorted(scan_targets):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for finding in scan_text(text):
            finding["file"] = str(path.relative_to(root))
            contextual.append(finding)

    priority = {
        "python-exception": 0,
        "csv-tokenize": 1,
        "export": 2,
        "duplicate-dialog": 3,
        "stale-state": 4,
        "qml-scope": 5,
        "qml-performance": 6,
        "assertion": 7,
        "object-render": 8,
    }
    contextual.sort(key=lambda x: (priority.get(x["id"], 99), x["file"], int(x["line"])))

    lines = [
        "# StoreLens Bug Hunter Report",
        "",
        "This report is diagnostic only. It does not modify application behavior.",
        "",
    ]

    if confirmed:
        lines += [
            f"## Confirmed CI failures ({len(confirmed)})",
            "",
            "These findings come directly from explicit pytest failure output. They are the primary debugging targets.",
            "",
            "| Confidence | Test | Location | Result |",
            "|---|---|---|---|",
        ]
        for failure in confirmed:
            detail = failure.get("detail", failure["reason"])
            location = failure.get("location", "not captured")
            lines.append(f"| **{failure['confidence']}** | `{failure['target']}` | `{location}` | {detail} |")
        lines += [
            "",
            "### Debug rule",
            "",
            "Start with the first confirmed failure. Do not change unrelated application code merely because a static rule matches a keyword.",
            "",
        ]
    elif ci_text:
        lines += [
            "## Confirmed CI failures",
            "",
            "No explicit pytest `FAILED ...` entries were found in the supplied CI log. Static findings below are contextual only.",
            "",
        ]
    else:
        lines += [
            "## Confirmed CI failures",
            "",
            "No CI log was supplied, so no failure can be promoted to confirmed status.",
            "",
        ]

    if contextual:
        lines += [
            f"## Contextual static signals ({len(contextual)})",
            "",
            "These are risk signals, not proof of defects. When CI logs are available, only files named by the failure log are scanned.",
            "",
            "| Priority | Area | File | Line | Suggested debug |",
            "|---|---|---|---:|---|",
        ]
        for i, finding in enumerate(contextual, 1):
            lines.append(
                f"| {i} | {finding['area']} | `{finding['file']}` | {finding['line']} | {finding['suggestion']} |"
            )
        lines.append("")
    else:
        lines += ["## Contextual static signals", "", "No known static signals were detected.", ""]

    lines += [
        "## Recommended order",
        "",
        "1. Fix the first **confirmed CI failure** and preserve all currently passing contracts.",
        "2. Add or update a focused regression test for the exact failure.",
        "3. Re-run the full CI suite before changing unrelated QML/backend behavior.",
        "4. Treat static signals as review prompts, not confirmed bugs.",
        "",
    ]

    Path(args.output).write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
