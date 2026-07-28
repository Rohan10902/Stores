"""Pure, side-effect-free dataset quality scoring helpers.

This module intentionally has no UI, file writes, or mutation of caller-owned
DataFrames. It is safe to use from review/health screens as a shared quality
engine without changing existing workflows.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

import pandas as pd


@dataclass(frozen=True)
class QualityDimension:
    name: str
    score: float
    weight: float
    issue_count: int
    description: str

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


def _is_blank(series: pd.Series) -> pd.Series:
    return series.isna() | series.astype("string").fillna("").str.strip().eq("")


def _safe_score(bad: int, total: int) -> float:
    if total <= 0:
        return 100.0
    return round(max(0.0, min(100.0, 100.0 * (1.0 - bad / total))), 1)


def _dimension(name: str, bad: int, total: int, weight: float, description: str) -> QualityDimension:
    return QualityDimension(name, _safe_score(bad, total), weight, int(bad), description)


def profile_dataframe(df: pd.DataFrame) -> dict[str, Any]:
    """Return a non-mutating quality profile for *df*.

    The score is intentionally conservative and explainable. It measures
    completeness, uniqueness, validity, and consistency from information that
    can be inferred without guessing business rules. Domain-specific checks
    can be layered on later.
    """
    if not isinstance(df, pd.DataFrame):
        raise TypeError("df must be a pandas DataFrame")

    frame = df.copy(deep=False)
    rows = len(frame)
    columns = len(frame.columns)
    cells = rows * columns

    missing_cells = int(sum(_is_blank(frame[c]).sum() for c in frame.columns)) if columns else 0
    duplicate_rows = int(frame.duplicated(keep=False).sum()) if rows else 0

    validity_bad = 0
    column_stats: list[dict[str, Any]] = []
    for column in frame.columns:
        s = frame[column]
        blank = int(_is_blank(s).sum())
        nonblank = s[~_is_blank(s)]
        unique = int(nonblank.nunique(dropna=True))
        duplicate_values = max(0, len(nonblank) - unique)
        validity_bad += duplicate_values
        column_stats.append(
            {
                "column": str(column),
                "type": str(s.dtype),
                "rows": rows,
                "missing": blank,
                "missingPercent": round(100.0 * blank / rows, 1) if rows else 0.0,
                "unique": unique,
                "uniquePercent": round(100.0 * unique / len(nonblank), 1) if len(nonblank) else 0.0,
            }
        )

    dimensions = [
        _dimension("Completeness", missing_cells, cells, 0.40, "Percentage of populated cells."),
        _dimension("Uniqueness", duplicate_rows, rows, 0.25, "Penalty for complete duplicate records."),
        _dimension("Consistency", validity_bad, max(1, rows * max(1, columns)), 0.20, "Penalty for repeated values across populated fields."),
        _dimension("Validity", 0, max(1, cells), 0.15, "No domain-specific invalid values are assumed without a schema rule."),
    ]

    score = round(sum(d.score * d.weight for d in dimensions), 1)
    if score >= 95:
        grade = "Excellent"
    elif score >= 85:
        grade = "Good"
    elif score >= 70:
        grade = "Needs attention"
    else:
        grade = "Poor"

    return {
        "score": score,
        "grade": grade,
        "rows": rows,
        "columns": columns,
        "missingCells": missing_cells,
        "duplicateRows": duplicate_rows,
        "dimensions": [d.as_dict() for d in dimensions],
        "columnStats": column_stats,
    }
