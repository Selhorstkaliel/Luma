# SPDX-License-Identifier: GPL-2.0-or-later
"""Utilitários dos testes do Lume: põe lume/ no caminho de importação e executa código gerado."""
import contextlib
import io
import sys
from pathlib import Path

LUME = Path(__file__).resolve().parents[1]
if str(LUME) not in sys.path:
    sys.path.insert(0, str(LUME))

from lumec.compiler import compile_source  # noqa: E402


def run_lume(src: str) -> str:
    """Compila e executa um programa Lume sem interface; devolve o que ele imprimiu."""
    code, _ = compile_source(src, "teste.lume")
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        exec(compile(code, "<teste>", "exec"), {"__name__": "__main__"})  # noqa: S102
    return out.getvalue()
