import json
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SQL_LOAD = ROOT / "database" / "sql" / "warehouse" / "warehouse_hu_v1_load.sql"


def env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def run_psql_file(sql_path: Path) -> None:
    psql = os.getenv("PSQL_PATH", r"C:\Program Files\PostgreSQL\17\bin\psql.exe")
    cmd = [
        psql,
        "-h",
        env("PGHOST", "localhost"),
        "-p",
        env("PGPORT", "5432"),
        "-U",
        env("PGUSER", "postgres"),
        "-d",
        env("PGDATABASE", "PUNT_SISTEMES_PRO"),
        "-v",
        "ON_ERROR_STOP=1",
        "-f",
        str(sql_path),
    ]
    subprocess.run(cmd, check=True)


def query_scalar(sql: str) -> str:
    psql = os.getenv("PSQL_PATH", r"C:\Program Files\PostgreSQL\17\bin\psql.exe")
    cmd = [
        psql,
        "-h",
        env("PGHOST", "localhost"),
        "-p",
        env("PGPORT", "5432"),
        "-U",
        env("PGUSER", "postgres"),
        "-d",
        env("PGDATABASE", "PUNT_SISTEMES_PRO"),
        "-At",
        "-c",
        sql,
    ]
    res = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return (res.stdout or "").strip()


def run_full_load() -> dict:
    t0 = time.time()
    run_psql_file(SQL_LOAD)
    elapsed = round(time.time() - t0, 3)
    group_count = query_scalar("SELECT COUNT(*) FROM analytics.wh_hu_group;")
    node_count = query_scalar("SELECT COUNT(*) FROM analytics.wh_hu_node;")
    return {
        "mode": "full",
        "elapsed_seconds": elapsed,
        "wh_hu_group_rows": int(group_count or 0),
        "wh_hu_node_rows": int(node_count or 0),
        "sql_file": str(SQL_LOAD),
    }


if __name__ == "__main__":
    result = run_full_load()
    print(json.dumps(result, ensure_ascii=True))
