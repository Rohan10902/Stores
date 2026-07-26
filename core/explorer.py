import re
import duckdb
def run_sql(df,q):
    q=q.strip()
    if not re.match(r"^(select|with)\b",q,re.I): raise ValueError("Only read-only SELECT/WITH SQL is allowed.")
    if re.search(r"\b(insert|update|delete|drop|alter|create|attach|detach|copy|install|load|pragma|replace|vacuum)\b",q,re.I): raise ValueError("Only read-only SQL is allowed.")
    con=duckdb.connect(database=":memory:")
    try:
        con.register("data",df)
        return con.execute(q).fetchdf()
    finally: con.close()
