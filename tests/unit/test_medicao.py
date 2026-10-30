#!/usr/bin/env python3
"""Veredito do F5-03 (scripts/ci/medicao-compara.py) com medições sintéticas. Uso: python3 tests/unit/test_medicao.py"""
import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/ci/medicao-compara.py"
spec = importlib.util.spec_from_file_location("medicao_compara", SCRIPT)
mc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mc)


def medicao(usadas, boots, procs, avc="nenhuma"):
    linhas = []
    for i, (u, b) in enumerate(zip(usadas, boots, strict=True), 1):
        linhas.append(f"MED boot={i} usada_mib={u} disponivel_mib={6000 - u} shmem_mib=300 boot_s={b}")
        for comm, kib in procs.items():
            linhas.append(f"MEDPROC boot={i} pss_kib={kib} comm={comm}")
        linhas.append(f"MEDAVC boot={i} total=0 assinaturas={avc}")
    linhas.append("END medicao")
    f = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8")
    f.write("\n".join(linhas) + "\n")
    f.close()
    return f.name


class TestCompara(unittest.TestCase):
    def test_dentro_do_limite(self):
        k = medicao([1500, 1520, 1480], [20, 21, 19], {"plasmashell": 300000})
        lu = medicao([1650, 1700, 1690], [21, 22, 20], {"plasmashell": 320000, "python3": 60000})
        ok, linhas = mc.comparar(k, lu)
        self.assertTrue(ok, linhas)
        self.assertIn("F5-03 PASSOU", linhas[-1])
        self.assertTrue(any("python3 +59" in linha for linha in linhas), linhas)   # mediana de 60000 KiB

    def test_acima_do_limite_de_ram(self):
        k = medicao([1400, 1400, 1400], [20, 20, 20], {"plasmashell": 300000})
        lu = medicao([1700, 1700, 1700], [20, 20, 20], {"plasmashell": 300000})
        ok, linhas = mc.comparar(k, lu)
        self.assertFalse(ok)
        self.assertTrue(any("ACIMA" in linha for linha in linhas))

    def test_mediana_ignora_um_boot_fora_da_curva(self):
        k = medicao([1500, 1500, 1500], [20, 20, 20], {})
        lu = medicao([1550, 1560, 4000], [20, 20, 90], {})
        self.assertTrue(mc.comparar(k, lu)[0])

    def test_medicao_vazia_reprova(self):
        vazio = tempfile.NamedTemporaryFile("w", delete=False)
        vazio.close()
        ok, linhas = mc.comparar(vazio.name, vazio.name)
        self.assertFalse(ok)
        self.assertIn("incompleta", linhas[-1])


    def test_avc_da_base_fica_explicado(self):
        base = "tuned_t/mac_admin:6,initrc_t/mac_admin:2"
        k = medicao([1500] * 3, [20] * 3, {}, avc=base)
        lu = medicao([1500] * 3, [20] * 3, {}, avc=base)
        self.assertIn("F5-02 EXPLICADO", "\n".join(mc.comparar(k, lu)[1]))

    def test_avc_so_do_luma_reprova_o_f5_02(self):
        k = medicao([1500] * 3, [20] * 3, {}, avc="tuned_t/mac_admin:6")
        lu = medicao([1500] * 3, [20] * 3, {}, avc="tuned_t/mac_admin:6,unconfined_t/execmem:1")
        texto = "\n".join(mc.comparar(k, lu)[1])
        self.assertIn("F5-02 FALHOU", texto)
        self.assertIn("unconfined_t/execmem", texto)
        self.assertIn("F5-03 PASSOU", texto)   # o AVC não muda o veredito do F5-03


if __name__ == "__main__":
    unittest.main(verbosity=1)
