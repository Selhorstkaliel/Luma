#!/usr/bin/env python3
"""Todo script shell com "#!" versionado em scripts/, tests/ e build/ é executável no git (o CI chama pelo
caminho); os sem "#!" são carregados com "source" (ex.: scripts/lab/config.sh) e ficam de fora.
Run medicao #1: scripts/ci/vm-medicao.sh entrou como 100644 e o passo falhou com "command not found".
Uso: python3 tests/unit/test_exec_bits.py"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class TestExecBits(unittest.TestCase):
    def test_shell_scripts_are_executable(self):
        out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-s", "--", "scripts/*.sh", "tests/*.sh", "build/*.sh"],
                             capture_output=True, text=True, check=True).stdout
        entries = [line.split(maxsplit=3) for line in out.splitlines()]
        self.assertTrue(entries, "nenhum script encontrado")
        for mode, _obj, _stage, path in entries:
            if not (ROOT / path).read_bytes().startswith(b"#!"):
                continue
            with self.subTest(arquivo=path):
                self.assertEqual(mode, "100755", f"{path} sem bit de execução no git")


if __name__ == "__main__":
    unittest.main(verbosity=1)
