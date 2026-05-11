"""Carga un .sql parametrizado del catálogo y lo ejecuta contra Postgres.

Soporta dos tipos de parámetros:

- **Valores** (`:nombre`): pasados como bind params a SQLAlchemy `text()`. Seguros
  por construcción (no se interpolan en la SQL).
- **Identificadores** (`{{nombre}}`): nombres de esquema/tabla/columna. No se
  pueden pasar como bind params. Se validan contra una regex estricta y se
  citan con `"..."` antes de la sustitución textual en la SQL.

Para listas de identificadores (p.ej. columnas separadas por coma) usar
``join_identifiers``.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Iterable

import pandas as pd
from sqlalchemy import text

from .db import readonly_connection

SQL_ROOT = Path(__file__).resolve().parents[2] / "consultas_SQL" / "inspect"

# Identificadores admitidos: minúsculas, dígitos y _; comienzo no numérico.
# Cubre 100% de los nombres usados por Odoo y deja fuera espacios, comillas,
# puntos y caracteres no ASCII (que requerirían escapado adicional).
_IDENT_RE = re.compile(r"^[a-z_][a-z0-9_]{0,62}$")


class InvalidIdentifierError(ValueError):
    """Identificador no válido para sustitución en SQL."""


def quote_ident(name: str) -> str:
    """Valida `name` contra la regex y lo devuelve entre comillas dobles."""
    if not isinstance(name, str) or not _IDENT_RE.match(name):
        raise InvalidIdentifierError(
            f"Identificador no válido: {name!r}. "
            "Solo se admite ^[a-z_][a-z0-9_]{0,62}$."
        )
    return f'"{name}"'


def join_identifiers(names: Iterable[str], sep: str = ", ") -> str:
    """Cita y une una secuencia de identificadores."""
    return sep.join(quote_ident(n) for n in names)


def resolve_sql_path(category: str, name: str) -> Path:
    path = SQL_ROOT / category / f"{name}.sql"
    if not path.is_file():
        raise FileNotFoundError(f"No existe el script SQL: {path}")
    return path


_PLACEHOLDER_RE = re.compile(r"\{\{\s*(\w+)\s*\}\}")


def _substitute_identifiers(sql: str, identifiers: dict[str, str]) -> str:
    """Sustituye `{{name}}` por el valor de `identifiers[name]`.

    Ignora líneas que empiezan por `--` (comentarios de línea SQL) para que
    la documentación dentro del `.sql` pueda mencionar los placeholders sin
    riesgo de que la sustitución (potencialmente multilínea) rompa la SQL.
    Los comentarios `/* ... */` no se procesan especialmente; si se usan, no
    incluir placeholders dentro.
    """

    def repl(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in identifiers:
            raise KeyError(f"Falta identificador para {{{{ {key} }}}}")
        return identifiers[key]

    out_lines: list[str] = []
    for line in sql.splitlines(keepends=True):
        if line.lstrip().startswith("--"):
            out_lines.append(line)
        else:
            out_lines.append(_PLACEHOLDER_RE.sub(repl, line))
    return "".join(out_lines)


def run_sql(
    category: str,
    name: str,
    params: dict[str, Any] | None = None,
    identifiers: dict[str, str] | None = None,
) -> pd.DataFrame:
    """Ejecuta `consultas_SQL/inspect/<category>/<name>.sql`.

    Args:
        params: bind params `:nombre` (valores).
        identifiers: pares `nombre -> identificador_ya_citado` para
            placeholders `{{nombre}}`. Usar :func:`quote_ident` o
            :func:`join_identifiers` para construirlos.
    """
    sql_path = resolve_sql_path(category, name)
    sql = sql_path.read_text(encoding="utf-8")
    if identifiers:
        sql = _substitute_identifiers(sql, identifiers)
    with readonly_connection() as conn:
        result = conn.execute(text(sql), params or {})
        rows = result.fetchall()
        columns = list(result.keys())
    return pd.DataFrame(rows, columns=columns)


def run_inline(sql: str, params: dict[str, Any] | None = None) -> pd.DataFrame:
    """Ejecuta SQL ad-hoc (sin fichero). Útil para meta-consultas internas."""
    with readonly_connection() as conn:
        result = conn.execute(text(sql), params or {})
        rows = result.fetchall()
        columns = list(result.keys())
    return pd.DataFrame(rows, columns=columns)


def list_table_columns(schema: str, table: str) -> list[tuple[str, str]]:
    """Devuelve `[(column, type), ...]` para una tabla, ordenado por attnum."""
    df = run_inline(
        """
        SELECT a.attname AS column, format_type(a.atttypid, a.atttypmod) AS type
        FROM pg_attribute a
        JOIN pg_class c     ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = :schema
          AND c.relname = :table
          AND a.attnum > 0
          AND NOT a.attisdropped
        ORDER BY a.attnum
        """,
        {"schema": schema, "table": table},
    )
    return list(zip(df["column"], df["type"]))


def resolve_fk_target(schema: str, table: str, column: str) -> tuple[str, str, str]:
    """Devuelve `(ref_schema, ref_table, ref_column)` para una FK declarada.

    Soporta solo FKs simples (una columna). Lanza ValueError si no existe FK
    sobre `column` o si es compuesta.
    """
    df = run_inline(
        """
        SELECT fns.nspname AS ref_schema,
               fcl.relname AS ref_table,
               fatt.attname AS ref_column,
               cardinality(c.conkey) AS k
        FROM pg_constraint c
        JOIN pg_class cl       ON cl.oid = c.conrelid
        JOIN pg_namespace ns   ON ns.oid = cl.relnamespace
        JOIN pg_class fcl      ON fcl.oid = c.confrelid
        JOIN pg_namespace fns  ON fns.oid = fcl.relnamespace
        JOIN unnest(c.conkey, c.confkey) WITH ORDINALITY AS k(conkey, confkey, ord) ON TRUE
        JOIN pg_attribute att  ON att.attrelid = c.conrelid  AND att.attnum  = k.conkey
        JOIN pg_attribute fatt ON fatt.attrelid = c.confrelid AND fatt.attnum = k.confkey
        WHERE c.contype = 'f'
          AND ns.nspname = :schema
          AND cl.relname = :table
          AND att.attname = :column
        """,
        {"schema": schema, "table": table, "column": column},
    )
    if df.empty:
        raise ValueError(
            f"No hay FK declarada sobre {schema}.{table}.{column}. "
            "Pasa --ref-table/--ref-column manualmente."
        )
    if len(df) > 1:
        raise ValueError(
            f"FK compuesta sobre {schema}.{table}.{column}; no soportado en v1."
        )
    row = df.iloc[0]
    return (row["ref_schema"], row["ref_table"], row["ref_column"])
