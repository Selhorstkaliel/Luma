# SPDX-License-Identifier: GPL-2.0-or-later
"""Módulo `ui` do Lume 0.1: janelas simples em coluna, sobre PySide6.QtWidgets.

    let w = ui.window("Título")
    let l = w.label("texto")
    w.button("Clique", fn_sem_argumentos)
    let campo = w.input("dica")      # campo.text() devolve o texto
    w.show()
    ui.run()

Com LUME_UI_SEM_LOOP=1, ui.run() volta na hora (testes automáticos, sem tela).
"""
from __future__ import annotations

import os
import sys

try:
    from PySide6.QtWidgets import QApplication, QLabel, QLineEdit, QPushButton, QVBoxLayout, QWidget
except ImportError as e:  # pragma: no cover - depende do sistema
    raise ImportError("o módulo ui do Lume precisa do PySide6 (no Fedora/Luma: python3-pyside6)") from e

from .core import to_str

windows: list = []   # janelas criadas, na ordem (usado pelos testes)
_app = None


def _application():
    global _app
    if _app is None:
        _app = QApplication.instance() or QApplication(sys.argv[:1])
    return _app


class Label:
    def __init__(self, widget: QLabel):
        self._w = widget

    def set_text(self, value) -> None:
        self._w.setText(to_str(value))

    def text(self) -> str:
        return self._w.text()


class Input:
    def __init__(self, widget: QLineEdit):
        self._w = widget

    def text(self) -> str:
        return self._w.text()

    def set_text(self, value) -> None:
        self._w.setText(to_str(value))


class Window:
    def __init__(self, title):
        _application()
        self._w = QWidget()
        self._w.setWindowTitle(to_str(title))
        self._layout = QVBoxLayout(self._w)
        self.buttons: list[QPushButton] = []
        windows.append(self)

    def label(self, text) -> Label:
        w = QLabel(to_str(text))
        self._layout.addWidget(w)
        return Label(w)

    def button(self, text, on_click=None) -> QPushButton:
        b = QPushButton(to_str(text))
        if on_click is not None:
            b.clicked.connect(lambda _checked=False: on_click())
        self._layout.addWidget(b)
        self.buttons.append(b)
        return b

    def input(self, placeholder="") -> Input:
        w = QLineEdit()
        w.setPlaceholderText(to_str(placeholder))
        self._layout.addWidget(w)
        return Input(w)

    def show(self) -> None:
        self._w.show()


def window(title) -> Window:
    return Window(title)


def run() -> int:
    if os.environ.get("LUME_UI_SEM_LOOP") == "1":
        return 0
    return _application().exec()
