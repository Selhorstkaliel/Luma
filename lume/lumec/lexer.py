# SPDX-License-Identifier: GPL-2.0-or-later
"""Analisador léxico do Lume: texto -> tokens com linha e coluna (1-based)."""
from __future__ import annotations

from dataclasses import dataclass

from . import LumeError

KEYWORDS = {"let", "fn", "return", "if", "else", "while", "for", "in", "true", "false", "nil", "and", "or", "not"}
# Ordem importa: operadores de dois caracteres antes dos de um
OPERATORS = ["==", "!=", "<=", ">=", "(", ")", "{", "}", "[", "]", ",", ".", "=", "<", ">", "+", "-", "*", "/", "%"]
ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}


@dataclass(frozen=True)
class Token:
    kind: str    # NUMBER, STRING, IDENT, KEYWORD, OP, NEWLINE, EOF
    value: object
    line: int
    col: int


def tokenize(src: str) -> list[Token]:
    tokens: list[Token] = []
    i, line, col = 0, 1, 1
    depth = 0  # dentro de () ou [] a quebra de linha não termina instrução

    def add(kind, value, at_line, at_col):
        tokens.append(Token(kind, value, at_line, at_col))

    while i < len(src):
        ch = src[i]
        if ch == "#":
            while i < len(src) and src[i] != "\n":
                i += 1
            continue
        if ch == "\n":
            if depth == 0 and tokens and tokens[-1].kind != "NEWLINE":
                add("NEWLINE", None, line, col)
            i += 1
            line += 1
            col = 1
            continue
        if ch in " \t\r":
            i += 1
            col += 1
            continue
        start_col = col
        if ch.isdigit():
            j = i
            while j < len(src) and src[j].isdigit():
                j += 1
            is_float = j + 1 < len(src) and src[j] == "." and src[j + 1].isdigit()
            if is_float:
                j += 1
                while j < len(src) and src[j].isdigit():
                    j += 1
            text = src[i:j]
            add("NUMBER", float(text) if is_float else int(text), line, start_col)
            col += j - i
            i = j
            continue
        if ch.isalpha() or ch == "_":
            j = i
            while j < len(src) and (src[j].isalnum() or src[j] == "_"):
                j += 1
            word = src[i:j]
            add("KEYWORD" if word in KEYWORDS else "IDENT", word, line, start_col)
            col += j - i
            i = j
            continue
        if ch == '"':
            j, out = i + 1, []
            while True:
                if j >= len(src) or src[j] == "\n":
                    raise LumeError("texto sem aspas de fechamento", line, start_col)
                c = src[j]
                if c == '"':
                    break
                if c == "\\":
                    nxt = src[j + 1] if j + 1 < len(src) else ""
                    if nxt not in ESCAPES:
                        raise LumeError(f"escape desconhecido: \\{nxt}", line, col + (j - i))
                    out.append(ESCAPES[nxt])
                    j += 2
                    continue
                out.append(c)
                j += 1
            add("STRING", "".join(out), line, start_col)
            col += j + 1 - i
            i = j + 1
            continue
        for op in OPERATORS:
            if src.startswith(op, i):
                if op in "([":
                    depth += 1
                elif op in ")]":
                    depth = max(0, depth - 1)
                add("OP", op, line, start_col)
                i += len(op)
                col += len(op)
                break
        else:
            raise LumeError(f"caractere inesperado: {ch!r}", line, col)
    if tokens and tokens[-1].kind != "NEWLINE":
        add("NEWLINE", None, line, col)
    add("EOF", None, line, col)
    return tokens
