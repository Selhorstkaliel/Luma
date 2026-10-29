#!/usr/bin/env python3
"""O kickstart da ISO (build/iso/config.toml) não pode apagar disco nem instalar sem perguntar.

Uso: python3 tests/unit/test_installer.py
"""
import tomllib
import unittest
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[2] / "build/iso/config.toml"
# Comandos do Anaconda que particionam, formatam, escolhem disco ou dispensam a confirmação do usuário
FORBIDDEN = {"zerombr", "clearpart", "autopart", "reqpart", "part", "partition", "logvol", "volgroup", "raid",
             "ignoredisk", "bootloader", "reboot", "poweroff", "halt", "shutdown", "cmdline", "text", "vnc",
             "rootpw", "user", "ostreecontainer", "ostreesetup", "%pre", "%post"}


def commands():
    contents = tomllib.loads(CONFIG.read_text(encoding="utf-8"))["customizations"]["installer"]["kickstart"]["contents"]
    for line in contents.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            yield line.split()[0], line


class TestInstallerKickstart(unittest.TestCase):
    def test_no_destructive_or_unattended_command(self):
        for cmd, line in commands():
            with self.subTest(linha=line):
                self.assertNotIn(cmd, FORBIDDEN)

    def test_expected_defaults(self):
        found = dict(commands())
        self.assertEqual(found["lang"], "lang pt_BR.UTF-8")
        self.assertEqual(found["keyboard"], "keyboard br")
        self.assertIn("--hostname=luma", found["network"])


if __name__ == "__main__":
    unittest.main()
