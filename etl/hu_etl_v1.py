import json
import os
import subprocess
import time
import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SQL_LOAD_FULL = ROOT / "database" / "sql" / "warehouse" / "warehouse_hu_v1_load.sql"
SQL_LOAD_INCREMENTAL = ROOT / "database" / "sql" / "warehouse" / "warehouse_hu_v1_load_incremental.sql"
PROCESS_NAME = "hu_index_v1"


def env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def env_any(names: list[str], default: str | None = None) -> str:
    for n in names:
        value = os.getenv(n)
        if value is not None:
            return value
    if default is not None:
        return default
    raise RuntimeError(f"Missing required environment variable. Tried: {', '.join(names)}")


def run_psql_file(sql_path: Path, extra_vars: dict[str, str] | None = None) -> None:
    psql = os.getenv("PSQL_PATH", r"C:\Program Files\PostgreSQL\17\bin\psql.exe")
    cmd = [
        psql,
        "-h",
        env_any(["PGHOST", "POSTGRES_HOST"], "localhost"),
        "-p",
        env_any(["PGPORT", "POSTGRES_PORT"], "5432"),
        "-U",
        env_any(["PGUSER", "POSTGRES_USER"], "postgres"),
        "-d",
        env_any(["PGDATABASE", "POSTGRES_DB"], "PUNT_SISTEMES_PRO"),
        "-v",
        "ON_ERROR_STOP=1",
        "-f",
        str(sql_path),
    ]
    if extra_vars:
        for k, v in extra_vars.items():
            cmd.extend(["-v", f"{k}={v}"])
    subprocess.run(cmd, check=True)


def query_scalar(sql: str) -> str:
    psql = os.getenv("PSQL_PATH", r"C:\Program Files\PostgreSQL\17\bin\psql.exe")
    cmd = [
        psql,
        "-h",
        env_any(["PGHOST", "POSTGRES_HOST"], "localhost"),
        "-p",
        env_any(["PGPORT", "POSTGRES_PORT"], "5432"),
        "-U",
        env_any(["PGUSER", "POSTGRES_USER"], "postgres"),
        "-d",
        env_any(["PGDATABASE", "POSTGRES_DB"], "PUNT_SISTEMES_PRO"),
        "-At",
        "-c",
        sql,
    ]
    res = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return (res.stdout or "").strip()


def get_watermark() -> str:
    sql = f"""
    SELECT COALESCE(
        (SELECT last_max_write_date::text FROM analytics.wh_etl_watermark WHERE process_name = '{PROCESS_NAME}'),
        '1900-01-01 00:00:00'
    );
    """
    return query_scalar(sql)


def upsert_watermark(value: str) -> None:
    sql = f"""
    INSERT INTO analytics.wh_etl_watermark(process_name, last_max_write_date, updated_at)
    VALUES ('{PROCESS_NAME}', '{value}'::timestamp, NOW())
    ON CONFLICT (process_name) DO UPDATE SET
        last_max_write_date = EXCLUDED.last_max_write_date,
        updated_at = NOW();
    """
    _ = query_scalar(sql)


def get_max_source_write_date() -> str:
    return query_scalar("SELECT COALESCE(MAX(write_date)::text, '1900-01-01 00:00:00') FROM analytics.v_hu_raw;")


def run_full_load() -> dict:
    t0 = time.time()
    run_psql_file(SQL_LOAD_FULL)
    elapsed = round(time.time() - t0, 3)
    max_source_write_date = get_max_source_write_date()
    upsert_watermark(max_source_write_date)
    group_count = query_scalar("SELECT COUNT(*) FROM analytics.wh_hu_group;")
    node_count = query_scalar("SELECT COUNT(*) FROM analytics.wh_hu_node;")
    return {
        "mode": "full",
        "elapsed_seconds": elapsed,
        "wh_hu_group_rows": int(group_count or 0),
        "wh_hu_node_rows": int(node_count or 0),
        "watermark": max_source_write_date,
        "sql_file": str(SQL_LOAD_FULL),
    }


def run_incremental_load() -> dict:
    watermark = get_watermark()
    t0 = time.time()
    run_psql_file(SQL_LOAD_INCREMENTAL)
    elapsed = round(time.time() - t0, 3)
    max_source_write_date = get_max_source_write_date()
    upsert_watermark(max_source_write_date)
    group_count = query_scalar("SELECT COUNT(*) FROM analytics.wh_hu_group;")
    node_count = query_scalar("SELECT COUNT(*) FROM analytics.wh_hu_node;")
    return {
        "mode": "incremental",
        "elapsed_seconds": elapsed,
        "wh_hu_group_rows": int(group_count or 0),
        "wh_hu_node_rows": int(node_count or 0),
        "watermark_before": watermark,
        "watermark_after": max_source_write_date,
        "sql_file": str(SQL_LOAD_INCREMENTAL),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["full", "incremental"], default="full")
    args = parser.parse_args()

    result = run_full_load() if args.mode == "full" else run_incremental_load()
    print(json.dumps(result, ensure_ascii=True))
