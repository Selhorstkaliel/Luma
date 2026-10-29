# SPDX-License-Identifier: GPL-2.0-or-later
"""Linha de comando: lumec check|build|run ARQUIVO.lume"""
from __future__ import annotations

import argparse
import sys
import traceback
from pathlib import Path

from . import LumeError, __version__
from .compiler import compile_source


def run_python(code: str, line_map: dict[int, int], lume_file: str) -> int:
    pyname = f"<lumec:{lume_file}>"
    try:
        exec(compile(code, pyname, "exec"), {"__name__": "__main__"})  # noqa: S102 — código gerado pelo lumec
    except SystemExit as e:
        return int(e.code or 0)
    except Exception as e:  # noqa: BLE001 — qualquer erro de execução vira mensagem com linha do .lume
        lume_line = None
        for frame in traceback.extract_tb(e.__traceback__):
            if frame.filename == pyname and frame.lineno in line_map:
                lume_line = line_map[frame.lineno]
        where = f"{lume_file}:{lume_line}" if lume_line else lume_file
        print(f"{where}: erro de execução: {type(e).__name__}: {e}", file=sys.stderr)
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="lumec", description="Compilador da linguagem Lume (traduz para Python)")
    ap.add_argument("--version", action="version", version=f"lumec {__version__}")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name, help_ in (("check", "só verifica o programa"), ("build", "gera o arquivo .py"),
                        ("run", "compila e executa")):
        p = sub.add_parser(name, help=help_)
        p.add_argument("arquivo")
        if name == "build":
            p.add_argument("-o", "--saida", help="arquivo .py de saída (padrão: mesmo nome)")
    args = ap.parse_args(argv)

    path = Path(args.arquivo)
    try:
        src = path.read_text(encoding="utf-8")
    except OSError as e:
        print(f"lumec: não foi possível ler {path}: {e.strerror}", file=sys.stderr)
        return 2
    try:
        code, line_map = compile_source(src, path.name)
    except LumeError as e:
        print(e.format(str(path)), file=sys.stderr)
        return 1
    if args.cmd == "check":
        print(f"{path}: ok")
        return 0
    if args.cmd == "build":
        out = Path(args.saida) if args.saida else path.with_suffix(".py")
        out.write_text(code, encoding="utf-8")
        print(f"{path} -> {out}")
        return 0
    return run_python(code, line_map, str(path))
