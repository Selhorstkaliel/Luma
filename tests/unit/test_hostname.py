#!/usr/bin/env python3
"""Testes do luma-hostname (configs/usr/libexec/luma/luma-hostname) numa raiz temporária (LUMA_ROOT).

Uso: python3 tests/unit/test_hostname.py
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "configs/usr/libexec/luma/luma-hostname"


def make_root(hostname):
    root = Path(tempfile.mkdtemp())
    (root / "etc").mkdir()
    (root / "usr/lib").mkdir(parents=True)
    (root / "usr/lib/os-release").write_text('NAME="Luma-OS"\nDEFAULT_HOSTNAME="luma"\n')
    if hostname is not None:
        (root / "etc/hostname").write_text(hostname)
    return root


def run(root):
    env = dict(os.environ, LUMA_ROOT=str(root))
    subprocess.run(["bash", str(SCRIPT)], env=env, check=True, capture_output=True)
    return (root / "etc/hostname").read_text().strip()


class TestHostname(unittest.TestCase):
    def test_generic_names_become_luma(self):
        for name in ("fedora\n", "localhost", "localhost.localdomain", "", None):
            with self.subTest(hostname=name):
                self.assertEqual(run(make_root(name)), "luma")

    def test_user_choice_is_kept(self):
        self.assertEqual(run(make_root("meu-pc\n")), "meu-pc")

    def test_runs_only_once(self):
        root = make_root("fedora")
        run(root)
        (root / "etc/hostname").write_text("fedora")  # se o usuário escolher "fedora" depois, não mexe mais
        self.assertEqual(run(root), "fedora")


if __name__ == "__main__":
    unittest.main()
