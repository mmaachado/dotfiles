"""Console output helpers."""

from __future__ import annotations

import typer
from rich.console import Console
from rich.table import Table

console = Console()

OK = "[green]✔[/]"
WARN = "[yellow]![/]"
BAD = "[red]✘[/]"


def mark(ok: bool, warn_only: bool = False) -> str:
    return OK if ok else (WARN if warn_only else BAD)


def table(title: str) -> Table:
    t = Table(title=title, title_justify="left", title_style="bold", show_header=False,
              box=None, padding=(0, 2))
    t.add_column(width=1)
    t.add_column(style="bold")
    t.add_column()
    return t


def step(title: str) -> None:
    console.rule(f"[bold]{title}", align="left")


def confirm(question: str, yes: bool) -> bool:
    return yes or typer.confirm(question, default=True)
