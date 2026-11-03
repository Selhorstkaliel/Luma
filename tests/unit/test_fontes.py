#!/usr/bin/env python3
"""F6-09/F6-10: manifesto de fontes (scripts/ci/fontes.py) e a trava do commit automático da base
(scripts/ci/so-digests.sh).

Uso: python3 tests/unit/test_fontes.py
"""
import importlib.util
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("fontes", REPO / "scripts/ci/fontes.py")
fontes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fontes)

D1 = "sha256:" + "a" * 64
D2 = "sha256:" + "b" * 64


class Manifesto(unittest.TestCase):
    def test_url_do_koji(self):
        self.assertEqual(fontes.srpm_para_url("bash-5.2.37-1.fc44.src.rpm"),
                         "https://kojipkgs.fedoraproject.org/packages/bash/5.2.37/1.fc44/src/bash-5.2.37-1.fc44.src.rpm")
        self.assertEqual(fontes.srpm_para_url("python-pyside6-6.9.1-2.fc44.src.rpm").split("/")[4:7],
                         ["python-pyside6", "6.9.1", "2.fc44"])
        self.assertIsNone(fontes.srpm_para_url("(none)"))

    def test_manifesto(self):
        saida = ("bash\t0:5.2.37-1.fc44.x86_64\tbash-5.2.37-1.fc44.src.rpm\tGPL-3.0-or-later\n"
                 "bash-doc\t0:5.2.37-1.fc44.noarch\tbash-5.2.37-1.fc44.src.rpm\tGPL-3.0-or-later\n"
                 "gpg-pubkey\t0:abcd-1234.(none)\t(none)\tpubkey\n")
        m = fontes.manifesto(saida)
        self.assertEqual((m["formato"], m["pacotes"], m["srpms"]), ("luma-fontes/v1", 2, 1))
        self.assertEqual([i["pacote"] for i in m["sem_srpm"]], ["gpg-pubkey"])


class TravaDigests(unittest.TestCase):
    def repo(self):
        d = Path(tempfile.mkdtemp())
        (d / "build/iso").mkdir(parents=True)
        (d / "Containerfile").write_text(f"ARG BASE_DIGEST={D1}\nARG TOOLS_DIGEST={D1}\nFROM x\n")
        (d / "build/iso/Containerfile.installer").write_text(f"ARG TOOLS_IMAGE=quay.io/fedora/fedora:44@{D1}\n")
        for c in (["init", "-q"], ["add", "."], ["-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "x"]):
            subprocess.run(["git", *c], cwd=d, check=True)
        return d

    def rc(self, d):
        return subprocess.run(["bash", str(REPO / "scripts/ci/so-digests.sh"), str(d)], capture_output=True).returncode

    @unittest.skipUnless(shutil.which("git"), "sem git")
    def test_sem_mudanca(self):
        self.assertEqual(self.rc(self.repo()), 0)

    @unittest.skipUnless(shutil.which("git"), "sem git")
    def test_so_digests(self):
        d = self.repo()
        (d / "Containerfile").write_text(f"ARG BASE_DIGEST={D2}\nARG TOOLS_DIGEST={D2}\nFROM x\n")
        (d / "build/iso/Containerfile.installer").write_text(f"ARG TOOLS_IMAGE=quay.io/fedora/fedora:44@{D2}\n")
        self.assertEqual(self.rc(d), 10)

    @unittest.skipUnless(shutil.which("git"), "sem git")
    def test_outra_mudanca_bloqueia(self):
        d = self.repo()
        (d / "Containerfile").write_text(f"ARG BASE_DIGEST={D2}\nARG TOOLS_DIGEST={D1}\nFROM y\n")
        self.assertEqual(self.rc(d), 1)
        d = self.repo()
        (d / "outro.txt").write_text("x")
        self.assertEqual(self.rc(d), 1)


if __name__ == "__main__":
    unittest.main()
