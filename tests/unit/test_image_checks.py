#!/usr/bin/env python3
"""Cada verificação de tests/image/test-image.sh tem ID e descrição separados.
Run ci #28: uma edição tirou o espaço de "check F4-I01 \"jogos...\"" e o ID virou outro argumento; o shell
continuava válido e só o CI da imagem (10 min) acusou. Uso: python3 tests/unit/test_image_checks.py"""
import re
import shlex
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "tests/image/test-image.sh"
ID = re.compile(r"^F[0-9]-I[0-9]{2}$")


class TestImageChecks(unittest.TestCase):
    def checks(self):
        return [line for line in SCRIPT.read_text(encoding="utf-8").splitlines() if line.startswith("check ")]

    def test_every_check_has_id_description_and_command(self):
        lines = self.checks()
        self.assertGreater(len(lines), 30)
        for line in lines:
            with self.subTest(linha=line[:60]):
                args = shlex.split(line, comments=False, posix=True)
                self.assertGreaterEqual(len(args), 4, "check ID \"descrição\" comando...")
                self.assertRegex(args[1], ID)

    def test_ids_are_unique(self):
        ids = [shlex.split(line)[1] for line in self.checks()]
        self.assertEqual(len(ids), len(set(ids)), [i for i in ids if ids.count(i) > 1])


if __name__ == "__main__":
    unittest.main(verbosity=1)
