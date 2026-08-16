from __future__ import annotations

import argparse
import re
from pathlib import Path


RULES: list[tuple[str, str, str, str]] = [
    ("qml-scope", r"unqualified access|missing-property|modelData|\bparent\.", "QML delegate scope", "Audit the delegate under ComponentBehavior: Bound; add required properties and explicit delegate IDs instead of relying on modelData/index/parent scope."),
    ("csv-tokenize", r"tokeniz|Expected \d+ fields|ParserError|Error tokenizing data", "CSV parsing", "Inspect CSV dialect/quoting/encoding handling and preserve a readable parse error; do not discard the file or leave the preview empty."),
    ("duplicate-dialog", r"popup|dialog|window.*twice|twice|duplicate.*dialog|multiple.*window", "Dialog lifecycle", "Check repeated signal connections, duplicate component creation, and stale modal objects. A browse action must create/trigger exactly one dialog."),
    ("stale-state", r"stale|previous.*dataset|old.*dataset|master.*preview|previous.*preview", "Dataset state isolation", "Clear and replace feature-local dataset/model state on every load. Do not keep global preview state shared between pages."),
    ("export", r"export.*fail|export.*failed|cannot.*export|permission.*denied|No such file|destination", "Export pipeline", "Export to a new destination atomically, validate the output, and never write to the source dataset."),
    ("qml-performance", r"not responding|hang|timeout|10,000|10000|slow|lag", "UI performance", "Keep large datasets in a Qt model and use virtualized TableView; avoid creating one QML object per record/cell."),
    ("assertion", r"AssertionError|assert .*==", "Test contract", "Inspect the failing assertion and compare it with the canonical schema/model contract before changing application behavior."),
    ("python-exception", r"Traceback \(most recent call last\)|AttributeError|KeyError|TypeError|IndexError|ValueError|RuntimeError", "Python exception", "Fix the first application traceback at its source; add a regression test for the failing path."),
    ("object-render", r"\[object Object\]|object Object|item\(s\)", "Structured UI rendering", "Format dictionaries/lists into human-readable sections instead of binding raw JavaScript object representations to Text elements."),
]


def scan_text(text: str) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []
    for rule_id, pattern, area, suggestion in RULES:
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            findings.append({"id": rule_id, "area": area, "line": str(line), "suggestion": suggestion})
    return findings


def collect_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for folder in (root / "core", root / "qml", root / "tests", root / ".github"):
        if folder.exists():
            files.extend(p for p in folder.rglob("*") if p.is_file() and p.suffix in {".py", ".qml", ".yml", ".yaml", ".txt", ".log"})
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--logs", default="")
    parser.add_argument("--output", default="bug-hunter-report.md")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    files = collect_files(root)
    findings: list[dict[str, str]] = []

    for path in files:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for finding in scan_text(text):
            finding["file"] = str(path.relative_to(root))
            findings.append(finding)

    if args.logs:
        log_path = Path(args.logs)
        if log_path.exists():
            text = log_path.read_text(encoding="utf-8", errors="replace")
            for finding in scan_text(text):
                finding["file"] = str(log_path.relative_to(root))
                findings.append(finding)

    unique: dict[tuple[str, str], dict[str, str]] = {}
    for finding in findings:
        unique[(finding["id"], finding["file"])] = finding
    findings = list(unique.values())

    priority = {"python-exception": 0, "csv-tokenize": 1, "export": 2, "duplicate-dialog": 3, "stale-state": 4, "qml-scope": 5, "qml-performance": 6, "assertion": 7, "object-render": 8}
    findings.sort(key=lambda x: (priority.get(x["id"], 99), x["file"], int(x["line"])))

    lines = ["# StoreLens Bug Hunter Report", "", "This report is diagnostic only. It does not modify application behavior.", ""]
    if not findings:
        lines += ["## Result", "", "No known bug signatures were detected by the rule-based scan.", ""]
    else:
        lines += [f"## Findings ({len(findings)})", "", "| Priority | Area | File | Line | Suggested debug |", "|---|---|---|---:|---|"]
        for i, finding in enumerate(findings, 1):
            lines.append(f"| {i} | {finding['area']} | `{finding['file']}` | {finding['line']} | {finding['suggestion']} |")
        lines += ["", "## Recommended order", "", "1. Fix application exceptions and data-loading failures.", "2. Fix dataset/dialog lifecycle leaks and cross-page state.", "3. Fix QML scope/lint problems without suppressing diagnostics.", "4. Fix large-dataset rendering/performance using Qt models/TableView.", "5. Fix presentation of structured health/statistics payloads.", "6. Add or update a regression test before declaring the issue closed.", ""]

    Path(args.output).write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
