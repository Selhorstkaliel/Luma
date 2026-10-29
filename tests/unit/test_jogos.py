#!/usr/bin/env python3
"""Testes do luma-jogos (gaming/bin/luma-jogos) em modo --simular: só os comandos gerados.

Uso: python3 tests/unit/test_jogos.py
"""
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "gaming/bin/luma-jogos"
REMOTE = "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"


def simular(*args):
    return subprocess.run(["bash", str(SCRIPT), "--simular", *args], capture_output=True, text=True)


class TestJogos(unittest.TestCase):
    def test_all_by_default_user_scope(self):
        r = simular("instalar")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), [
            REMOTE,
            "flatpak install --user --noninteractive flathub com.valvesoftware.Steam net.lutris.Lutris "
            "com.heroicgameslauncher.hgl com.usebottles.bottles",
        ])

    def test_selection(self):
        r = simular("instalar", "steam", "bottles")
        self.assertEqual(r.stdout.splitlines()[1],
                         "flatpak install --user --noninteractive flathub com.valvesoftware.Steam com.usebottles.bottles")

    def test_unknown_app_and_usage(self):
        self.assertEqual(simular("instalar", "epic").returncode, 64)
        self.assertEqual(simular().returncode, 64)

    def test_never_system_scope_or_rpmfusion(self):
        text = SCRIPT.read_text()
        self.assertNotIn("--system", text)
        self.assertNotIn("rpmfusion", text.lower())


if __name__ == "__main__":
    unittest.main()
