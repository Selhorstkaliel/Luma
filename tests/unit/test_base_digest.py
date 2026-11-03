#!/usr/bin/env python3
"""F6-08: a base Fedora entra no build fixada por digest, nunca só por tag (decisão 0009).

Uso: python3 tests/unit/test_base_digest.py
"""
import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CF = (REPO / "Containerfile").read_text()
INST = (REPO / "build/iso/Containerfile.installer").read_text()
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")


def arg(texto, nome):
    m = re.search(rf"^ARG {nome}=(\S+)$", texto, re.M)
    return m.group(1) if m else None


class BaseDigest(unittest.TestCase):
    def test_args_com_digest(self):
        for nome in ("BASE_DIGEST", "TOOLS_DIGEST"):
            self.assertRegex(arg(CF, nome) or "", DIGEST, nome)

    def test_from_do_containerfile_por_digest(self):
        froms = re.findall(r"^FROM (\S+)", CF, re.M)
        self.assertIn("${TOOLS_IMAGE}:${FEDORA_VERSION}@${TOOLS_DIGEST}", froms)
        self.assertIn("${BASE_IMAGE}:${FEDORA_VERSION}@${BASE_DIGEST}", froms)
        for f in froms:
            self.assertIn("@", f, f"FROM sem digest: {f}")

    def test_installer_usa_o_mesmo_tools(self):
        tools = arg(INST, "TOOLS_IMAGE")
        self.assertTrue(tools.startswith("quay.io/fedora/fedora:"), tools)
        self.assertEqual(tools.split("@", 1)[1], arg(CF, "TOOLS_DIGEST"))
        # O instalador parte da imagem Luma local (já construída pelo digest); nenhuma imagem do quay.io por tag
        self.assertFalse(re.search(r"quay\.io/\S+:\d+(?!@)\s", INST))

    def test_workflows_nao_puxam_a_base_por_tag(self):
        for wf in sorted((REPO / ".github/workflows").glob("*.yml")):
            texto = wf.read_text()
            for m in re.finditer(r"podman pull (\S+)", texto):
                alvo = m.group(1)
                self.assertFalse("fedora-kinoite" in alvo and "@" not in alvo and "$base" not in alvo,
                                 f"{wf.name}: pull por tag: {alvo}")


if __name__ == "__main__":
    unittest.main()
