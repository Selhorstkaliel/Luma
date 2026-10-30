#!/usr/bin/env python3
"""Compara a medição do Luma com a da Kinoite pura (F5-03) e escreve o veredito.

    medicao-compara.py medicao-kinoite.txt medicao-luma.txt [saida.txt]

Entrada: as linhas gravadas por scripts/ci/vm-medicao.sh ("MED boot=N usada_mib=... boot_s=..." e
"MEDPROC boot=N pss_kib=... comm=..."). Usa a mediana dos boots. Critério do plano (F5-03): RAM ociosa
<= Kinoite pura +15 % e boot <= +10 %. Sai com 1 se reprovar ou se faltar medição.
"""
from __future__ import annotations

import re
import statistics
import sys
from collections import defaultdict

LIMITE_RAM = 0.15
LIMITE_BOOT = 0.10


def ler(caminho: str) -> tuple[dict[str, list[float]], dict[str, list[int]]]:
    med: dict[str, list[float]] = defaultdict(list)
    proc: dict[int, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    with open(caminho, encoding="utf-8", errors="replace") as f:
        for linha in f:
            campos = dict(re.findall(r"(\w+)=(\S+)", linha))
            if linha.startswith("MED ") and "usada_mib" in campos:
                for k in ("usada_mib", "disponivel_mib", "shmem_mib", "boot_s"):
                    med[k].append(float(campos[k]))
            elif linha.startswith("MEDPROC ") and "pss_kib" in campos:
                proc[int(campos["boot"])][campos.get("comm", "?")] += int(campos["pss_kib"])
    # PSS por nome de processo: soma por boot, depois mediana entre os boots
    por_nome: dict[str, list[int]] = defaultdict(list)
    for boot in proc.values():
        for nome, kib in boot.items():
            por_nome[nome].append(kib)
    return med, por_nome


def mediana(v: list[float]) -> float:
    return statistics.median(v) if v else float("nan")


def comparar(kinoite: str, luma: str) -> tuple[bool, list[str]]:
    mk, pk = ler(kinoite)
    ml, pl = ler(luma)
    linhas = [f"boots medidos: Kinoite {len(mk['usada_mib'])}, Luma {len(ml['usada_mib'])}"]
    if not mk["usada_mib"] or not ml["usada_mib"]:
        return False, linhas + ["F5-03 FALHOU medição incompleta"]
    ok = True
    for chave, rotulo, limite in (("usada_mib", "RAM usada (MiB)", LIMITE_RAM), ("boot_s", "boot (s)", LIMITE_BOOT)):
        a, b = mediana(mk[chave]), mediana(ml[chave])
        dif = (b - a) / a if a else float("inf")
        dentro = dif <= limite
        ok &= dentro
        linhas.append(f"{rotulo}: Kinoite {a:.1f} | Luma {b:.1f} | diferença {dif:+.1%} (limite +{limite:.0%}) "
                      + ("dentro" if dentro else "ACIMA"))
    for chave, rotulo in (("shmem_mib", "Shmem (MiB, inclui buffers do llvmpipe)"), ("disponivel_mib", "disponível (MiB)")):
        linhas.append(f"{rotulo}: Kinoite {mediana(mk[chave]):.0f} | Luma {mediana(ml[chave]):.0f}")
    # Processos que mais pesam a mais no Luma (mediana de PSS entre os boots)
    nomes = set(pk) | set(pl)
    difs = sorted(((statistics.median(pl.get(n, [0])) - statistics.median(pk.get(n, [0]))) / 1024, n) for n in nomes)
    a_mais = ", ".join(f"{n} {d:+.0f}" for d, n in reversed(difs[-8:]) if d > 0)
    a_menos = ", ".join(f"{n} {d:+.0f}" for d, n in difs[:5] if d < 0)
    linhas.append(f"processos com mais PSS a mais no Luma (MiB): {a_mais or 'nenhum'}")
    linhas.append(f"processos com mais PSS a menos no Luma (MiB): {a_menos or 'nenhum'}")
    linhas.append(f"F5-03 {'PASSOU' if ok else 'FALHOU'} Luma contra Kinoite pura, mesma VM sem 3D, mediana de 3 boots")
    return ok, linhas


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    ok, linhas = comparar(argv[1], argv[2])
    texto = "\n".join(linhas) + "\n"
    print(texto, end="")
    if len(argv) > 3:
        with open(argv[3], "w", encoding="utf-8") as f:
            f.write(texto)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
