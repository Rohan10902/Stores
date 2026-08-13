import re

import duckdb
import pandas as pd

_DENY = re.compile(r"\b(insert|update|delete|drop|alter|create|attach|detach|copy|install|load|pragma|replace|vacuum|call|export|import|execute|transaction)\b", re.I)
_TRUE = {"true", "yes", "y"}
_FALSE = {"false", "no", "n"}
_IDENTIFIER = re.compile(r"(^|\b)(sid|id|code|zip|postal|postcode|pincode|pin)(\b|$)", re.I)
MAX_QUERY_LENGTH = 50_000
MAX_RESULT_ROWS = 200_000


def _blank(s):
    return s.isna() | s.astype(str).str.strip().eq("")


def _typed(s, name=""):
    blank = _blank(s)
    clean = s[~blank]
    if clean.empty:
        return s.map(lambda _: None), "VARCHAR"
    text = clean.astype(str).str.strip()
    if _IDENTIFIER.search(str(name)):
        return s.map(lambda v: None if pd.isna(v) or str(v).strip() == "" else str(v).strip()), "VARCHAR"
    low = set(text.str.lower().unique())
    if low and low.issubset(_TRUE | _FALSE):
        x = s.astype(str).str.strip().str.lower().map(lambda v: True if v in _TRUE else False if v in _FALSE else None)
        return x.astype("boolean"), "BOOLEAN"
    n = pd.to_numeric(text, errors="coerce")
    if n.notna().all():
        full = pd.to_numeric(s.where(~blank, None), errors="coerce")
        z = full.dropna()
        if len(z) and ((z % 1) == 0).all():
            return full.astype("Int64"), "BIGINT"
        return full.astype("Float64"), "DOUBLE"
    if text.str.contains(r"[-/:]|[A-Za-z]{3,}", regex=True).mean() >= .80:
        d = pd.to_datetime(text, errors="coerce")
        if d.notna().all():
            return pd.to_datetime(s.where(~blank, None), errors="coerce"), "TIMESTAMP"
    return s.map(lambda v: None if pd.isna(v) or str(v).strip() == "" else str(v)), "VARCHAR"


def prepare_for_sql(df):
    typed = pd.DataFrame(index=df.index)
    schema = {}
    for column in df.columns:
        typed[column], schema[str(column)] = _typed(df[column], str(column))
    return typed, schema


def run_sql(df, q):
    if df is None:
        raise ValueError("Load a dataset before running SQL.")
    q = str(q or "").strip()
    if not q:
        raise ValueError("SQL query cannot be empty.")
    if len(q) > MAX_QUERY_LENGTH:
        raise ValueError(f"SQL query exceeds the {MAX_QUERY_LENGTH:,}-character limit.")
    if not re.match(r"^(select|with)\b", q, re.I):
        raise ValueError("Only read-only SELECT/WITH SQL is allowed.")
    if _DENY.search(q):
        raise ValueError("Only read-only SQL is allowed.")
    if ";" in q.rstrip(";"):
        raise ValueError("Only one SQL statement is allowed.")

    typed, _ = prepare_for_sql(df)
    con = duckdb.connect(database=":memory:", config={"memory_limit": "512MB", "threads": "2"})
    try:
        con.register("data", typed)
        result = con.execute(q).fetchdf()
        if len(result) > MAX_RESULT_ROWS:
            raise ValueError(f"Query returned {len(result):,} rows; the maximum result size is {MAX_RESULT_ROWS:,} rows.")
        return result
    finally:
        con.close()
