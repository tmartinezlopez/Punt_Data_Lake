"""Renderizado de DataFrames a varios formatos para la CLI."""

from __future__ import annotations

import sys
from typing import Literal

import pandas as pd
from rich.console import Console
from rich.table import Table

Format = Literal["table", "md", "csv", "json"]

_console = Console()


def render(df: pd.DataFrame, fmt: Format = "table", title: str | None = None) -> None:
    if df.empty:
        _console.print(f"[yellow]Sin resultados[/yellow]" + (f" — {title}" if title else ""))
        return

    if fmt == "csv":
        df.to_csv(sys.stdout, index=False)
        return
    if fmt == "json":
        df.to_json(sys.stdout, orient="records", date_format="iso", indent=2)
        sys.stdout.write("\n")
        return
    if fmt == "md":
        sys.stdout.write(df.to_markdown(index=False) + "\n")
        return

    table = Table(title=title, show_lines=False, header_style="bold cyan")
    for col in df.columns:
        table.add_column(str(col))
    for _, row in df.iterrows():
        table.add_row(*[("" if pd.isna(v) else str(v)) for v in row])
    _console.print(table)
