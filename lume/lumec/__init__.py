# SPDX-License-Identifier: GPL-2.0-or-later
"""lumec: compilador da linguagem Lume (0.1). Traduz Lume para Python que usa o lume_runtime (decisão 0013)."""
__version__ = "0.1.0"


class LumeError(Exception):
    """Erro de compilação com posição no arquivo Lume."""

    def __init__(self, message: str, line: int, col: int):
        super().__init__(message)
        self.message, self.line, self.col = message, line, col

    def format(self, filename: str) -> str:
        return f"{filename}:{self.line}:{self.col}: erro: {self.message}"
