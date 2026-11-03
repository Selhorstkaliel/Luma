#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Manifesto de fontes da imagem (F6-10, docs/FONTES.md): roda DENTRO da imagem Luma e imprime JSON com cada pacote
RPM, a licença, o SRPM e onde baixar o fonte no arquivo de builds do Fedora (koji).

  podman run --rm -v "$PWD/scripts/ci:/s:ro" localhost/luma:44 python3 /s/fontes.py > fontes.json
"""
from __future__ import annotations

import json
import subprocess
import sys

KOJI = "https://kojipkgs.fedoraproject.org/packages"
QF = "%{NAME}\\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\\t%{SOURCERPM}\\t%{LICENSE}\\n"


def srpm_para_url(srpm: str) -> str | None:
    """bash-5.2.37-1.fc44.src.rpm -> .../packages/bash/5.2.37/1.fc44/src/bash-5.2.37-1.fc44.src.rpm"""
    if not srpm.endswith(".src.rpm"):
        return None
    base = srpm[: -len(".src.rpm")]
    try:
        nome_ver, rel = base.rsplit("-", 1)
        nome, ver = nome_ver.rsplit("-", 1)
    except ValueError:
        return None
    return f"{KOJI}/{nome}/{ver}/{rel}/src/{srpm}"


def manifesto(saida_rpm: str) -> dict:
    pacotes, sem_fonte = [], []
    for linha in saida_rpm.splitlines():
        if not linha.strip():
            continue
        nome, nevra, srpm, licenca = (linha.split("\t") + ["", "", ""])[:4]
        url = srpm_para_url(srpm)
        item = {"pacote": nome, "versao": nevra, "srpm": srpm, "licenca": licenca, "fonte": url}
        (pacotes if url else sem_fonte).append(item)
    srpms = sorted({p["srpm"] for p in pacotes})
    return {"formato": "luma-fontes/v1", "pacotes": len(pacotes), "srpms": len(srpms), "itens": pacotes,
            "sem_srpm": sem_fonte}


def main() -> int:
    out = subprocess.run(["rpm", "-qa", "--qf", QF], capture_output=True, text=True, check=True).stdout
    json.dump(manifesto(out), sys.stdout, ensure_ascii=False, indent=1)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
