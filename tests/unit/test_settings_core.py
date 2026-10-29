#!/usr/bin/env python3
"""Testes da lógica do app Ajustes (sem Qt). Uso: python3 tests/unit/test_settings_core.py"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "apps" / "settings"))
from luma_ajustes import core  # noqa: E402


class TestContrast(unittest.TestCase):
    def test_reference(self):
        self.assertAlmostEqual(core.contrast("#000000", "#FFFFFF"), 21.0, places=2)
        self.assertAlmostEqual(core.contrast("#767676", "#FFFFFF"), 4.54, places=2)

    def test_every_accent_gets_readable_white_text(self):
        for name, color in core.ACCENTS.items():
            fixed = core.accessible_accent(color)
            with self.subTest(cor=name, original=color, ajustada=fixed):
                self.assertGreaterEqual(core.contrast(fixed, "#FFFFFF"), 4.5)

    def test_accent_already_accessible_is_unchanged(self):
        self.assertEqual(core.accessible_accent("#1E3E80"), "#1E3E80")

    def test_adjustment_is_minimal_darkening(self):
        fixed = core.accessible_accent("#2A7EFD")
        self.assertNotEqual(fixed, "#2A7EFD")
        self.assertLess(core.contrast(fixed, "#FFFFFF"), 5.2)   # não escurece além do necessário


class TestCommands(unittest.TestCase):
    def test_mode(self):
        self.assertEqual(core.mode_commands("escuro")[0].argv, ["luma-appearance", "escuro"])
        with self.assertRaises(ValueError):
            core.mode_commands("azul")

    def test_accent_is_stored_and_applied_with_accessible_color(self):
        store, apply = (c.argv for c in core.accent_commands("amarelo", "escuro"))
        self.assertEqual(store[-3:-1], ["--key", "AccentColor"])
        self.assertEqual(apply[:2], ["plasma-apply-colorscheme", "--accent-color"])
        self.assertEqual(store[-1], apply[2])
        self.assertGreaterEqual(core.contrast(apply[2], "#FFFFFF"), 4.5)
        with self.assertRaises(ValueError):
            core.accent_commands("dourado")

    def test_blue_restores_original_scheme_of_current_mode(self):
        cmds = [c.argv for c in core.accent_commands("azul", "escuro")]
        self.assertIn("--delete", cmds[0])
        self.assertEqual(cmds[-1], ["plasma-apply-colorscheme", "LumaDark"])
        self.assertEqual(core.accent_commands("azul", "claro")[-1].argv[-1], "LumaLight")

    def test_animations(self):
        on = core.animations_commands(True)[0].argv
        off = core.animations_commands(False)[0].argv
        self.assertEqual((on[-2], on[-1]), ("AnimationDurationFactor", "1"))
        self.assertEqual(off[-1], "0")

    def test_text_size_sets_all_fonts_and_notifies(self):
        cmds = core.text_size_commands("Grande")
        keys = [c.argv[c.argv.index("--key") + 1] for c in cmds if c.argv[0] == "kwriteconfig6"]
        self.assertEqual(set(keys), {"font", "menuFont", "toolBarFont", "smallestReadableFont", "activeFont"})
        self.assertTrue(any("Inter,12," in " ".join(c.argv) for c in cmds))
        self.assertEqual(cmds[-1].argv[0], "dbus-send")

    def test_transparency_bounds(self):
        zero = core.transparency_commands(0)
        full = core.transparency_commands(150)          # limitado a 100
        self.assertEqual(zero[0].argv[-1], "false")
        self.assertEqual(full[1].argv[-1], "70")       # nunca abaixo de 70 % de opacidade
        self.assertEqual(core.transparency_commands(70)[1].argv[-1], "79")

    def test_sections_open_existing_tools(self):
        ids = [s[0] for s in core.SECTIONS]
        self.assertEqual(ids, ["sistema", "aparencia", "rede", "aplicativos", "privacidade", "atualizacoes"])
        for sid, _label, _icon, argv in core.SECTIONS:
            if sid != "aparencia":
                self.assertIn(argv[0], ("systemsettings", "plasma-discover"))


class TestTools(unittest.TestCase):
    # run iso #16: o qdbus6 não existe na imagem Fedora; mudar animações ou transparência parava com erro
    def all_commands(self):
        return (core.mode_commands("claro") + core.mode_commands("escuro") + core.accent_commands("rosa")
                + core.animations_commands(True) + core.animations_commands(False)
                + core.text_size_commands("Grande") + core.transparency_commands(50) + core.transparency_commands(0))

    def test_no_qdbus6(self):
        for cmd in self.all_commands():
            with self.subTest(comando=cmd.description):
                self.assertNotIn("qdbus", cmd.argv[0])

    def test_kwin_reload_uses_dbus_send(self):
        reloads = [c.argv for c in self.all_commands() if c.description == "recarregar KWin"]
        self.assertTrue(reloads)
        for argv in reloads:
            self.assertEqual(argv[0], "dbus-send")
            self.assertIn("org.kde.KWin.reconfigure", argv)


if __name__ == "__main__":
    unittest.main(verbosity=1)
