import csv
from pathlib import Path

def _delimiter(raw, suffix):
    if suffix.lower() == ".tsv":
        return "\t"
    try:
        return csv.Sniffer().sniff(raw[:12000], delimiters=",;\t|").delimiter
    except Exception:
        return ","

def _quote_open(s):
    i = count = 0
    while i < len(s):
        if s[i] == '"':
            if i + 1 < len(s) and s[i + 1] == '"':
                i += 2
                continue
            count += 1
        i += 1
    return count % 2 == 1

def inspect_csv(p):
    path = Path(p)
    raw = path.read_text(encoding="utf-8-sig", errors="replace")
    physical = raw.splitlines(keepends=True)
    if not physical:
        raise ValueError("File is empty.")

    delim = _delimiter(raw, path.suffix)
    header = next(csv.reader([physical[0]], delimiter=delim))
    expected = len(header)
    logical = [(1, 1, header, physical[0].rstrip("\r\n"))]
    issues = []
    buf = ""
    start = 2

    for no, line in enumerate(physical[1:], 2):
        if not buf:
            start = no
        buf += line
        if _quote_open(buf):
            continue

        try:
            vals = next(csv.reader([buf], delimiter=delim))
        except Exception as e:
            issues.append({
                "line": str(start), "startLine": start, "endLine": no,
                "status": "UNRESOLVED", "problem": "CSV parser error",
                "repair": str(e), "expectedColumns": expected, "actualColumns": 0,
                "original": buf.rstrip("\r\n"), "proposed": "",
                "confidence": "NONE", "columns": []
            })
            buf = ""
            continue

        logical.append((start, no, vals, buf.rstrip("\r\n")))
        line_label = f"{start}-{no}" if start != no else str(no)

        if start != no and len(vals) == expected:
            columns = [{"field": header[i], "before": vals[i], "after": vals[i],
                        "status": "RECONSTRUCTED"} for i in range(expected)]
            issues.append({
                "line": line_label, "startLine": start, "endLine": no,
                "status": "AUTO FIXED",
                "problem": "One logical CSV record was split across physical lines",
                "repair": f"Combined lines {start}-{no}; parsed record now matches the {expected}-column header",
                "expectedColumns": expected, "actualColumns": len(vals),
                "original": buf.rstrip("\r\n"),
                "proposed": delim.join(vals),
                "confidence": "HIGH", "columns": columns
            })
        elif len(vals) != expected:
            columns = []
            for i, v in enumerate(vals):
                field = header[i] if i < expected else f"EXTRA FIELD {i-expected+1}"
                columns.append({
                    "field": field, "before": v, "after": v,
                    "status": "EXTRA" if i >= expected else "UNCHANGED"
                })
            for i in range(len(vals), expected):
                columns.append({"field": header[i], "before": "", "after": "", "status": "MISSING"})
            issues.append({
                "line": line_label, "startLine": start, "endLine": no,
                "status": "UNRESOLVED",
                "problem": "Column count differs from header",
                "repair": "No destructive repair was applied. Review the extra/missing values before treating this file as clean.",
                "expectedColumns": expected, "actualColumns": len(vals),
                "original": buf.rstrip("\r\n"), "proposed": delim.join(vals),
                "confidence": "NONE", "columns": columns
            })
        buf = ""

    if buf:
        issues.append({
            "line": f"{start}-{len(physical)}", "startLine": start, "endLine": len(physical),
            "status": "UNRESOLVED", "problem": "Unclosed quoted field",
            "repair": "The record cannot be safely reconstructed automatically.",
            "expectedColumns": expected, "actualColumns": 0,
            "original": buf.rstrip("\r\n"), "proposed": "",
            "confidence": "NONE", "columns": []
        })

    healthy = max(0, len(logical) - 1 - len(issues))
    auto = sum(i["status"] == "AUTO FIXED" for i in issues)
    unresolved = sum(i["status"] == "UNRESOLVED" for i in issues)
    return {
        "file": path.name, "delimiter": delim, "header": header, "expected": expected,
        "records": max(0, len(logical)-1), "healthy": healthy,
        "autoFixed": auto, "unresolved": unresolved,
        "logical": logical, "issues": issues
    }

def save_repaired(src, dst):
    x = inspect_csv(src)
    with open(dst, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f, delimiter=x["delimiter"])
        for _, _, vals, _ in x["logical"]:
            # Preserve every parsed value. Never silently truncate or merge extra fields.
            w.writerow(vals)
    return {"unresolved": x["unresolved"], "autoFixed": x["autoFixed"], "issues": len(x["issues"])}
