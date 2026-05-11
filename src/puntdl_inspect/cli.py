"""CLI puntdl-inspect (Fase 1: comandos de introspección de esquema)."""

from __future__ import annotations

import typer

from .formats import Format, render
from .runner import run_sql

app = typer.Typer(
    name="puntdl",
    help="Toolkit read-only de inspección de la BBDD del Punt Data Lake.",
    no_args_is_help=True,
)

inspect_app = typer.Typer(name="inspect", help="Comandos de inspección.", no_args_is_help=True)
schema_app = typer.Typer(name="schema", help="Introspección del esquema Odoo.", no_args_is_help=True)

app.add_typer(inspect_app, name="inspect")
inspect_app.add_typer(schema_app, name="schema")


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


if __name__ == "__main__":
    app()
