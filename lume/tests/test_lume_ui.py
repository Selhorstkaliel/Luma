#!/usr/bin/env python3
"""Módulo ui do Lume sobre PySide6, sem tela (offscreen). Pulado se o PySide6 não estiver instalado.

No CI de imagem e no Luma o PySide6 existe (python3-pyside6, Fase 3); no runner Ubuntu do lint, não.
"""
import os
import unittest

from _util import LUME

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ["LUME_UI_SEM_LOOP"] = "1"

try:
    import PySide6  # noqa: F401
    HAVE_QT = True
except ImportError:
    HAVE_QT = False
    # No CI da imagem o PySide6 é obrigatório: lá, pular seria esconder uma regressão
    if os.environ.get("LUME_EXIGIR_QT") == "1":
        raise


@unittest.skipUnless(HAVE_QT, "PySide6 ausente: teste de interface não executado")
class TestUI(unittest.TestCase):
    def run_example(self, name):
        from lume_runtime import ui
        from lumec.compiler import compile_source
        before = len(ui.windows)
        code, _ = compile_source((LUME / "examples" / name).read_text(), name)
        exec(compile(code, name, "exec"), {"__name__": "__main__"})  # noqa: S102
        return ui.windows[before:]

    def test_hello_window(self):
        (w,) = self.run_example("ola.lume")
        self.assertEqual(w._w.windowTitle(), "Olá do Lume")
        self.assertTrue(w._w.isVisible())

    def test_counter_button_updates_label(self):
        from PySide6.QtWidgets import QLabel
        (w,) = self.run_example("contador.lume")
        label = w._w.findChildren(QLabel)[0]
        self.assertEqual(label.text(), "Cliques: 0")
        w.buttons[0].click()
        w.buttons[0].click()
        self.assertEqual(label.text(), "Cliques: 2")


if __name__ == "__main__":
    unittest.main()
