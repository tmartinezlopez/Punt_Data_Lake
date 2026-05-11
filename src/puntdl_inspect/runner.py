"""Carga un .sql parametrizado del catálogo y lo ejecuta contra Postgres."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pandas as pd
from sqlalchemy import text

from .db import readonly_connection

SQL_ROOT = Path(__file__).resolve().parents[2] / "consultas_SQL" / "inspect"


def resolve_sql_path(category: str, name: str) -> Path:
    path = SQL_ROOT / category / f"{name}.sql"
    if not path.is_file():
        raise FileNotFoundError(f"No existe el script SQL: {path}")
    return path


def run_sql(category: str, name: str, params: dict[str, Any] | None = None) -> pd.DataFrame:
    """Ejecuta `consultas_SQL/inspect/<category>/<name>.sql` con `params`."""
    sql_path = resolve_sql_path(category, name)
    sql = sql_path.read_text(encoding="utf-8")
    with readonly_connection() as conn:
        result = conn.execute(text(sql), params or {})
        rows = result.fetchall()
        columns = list(result.keys())
    return pd.DataFrame(rows, columns=columns)
