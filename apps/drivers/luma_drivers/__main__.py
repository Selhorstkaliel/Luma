# SPDX-License-Identifier: GPL-2.0-or-later
"""luma-drivers: mostra o hardware detectado e o que falta, e aplica uma ação só com confirmação.

  luma-drivers                 lista em português
  luma-drivers --json          a mesma lista em JSON (testes, app Ajustes)
  luma-drivers aplicar ID      mostra os comandos da ação do item ID e pergunta antes de rodar
  luma-drivers aplicar --confirmado ID   roda sem perguntar de novo (o app Ajustes já confirmou no diálogo)
  luma-drivers --avisar        notifica no login se houver item novo pedindo ação (autostart; não repete)
  luma-drivers --simular aplicar ID   só imprime os comandos (testes)
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys

from . import core

ROTULO = {"ok": "OK", "info": "INFO", "pendente": "FALTA", "sem_suporte": "SEM SUPORTE"}
CATEGORIA = {"video": "Vídeo", "rede": "Rede e Bluetooth", "firmware": "Firmware", "impressao": "Impressoras e scanners",
             "controles": "Controles de jogo", "digital": "Impressão digital", "perifericos": "Mouse e teclado"}


def listar(items):
    if not items:
        print("Nenhum dispositivo relevante encontrado.")
        return
    atual = None
    for i in items:
        if i.categoria != atual:
            atual = i.categoria
            print(f"\n== {CATEGORIA.get(atual, atual)}")
        print(f"[{ROTULO[i.estado]}] {i.dispositivo}\n    {i.detalhe}")
        if i.acao:
            print(f"    Ação: {i.acao.rotulo}  ->  luma-drivers aplicar {i.id}")
    p = core.pendentes(items)
    print(f"\n{len(p)} item(ns) pedindo ação." if p else "\nNada pendente.")


def aplicar(items, item_id, simular, confirmado=False):
    alvo = next((i for i in items if i.id == item_id), None)
    if alvo is None or alvo.acao is None:
        print(f"luma-drivers: item sem ação: {item_id}", file=sys.stderr)
        return 64
    print(f"{alvo.acao.rotulo}:")
    for c in alvo.acao.comandos:
        print("  " + " ".join(c))
    if simular:
        return 0
    if not confirmado and input("Executar? [s/N] ").strip().lower() not in ("s", "sim"):
        print("Nada foi feito.")
        return 0
    for c in alvo.acao.comandos:
        rc = subprocess.call(c)
        if rc != 0:
            print(f"luma-drivers: '{' '.join(c)}' terminou com código {rc}", file=sys.stderr)
            return rc
    return 0


def avisar(items, simular=False):
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    novos = core.novos_pendentes(items, os.path.join(config, "luma", "drivers-avisados"))
    if not novos:
        return 0
    texto = (f"{len(novos)} item(ns) de hardware pedem ação: " + ", ".join(i.dispositivo for i in novos[:3])
             + ". Abra Ajustes > Hardware e drivers.")
    cmd = ["notify-send", "--app-name=Luma", "--icon=luma-logo", "Hardware e drivers", texto]
    if simular or not shutil.which("notify-send"):
        print(" ".join(cmd))
        return 0
    return subprocess.call(cmd)


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    simular = "--simular" in args
    if simular:
        args.remove("--simular")
    if os.geteuid() == 0 and not simular and args[:1] == ["aplicar"]:
        print("luma-drivers: rode com o seu usuário, sem sudo (o sistema pede a senha quando precisar)", file=sys.stderr)
        return 77
    items = core.detectar(os.environ.get("LUMA_ROOT", "/"))
    if args == ["--json"]:
        json.dump(core.como_dict(items), sys.stdout, ensure_ascii=False, indent=1)
        print()
        return 0
    if not args:
        listar(items)
        return 0
    if args == ["--avisar"]:
        return avisar(items, simular)
    confirmado = "--confirmado" in args
    if confirmado:
        args.remove("--confirmado")
    if len(args) == 2 and args[0] == "aplicar":
        return aplicar(items, args[1], simular, confirmado)
    print(__doc__, file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main())
