#!/usr/bin/env python3
"""Inventário de licenças e proteção contra ativos de terceiros (decisão 0010).

- Todo arquivo versionado casa com uma regra de LICENSES.toml.
- Nenhum ativo visual (SVG/PNG/JPG) tem nome ou conteúdo que indique marca de terceiros vista no mockup
  de referência (Apple, WhiteSur, Netflix...). O mockup é referência de estilo, não fonte de ativos.
Uso: python3 tests/unit/test_licenses.py
"""
import fnmatch
import re
import subprocess
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSET_EXT = {".svg", ".png", ".jpg", ".jpeg", ".webp"}
# Marcas vistas no mockup Midnight ou no fastfetch dele; a lista cresce quando surgir outra
BRANDS = ["apple", "macos", "whitesur", "netflix", "spotify", "youtube", "amazon", "discord", "steam-logo",
          "github", "gmail", "google", "mr.kitty", "mrkitty", "after dark"]


def tracked_files():
    out = subprocess.run(["git", "ls-files", "-co", "--exclude-standard"], cwd=ROOT, capture_output=True,
                         text=True, check=True).stdout
    return [f for f in out.splitlines() if (ROOT / f).is_file()]


def match(path, pattern):
    # fnmatch não trata "**" como diretórios recursivos; "x/**" vira prefixo e "**" casa tudo
    if pattern == "**":
        return True
    if pattern.endswith("/**"):
        return path.startswith(pattern[:-2])
    return fnmatch.fnmatch(path, pattern)


class TestLicenses(unittest.TestCase):
    def setUp(self):
        self.rules = tomllib.loads((ROOT / "LICENSES.toml").read_text(encoding="utf-8"))["regra"]

    def test_rules_are_complete(self):
        for r in self.rules:
            with self.subTest(regra=r.get("padrao")):
                self.assertTrue(r.get("licenca") and r.get("origem"))

    def test_every_file_has_a_license(self):
        files = tracked_files()
        self.assertTrue(files)
        orphans = [f for f in files if not any(match(f, r["padrao"]) for r in self.rules)]
        self.assertEqual(orphans, [])

    def test_no_third_party_brand_assets(self):
        bad = []
        for f in tracked_files():
            p = ROOT / f
            if p.suffix.lower() not in ASSET_EXT:
                continue
            name = f.lower()
            text = p.read_text(encoding="utf-8", errors="ignore").lower() if p.suffix.lower() == ".svg" else ""
            for b in BRANDS:
                if b in name or re.search(r"\b" + re.escape(b) + r"\b", text):
                    bad.append((f, b))
        self.assertEqual(bad, [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
