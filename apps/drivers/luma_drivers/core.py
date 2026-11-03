# SPDX-License-Identifier: GPL-2.0-or-later
"""Detecção de hardware e drivers do Luma, sem Qt e sem root (testável com unittest, decisão 0014).

Lê o sysfs (/sys/bus/pci, /sys/bus/usb, /sys/class/input) e a saída de ferramentas que já existem na imagem
(journalctl, lpstat, sane-find-scanner, fprintd-list, ratbagctl). Nunca instala nada sozinho: cada item pode
trazer uma ação (lista fixa de comandos) que só roda com a confirmação do usuário.
Limites declarados: o sistema é imutável (nada de rpm-ostree), nenhum repositório de terceiros (decisão 0012),
e o driver proprietário da NVIDIA não faz parte do Luma (só é detectado e explicado).
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Callable

FLATHUB = "https://dl.flathub.org/repo/flathub.flatpakrepo"

GPU_VENDORS = {"8086": "Intel", "1002": "AMD", "10de": "NVIDIA"}
# Placas de vídeo emuladas (QEMU/VirtualBox/VMware/virtio): VM, sem driver a buscar
VIRTUAL_GPU_VENDORS = {"1234": "QEMU (VGA padrão)", "1af4": "virtio", "1b36": "QEMU", "15ad": "VMware", "80ee": "VirtualBox"}
# Leitores de digital mais comuns em notebooks (vendedores USB); a confirmação vem do fprintd
FINGERPRINT_VENDORS = {"06cb", "27c6", "138a", "147e", "1c7a", "10a5", "2808", "298d"}
CONTROLLER_VENDORS = {"045e": "Microsoft (Xbox)", "054c": "Sony (PlayStation)", "057e": "Nintendo",
                      "28de": "Valve (Steam)", "2dc8": "8BitDo"}
CONTROLLER_WORDS = re.compile(r"controller|gamepad|joystick|joy-con|dualsense|dualshock|xbox|pro controller", re.I)
FIRMWARE_FAIL = re.compile(r"(?:firmware: failed to load|Direct firmware load for) (\S+?)(?: |:|$)")

Runner = Callable[[list], "str | None"]


@dataclass
class Acao:
    rotulo: str
    comandos: list  # lista de argv; rodam em ordem, com o usuário (o polkit pede senha quando a ferramenta precisa)


@dataclass
class Item:
    id: str
    categoria: str  # video | rede | firmware | impressao | controles | digital | perifericos
    dispositivo: str
    estado: str  # ok | info | pendente | sem_suporte
    detalhe: str
    acao: Acao | None = None
    extra: dict = field(default_factory=dict)


def run_cmd(argv: list) -> str | None:
    """Roda uma ferramenta de leitura; None se não existir ou falhar por tempo."""
    if not shutil.which(argv[0]):
        return None
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return (p.stdout or "") + (p.stderr or "")


def _read(p: Path) -> str:
    try:
        return p.read_text(errors="replace").strip()
    except OSError:
        return ""


def _hex(v: str) -> str:
    return v.lower().removeprefix("0x")[-4:]


def pci_devices(root: Path) -> list[dict]:
    out = []
    for d in sorted((root / "sys/bus/pci/devices").glob("*")):
        drv = d / "driver"
        out.append({
            "slot": d.name,
            "classe": _hex(_read(d / "class")[:6]) if _read(d / "class") else "",
            "vendor": _hex(_read(d / "vendor")),
            "device": _hex(_read(d / "device")),
            "driver": os.path.basename(os.readlink(drv)) if drv.is_symlink() else "",
        })
    return out


def usb_devices(root: Path) -> list[dict]:
    out = []
    for d in sorted((root / "sys/bus/usb/devices").glob("*")):
        if not (d / "idVendor").exists():
            continue
        ifaces = []
        for i in sorted(d.glob(f"{d.name}:*")):
            drv = i / "driver"
            ifaces.append({"classe": _read(i / "bInterfaceClass").lower(),
                           "driver": os.path.basename(os.readlink(drv)) if drv.is_symlink() else ""})
        out.append({"porta": d.name, "vendor": _hex(_read(d / "idVendor")), "product": _hex(_read(d / "idProduct")),
                    "nome": " ".join(filter(None, [_read(d / "manufacturer"), _read(d / "product")])),
                    "interfaces": ifaces})
    return out


# O joydev cria js* também para tablets e outros dispositivos de eixo absoluto (VM do usuário, 2026-11-03:
# "QEMU QEMU USB Tablet" e "spice vdagent tablet" apareciam como controles de jogo)
NAO_CONTROLE = re.compile(r"tablet|touchpad|trackpad|mouse|\bpen\b|stylus|digitizer|accelerometer|vdagent|wacom", re.I)


def joysticks(root: Path) -> list[str]:
    nomes = [_read(js / "device/name") or js.name for js in sorted((root / "sys/class/input").glob("js*"))]
    return [n for n in nomes if not NAO_CONTROLE.search(n)]


def _usb_label(u: dict) -> str:
    return u["nome"] or f"USB {u['vendor']}:{u['product']}"


def detect_video(pci: list[dict], has: Callable[[str], bool]) -> list[Item]:
    items, reais = [], []
    for d in pci:
        if not d["classe"].startswith("03"):
            continue
        v = d["vendor"]
        if v in VIRTUAL_GPU_VENDORS:
            items.append(Item(f"video-{d['slot']}", "video", f"Placa de vídeo virtual ({VIRTUAL_GPU_VENDORS[v]})", "ok",
                              "Máquina virtual: o vídeo é emulado e não há driver a buscar.", extra=d))
            continue
        nome = f"Placa de vídeo {GPU_VENDORS.get(v, 'fabricante ' + v)} ({v}:{d['device']})"
        reais.append(d)
        if not d["driver"]:
            items.append(Item(f"video-{d['slot']}", "video", nome, "sem_suporte",
                              "Nenhum driver do kernel está usando esta placa.", extra=d))
        elif v == "10de":
            items.append(Item(f"video-{d['slot']}", "video", nome, "info",
                              f"Driver livre em uso ({d['driver']}; Vulkan pelo NVK do Mesa). O driver proprietário da "
                              "NVIDIA não faz parte do Luma (decisão 0012): desempenho em jogos pode ser menor.", extra=d))
        else:
            items.append(Item(f"video-{d['slot']}", "video", nome, "ok",
                              f"Driver livre do kernel em uso ({d['driver']}), com aceleração pelo Mesa.", extra=d))
    if len(reais) >= 2:
        det = "Duas placas de vídeo (notebook híbrido): os apps usam a integrada; para usar a dedicada, "
        det += "clique com o botão direito no app e escolha a placa dedicada, ou rode: switcherooctl launch <app>."
        if not has("switcherooctl"):
            det += " (switcheroo-control ausente nesta imagem)"
        items.append(Item("video-hibrido", "video", "Gráficos híbridos", "info", det))
    return items


def detect_rede(pci: list[dict], usb: list[dict]) -> list[Item]:
    items = []
    for d in pci:
        if d["classe"] != "0280":
            continue
        nome = f"Wi-Fi PCI {d['vendor']}:{d['device']}"
        if d["driver"]:
            items.append(Item(f"rede-{d['slot']}", "rede", nome, "ok", f"Driver do kernel em uso ({d['driver']}).", extra=d))
        elif d["vendor"] == "14e4":
            items.append(Item(f"rede-{d['slot']}", "rede", nome, "sem_suporte",
                              "Broadcom sem driver livre: o driver 'wl' é proprietário e não vem no Fedora nem no Luma. "
                              "Alternativa: adaptador Wi-Fi USB compatível.", extra=d))
        else:
            items.append(Item(f"rede-{d['slot']}", "rede", nome, "sem_suporte",
                              "Nenhum driver do kernel está usando este Wi-Fi.", extra=d))
    for u in usb:
        for i in u["interfaces"]:
            if i["classe"] == "e0":  # Bluetooth (wireless controller)
                if i["driver"]:
                    st, det = "ok", f"Bluetooth com driver ({i['driver']})."
                else:
                    st, det = "sem_suporte", "Bluetooth sem driver do kernel."
                items.append(Item(f"rede-usb-{u['porta']}", "rede", _usb_label(u), st, det,
                                  extra={"vendor": u["vendor"], "product": u["product"]}))
                break
    return items


def detect_firmware(run: Runner, has: Callable[[str], bool]) -> list[Item]:
    items = []
    log = run(["journalctl", "-k", "-b", "--no-pager", "-o", "cat"]) or ""
    faltando = sorted(set(FIRMWARE_FAIL.findall(log)))
    for f in faltando:
        items.append(Item(f"firmware-{f}", "firmware", f"Firmware {f}", "sem_suporte",
                          "O kernel não achou este firmware. Se o Fedora o publicar no linux-firmware, ele chega numa "
                          "atualização do Luma (bootc upgrade); não dá para instalar à parte num sistema imutável."))
    if has("fwupdmgr"):
        items.append(Item("firmware-fwupd", "firmware", "Firmware de dispositivos (fwupd/LVFS)", "info",
                          "BIOS, SSD, dock, mouse e teclado compatíveis podem ser atualizados pelo fabricante via LVFS.",
                          Acao("Procurar e instalar atualizações de firmware",
                               [["fwupdmgr", "refresh"], ["fwupdmgr", "update"]])))
    return items


def detect_impressao(usb: list[dict], run: Runner, has: Callable[[str], bool]) -> list[Item]:
    items = []
    impressoras = [u for u in usb if any(i["classe"] == "07" for i in u["interfaces"])]
    filas = run(["lpstat", "-v"]) if has("lpstat") else None
    tem_fila = bool(filas and "device for" in filas)
    abrir = Acao("Abrir as configurações de impressora", [["systemsettings", "kcm_printer_manager"]])
    for u in impressoras:
        ippusb = has("ipp-usb")
        det = "Impressora USB. " + ("Modelos com IPP-over-USB funcionam sem driver (ipp-usb). " if ippusb else "")
        det += "Já há impressora configurada." if tem_fila else "Nenhuma impressora configurada ainda."
        items.append(Item(f"impressora-{u['porta']}", "impressao", _usb_label(u), "ok" if tem_fila else "pendente", det,
                          None if tem_fila else abrir, extra={"vendor": u["vendor"], "product": u["product"]}))
    scan = run(["sane-find-scanner", "-q"]) if has("sane-find-scanner") else None
    for m in re.finditer(r"found USB scanner \(vendor=0x([0-9a-f]+)[^,]*, product=0x([0-9a-f]+)", scan or "", re.I):
        items.append(Item(f"scanner-{m.group(1)}-{m.group(2)}", "impressao", f"Scanner USB {m.group(1)}:{m.group(2)}", "info",
                          "Scanner detectado pelo SANE. Se o modelo precisar de driver do fabricante, ele não vem no Luma; "
                          "scanners de rede funcionam sem driver (sane-airscan)."))
    if not items and has("lpstat"):
        items.append(Item("impressao-rede", "impressao", "Impressoras e scanners de rede", "info",
                          "Impressoras de rede compatíveis (IPP Everywhere/AirPrint) e scanners eSCL aparecem sozinhos, "
                          "sem driver." + ("" if has("airscan-discover") or has("scanimage") else " (sane-airscan ausente)")))
    return items


def detect_controles(usb: list[dict], js: list[str], has: Callable[[str], bool]) -> list[Item]:
    items, vistos = [], set()
    for u in usb:
        if u["vendor"] in CONTROLLER_VENDORS and (u["vendor"] in {"28de", "2dc8"} or CONTROLLER_WORDS.search(u["nome"])):
            vistos.add(u["nome"])
            com_driver = any(i["driver"] for i in u["interfaces"])
            items.append(Item(f"controle-{u['porta']}", "controles", _usb_label(u) + f" [{CONTROLLER_VENDORS[u['vendor']]}]",
                              "ok" if com_driver else "info",
                              "Controle reconhecido pelo kernel." if com_driver
                              else "Controle sem driver do kernel; a Steam o usa diretamente.",
                              extra={"vendor": u["vendor"], "product": u["product"]}))
    for nome in js:
        if nome not in vistos and not any(nome in i.dispositivo for i in items):
            items.append(Item(f"controle-js-{len(items)}", "controles", nome, "ok",
                              "Controle ativo (dispositivo de jogo do kernel)."))
    if items:
        det = "Regras de controles da Steam instaladas (steam-devices)." if has("steam-devices") else \
            "A imagem não tem as regras steam-devices; a Steam em Flatpak traz as próprias."
        items.append(Item("controles-steam", "controles", "Steam para os controles", "info", det,
                          Acao("Instalar a Steam (Flathub, só para o seu usuário)", [["luma-jogos", "instalar", "steam"]])))
    return items


def detect_digital(usb: list[dict], run: Runner, has: Callable[[str], bool], usuario: str) -> list[Item]:
    suspeitos = [u for u in usb if u["vendor"] in FINGERPRINT_VENDORS or "fingerprint" in u["nome"].lower()]
    out = run(["fprintd-list", usuario]) if has("fprintd-list") else None
    if out and re.search(r"found \d+ devices?", out, re.I) and not re.search(r"found 0 devices?", out, re.I):
        cadastrada = "has no fingers enrolled" not in out and "no fingers" not in out.lower()
        acao = None if cadastrada else Acao("Cadastrar a digital (Configurações > Usuários)", [["systemsettings", "kcm_users"]])
        return [Item("digital", "digital", "Leitor de impressão digital", "ok" if cadastrada else "pendente",
                     "Leitor suportado (fprintd). "
                     + ("Digital já cadastrada." if cadastrada else "Nenhuma digital cadastrada."), acao)]
    if suspeitos:
        u = suspeitos[0]
        return [Item("digital", "digital", _usb_label(u), "sem_suporte",
                     "Parece um leitor de digital, mas o fprintd/libfprint não tem driver livre para ele.",
                     extra={"vendor": u["vendor"], "product": u["product"]})]
    return []


def detect_perifericos(usb: list[dict], run: Runner, has: Callable[[str], bool]) -> list[Item]:
    items = []
    logi = [u for u in usb if u["vendor"] == "046d" and re.search(r"receiver|unifying|bolt|lightspeed", u["nome"], re.I)]
    if logi:
        cmds = [["solaar"]] if has("solaar") else []
        items.append(Item("perifericos-logitech", "perifericos", _usb_label(logi[0]), "info",
                          "Receptor Logitech: bateria, pareamento e botões pelo Solaar."
                          + ("" if cmds else " (Solaar ausente nesta imagem)"),
                          Acao("Abrir o Solaar", cmds) if cmds else None))
    out = run(["ratbagctl", "list"]) if has("ratbagctl") else None
    linhas = [ln for ln in (out or "").splitlines() if ":" in ln and "not found" not in ln.lower()]
    if linhas:
        items.append(Item("perifericos-ratbag", "perifericos", "Mouse gamer: " + linhas[0].split(":", 1)[1].strip(), "info",
                          "DPI, botões e luzes configuráveis pelo Piper (Flathub, só para o seu usuário).",
                          Acao("Instalar o Piper", [["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", FLATHUB],
                                                    ["flatpak", "install", "--user", "-y", "flathub", "org.freedesktop.Piper"]])))
    return items


def detectar(root: Path | str = "/", run: Runner = run_cmd, has: Callable[[str], bool] | None = None,
             usuario: str | None = None) -> list[Item]:
    root = Path(root)
    has = has or (lambda c: shutil.which(c) is not None or (c == "steam-devices" and _steam_rules(root)))
    usuario = usuario or os.environ.get("USER") or "root"
    pci, usb = pci_devices(root), usb_devices(root)
    return (detect_video(pci, has) + detect_rede(pci, usb) + detect_firmware(run, has) + detect_impressao(usb, run, has)
            + detect_controles(usb, joysticks(root), has) + detect_digital(usb, run, has, usuario)
            + detect_perifericos(usb, run, has))


def _steam_rules(root: Path) -> bool:
    return any((root / d).glob("*steam*.rules") for d in ("usr/lib/udev/rules.d", "etc/udev/rules.d"))


def pendentes(items: list[Item]) -> list[Item]:
    return [i for i in items if i.estado == "pendente"]


def como_dict(items: list[Item]) -> list[dict]:
    return [asdict(i) for i in items]
