#!/usr/bin/env python3
"""Compara a medição do Luma com a da Kinoite pura (F5-03) e escreve o veredito.

    medicao-compara.py medicao-kinoite.txt medicao-luma.txt [saida.txt]

Entrada: as linhas gravadas por scripts/ci/vm-medicao.sh ("MED boot=N usada_mib=... boot_s=..." e
"MEDPROC boot=N pss_kib=... comm=..."). Usa a mediana dos boots. Critério do plano (F5-03): RAM ociosa
<= Kinoite pura +15 % e boot <= +10 %. Sai com 1 se reprovar ou se faltar medição.
Também compara os AVCs do boot ("MEDAVC boot=N total=... assinaturas=dominio/permissao:qtd,..."): o F5-02 fica
explicado se todo AVC do Luma também aparece na Kinoite pura. É informação; não muda o código de saída.
Com MEDICAO_BASE=<nome> (ex.: "Windows 11"), o primeiro arquivo é desse sistema e a saída é só informativa.
"""
from __future__ import annotations

import os
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


def avcs(caminho: str) -> dict[str, int]:
    """Assinatura de AVC (domínio/permissão) -> maior quantidade num boot."""
    maior: dict[str, int] = defaultdict(int)
    with open(caminho, encoding="utf-8", errors="replace") as f:
        for linha in f:
            m = re.match(r"MEDAVC boot=\d+ total=\d+ assinaturas=(\S+)", linha)
            if not m or m.group(1) == "nenhuma":
                continue
            for item in m.group(1).split(","):
                nome, _, qtd = item.rpartition(":")
                maior[nome] = max(maior[nome], int(qtd))
    return maior


def comparar_avcs(kinoite: str, luma: str) -> str:
    ak, al = avcs(kinoite), avcs(luma)
    texto = (f"AVCs por boot (domínio/permissão: máximo): Kinoite {dict(ak) or 'nenhum'} | Luma {dict(al) or 'nenhum'}")
    so_luma = sorted(n for n, q in al.items() if q > ak.get(n, 0))
    if not al:
        return texto + "\nF5-02 PASSOU nenhum AVC no Luma"
    if not so_luma:
        return texto + "\nF5-02 EXPLICADO todo AVC do Luma também aparece na Kinoite pura (vem da base Fedora)"
    return texto + f"\nF5-02 FALHOU AVCs que só o Luma tem (ou em maior número): {', '.join(so_luma)}"


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
    linhas.extend(comparar_avcs(kinoite, luma).splitlines())
    linhas.append(f"F5-03 {'PASSOU' if ok else 'FALHOU'} Luma contra Kinoite pura, mesma VM sem 3D, mediana de 3 boots")
    return ok, linhas


def comparar_outro(nome: str, base: str, luma: str) -> tuple[bool, list[str]]:
    """Comparação só informativa com outro sistema (MEDICAO_BASE=nome; ex.: Windows 11), sem veredito do F5-03:
    a métrica de memória por processo e o momento do "boot" não são os mesmos entre sistemas diferentes."""
    mb, pb = ler(base)
    ml, pl = ler(luma)
    linhas = [f"boots medidos: {nome} {len(mb['usada_mib'])}, Luma {len(ml['usada_mib'])}"]
    if not mb["usada_mib"] or not ml["usada_mib"]:
        return False, linhas + [f"COMPARACAO FALHOU medição incompleta ({nome} × Luma)"]
    for chave, rotulo in (("usada_mib", "RAM usada (MiB)"), ("disponivel_mib", "disponível (MiB)"), ("boot_s", "boot (s)")):
        a, b = mediana(mb[chave]), mediana(ml[chave])
        dif = (b - a) / a if a else float("nan")
        linhas.append(f"{rotulo}: {nome} {a:.1f} | Luma {b:.1f} | Luma em relação ao {nome}: {dif:+.1%}")
    for rotulo, procs in ((nome, pb), ("Luma", pl)):
        top = sorted(((statistics.median(v) / 1024, n) for n, v in procs.items()), reverse=True)[:8]
        linhas.append(f"maiores processos no {rotulo} (MiB): " + (", ".join(f"{n} {m:.0f}" for m, n in top) or "nenhum"))
    linhas.append(f"COMPARACAO INFO Luma × {nome}, mesma VM (6 GiB, 4 CPUs, Secure Boot, sem 3D), mediana dos boots")
    return True, linhas


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    outro = os.environ.get("MEDICAO_BASE", "")
    ok, linhas = comparar_outro(outro, argv[1], argv[2]) if outro else comparar(argv[1], argv[2])
    texto = "\n".join(linhas) + "\n"
    print(texto, end="")
    if len(argv) > 3:
        with open(argv[3], "w", encoding="utf-8") as f:
            f.write(texto)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
