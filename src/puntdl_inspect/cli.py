"""CLI puntdl-inspect (Fases 1-2: schema / quality / profile)."""

from __future__ import annotations

import typer

from .formats import Format, render
from .runner import (
    InvalidIdentifierError,
    join_identifiers,
    list_table_columns,
    quote_ident,
    resolve_fk_target,
    run_sql,
)

app = typer.Typer(
    name="puntdl",
    help="Toolkit read-only de inspección de la BBDD del Punt Data Lake.",
    no_args_is_help=True,
)

inspect_app = typer.Typer(name="inspect", help="Comandos de inspección.", no_args_is_help=True)
schema_app = typer.Typer(name="schema", help="Introspección del esquema Odoo.", no_args_is_help=True)
quality_app = typer.Typer(name="quality", help="Calidad de datos (orphans, duplicados, nulls).", no_args_is_help=True)
profile_app = typer.Typer(name="profile", help="Perfilado de columnas (column, text, dates).", no_args_is_help=True)

app.add_typer(inspect_app, name="inspect")
inspect_app.add_typer(schema_app, name="schema")
inspect_app.add_typer(quality_app, name="quality")
inspect_app.add_typer(profile_app, name="profile")


def _idents(**kwargs: str) -> dict[str, str]:
    """Cita cada valor; convierte errores de validación en BadParameter."""
    try:
        return {k: quote_ident(v) for k, v in kwargs.items() if v is not None}
    except InvalidIdentifierError as e:
        raise typer.BadParameter(str(e)) from e


FormatOpt = typer.Option("table", "--format", "-f", help="table | md | csv | json")
LimitOpt = typer.Option(50, "--limit", "-n", min=1, help="Máximo de filas a mostrar.")


@schema_app.command("tables")
def schema_tables(
    like: str = typer.Option("%", "--like", help="Patrón LIKE para nombre de tabla."),
    schema: str = typer.Option("public", "--schema", help="Esquema a inspeccionar."),
    with_size: bool = typer.Option(False, "--with-size", help="Incluir tamaño en disco."),
    non_empty: bool = typer.Option(False, "--non-empty", help="Solo tablas con filas (estimadas)."),
    limit: int = LimitOpt,
    fmt: Format = FormatOpt,
) -> None:
    """Lista tablas del esquema indicado con conteo estimado y opcionalmente tamaño."""
    df = run_sql(
        "schema",
        "tables",
        {
            "like": like,
            "schema": schema,
            "with_size": with_size,
            "non_empty": non_empty,
            "limit": limit,
        },
    )
    render(df, fmt=fmt, title=f"tables in {schema} LIKE {like}")


@schema_app.command("columns")
def schema_columns(
    table: str = typer.Option(..., "--table", help="Tabla a inspeccionar."),
    schema: str = typer.Option("public", "--schema"),
    only_used: bool = typer.Option(False, "--only-used", help="Solo columnas con >0 valores no nulos."),
    fmt: Format = FormatOpt,
) -> None:
    """Columnas de una tabla con tipo, nullable, default y (opcional) % no nulos."""
    df = run_sql(
        "schema",
        "columns",
        {"table": table, "schema": schema, "only_used": only_used},
    )
    render(df, fmt=fmt, title=f"{schema}.{table} columns")


@schema_app.command("fks")
def schema_fks(
    table: str = typer.Option(..., "--table"),
    schema: str = typer.Option("public", "--schema"),
    direction: str = typer.Option("both", "--direction", help="outbound | inbound | both"),
    fmt: Format = FormatOpt,
) -> None:
    """Foreign keys salientes y/o entrantes para una tabla."""
    df = run_sql(
        "schema",
        "fks",
        {"table": table, "schema": schema, "direction": direction},
    )
    render(df, fmt=fmt, title=f"FKs of {schema}.{table} ({direction})")


@schema_app.command("odoo-models")
def schema_odoo_models(
    like: str = typer.Option("%", "--like", help="Patrón LIKE sobre ir_model.model."),
    limit: int = LimitOpt,
    fmt: Format = FormatOpt,
) -> None:
    """Cruza pg_catalog con ir_model/ir_module_module para mapear tablas a modelos Odoo."""
    df = run_sql("schema", "odoo_models", {"like": like, "limit": limit})
    render(df, fmt=fmt, title=f"Odoo models LIKE {like}")


# ---------- quality ----------


@quality_app.command("orphans")
def quality_orphans(
    table: str = typer.Option(..., "--table"),
    column: str = typer.Option(..., "--column", "--fk", help="Columna FK a auditar."),
    schema: str = typer.Option("public", "--schema"),
    ref_table: str = typer.Option(None, "--ref-table", help="Tabla destino; autodetectado si se omite."),
    ref_column: str = typer.Option(None, "--ref-column", help="Columna destino; autodetectado si se omite."),
    ref_schema: str = typer.Option(None, "--ref-schema", help="Esquema destino; autodetectado si se omite."),
    sample: int = typer.Option(10, "--sample", min=1, help="Muestra de huérfanos a mostrar."),
    fmt: Format = FormatOpt,
) -> None:
    """Filas con FK colgante (valor no encontrado en la tabla referenciada)."""
    if not (ref_table and ref_column):
        try:
            r_schema, r_table, r_col = resolve_fk_target(schema, table, column)
        except ValueError as e:
            raise typer.BadParameter(str(e)) from e
        ref_schema = ref_schema or r_schema
        ref_table = ref_table or r_table
        ref_column = ref_column or r_col
    df = run_sql(
        "quality",
        "orphans",
        {"sample": sample},
        identifiers=_idents(
            schema=schema, table=table, column=column,
            ref_schema=ref_schema, ref_table=ref_table, ref_column=ref_column,
        ),
    )
    render(df, fmt=fmt, title=f"orphans of {schema}.{table}.{column} → {ref_schema}.{ref_table}.{ref_column}")


@quality_app.command("duplicates")
def quality_duplicates(
    table: str = typer.Option(..., "--table"),
    by: list[str] = typer.Option(..., "--by", help="Columna(s) por las que agrupar. Repetir para varias."),
    schema: str = typer.Option("public", "--schema"),
    min_count: int = typer.Option(2, "--min-count", min=2),
    limit: int = LimitOpt,
    fmt: Format = FormatOpt,
) -> None:
    """Combinaciones de columnas con >= min_count ocurrencias."""
    try:
        by_cols = join_identifiers(by)
    except InvalidIdentifierError as e:
        raise typer.BadParameter(str(e)) from e
    df = run_sql(
        "quality",
        "duplicates",
        {"min_count": min_count, "limit": limit},
        identifiers={**_idents(schema=schema, table=table), "by_cols": by_cols},
    )
    render(df, fmt=fmt, title=f"duplicates in {schema}.{table} BY {', '.join(by)}")


@quality_app.command("nulls")
def quality_nulls(
    table: str = typer.Option(..., "--table"),
    schema: str = typer.Option("public", "--schema"),
    threshold: float = typer.Option(0.0, "--threshold", min=0.0, max=1.0),
    fmt: Format = FormatOpt,
) -> None:
    """Fracción exacta de NULLs por columna (1 seq scan)."""
    cols = list_table_columns(schema, table)
    if not cols:
        raise typer.BadParameter(f"No se encontraron columnas en {schema}.{table}.")
    aggregates = ",\n           ".join(
        f'count(*) FILTER (WHERE {quote_ident(c)} IS NULL) AS {quote_ident(c)}'
        for c, _ in cols
    )
    df = run_sql(
        "quality",
        "nulls",
        {"threshold": threshold},
        identifiers={
            **_idents(schema=schema, table=table),
            "col_aggregates": aggregates,
        },
    )
    render(df, fmt=fmt, title=f"nulls in {schema}.{table} (threshold ≥ {threshold})")


# ---------- profile ----------


@profile_app.command("column")
def profile_column(
    table: str = typer.Option(..., "--table"),
    column: str = typer.Option(..., "--column"),
    schema: str = typer.Option("public", "--schema"),
    top_n: int = typer.Option(10, "--top-n", min=1),
    fmt: Format = FormatOpt,
) -> None:
    """Resumen (total, NULLs, distintos) + top-N valores de una columna."""
    df = run_sql(
        "profile",
        "column",
        {"top_n": top_n},
        identifiers=_idents(schema=schema, table=table, column=column),
    )
    render(df, fmt=fmt, title=f"{schema}.{table}.{column} profile")


@profile_app.command("text")
def profile_text(
    table: str = typer.Option(..., "--table"),
    column: str = typer.Option(..., "--column"),
    schema: str = typer.Option("public", "--schema"),
    fmt: Format = FormatOpt,
) -> None:
    """Calidad de campo textual: longitudes, vacíos, HTML, heurísticas GWT."""
    df = run_sql(
        "profile",
        "text",
        identifiers=_idents(schema=schema, table=table, column=column),
    )
    render(df, fmt=fmt, title=f"{schema}.{table}.{column} text quality")


_BUCKETS = {"day", "week", "month", "quarter", "year"}


@profile_app.command("dates")
def profile_dates(
    table: str = typer.Option(..., "--table"),
    column: str = typer.Option(..., "--column"),
    schema: str = typer.Option("public", "--schema"),
    bucket: str = typer.Option("month", "--bucket", help="day | week | month | quarter | year"),
    limit: int = typer.Option(60, "--limit", "-n", min=1),
    fmt: Format = FormatOpt,
) -> None:
    """Distribución temporal de una columna fecha/timestamp por bucket."""
    if bucket not in _BUCKETS:
        raise typer.BadParameter(f"--bucket debe ser uno de {sorted(_BUCKETS)}")
    df = run_sql(
        "profile",
        "dates",
        {"bucket": bucket, "limit": limit},
        identifiers=_idents(schema=schema, table=table, column=column),
    )
    render(df, fmt=fmt, title=f"{schema}.{table}.{column} by {bucket}")


if __name__ == "__main__":
    app()
