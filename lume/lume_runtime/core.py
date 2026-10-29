# SPDX-License-Identifier: GPL-2.0-or-later
"""Embutidos do Lume que não são Python puro: texto dos valores, print, range e o módulo ui (preguiçoso)."""
from __future__ import annotations


def to_str(v) -> str:
    if v is True:
        return "true"
    if v is False:
        return "false"
    if v is None:
        return "nil"
    if isinstance(v, list):
        return "[" + ", ".join(f'"{x}"' if isinstance(x, str) else to_str(x) for x in v) + "]"
    if isinstance(v, float) and v.is_integer():
        return str(v)
    return str(v)


def show(*values) -> None:
    print(" ".join(to_str(v) for v in values))


def lrange(*args) -> list:
    return list(range(*args))


_ui = None


def ui():
    """Importa a interface (PySide6) só quando o programa usa `ui`: programas sem janela não dependem de Qt."""
    global _ui
    if _ui is None:
        from . import ui as module
        _ui = module
    return _ui
