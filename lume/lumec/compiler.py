# SPDX-License-Identifier: GPL-2.0-or-later
"""Pipeline do lumec: texto Lume -> (código Python, mapa de linhas)."""
from __future__ import annotations

from . import __version__
from .check import check
from .codegen import CodeGen
from .parser import parse


def compile_source(src: str, source_name: str = "<lume>") -> tuple[str, dict[int, int]]:
    prog = parse(src)
    checker = check(prog)
    gen = CodeGen(checker, source_name, __version__)
    return gen.program(prog), gen.line_map
