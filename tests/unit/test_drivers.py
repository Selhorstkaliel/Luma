#!/usr/bin/env python3
"""Testes do assistente de drivers (apps/drivers/luma_drivers) sobre um sysfs falso, sem root e sem hardware.

Uso: python3 tests/unit/test_drivers.py
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "apps/drivers"))
from luma_drivers import core  # noqa: E402


class FakeSys:
    def __init__(self):
        self.root = Path(tempfile.mkdtemp())
        (self.root / "sys/bus/pci/devices").mkdir(parents=True)
        (self.root / "sys/bus/usb/devices").mkdir(parents=True)
        (self.root / "sys/class/input").mkdir(parents=True)
        (self.root / "drv").mkdir()

    def _link_driver(self, d: Path, driver: str):
        if driver:
            (self.root / "drv" / driver).mkdir(exist_ok=True)
            (d / "driver").symlink_to(self.root / "drv" / driver)

    def pci(self, slot, classe, vendor, device, driver=""):
        d = self.root / "sys/bus/pci/devices" / slot
        d.mkdir()
        (d / "class").write_text(f"0x{classe}00\n")
        (d / "vendor").write_text(f"0x{vendor}\n")
        (d / "device").write_text(f"0x{device}\n")
        self._link_driver(d, driver)

    def usb(self, porta, vendor, product, nome="", ifaces=()):
        d = self.root / "sys/bus/usb/devices" / porta
        d.mkdir()
        (d / "idVendor").write_text(vendor + "\n")
        (d / "idProduct").write_text(product + "\n")
        if nome:
            (d / "product").write_text(nome + "\n")
        for n, (classe, driver) in enumerate(ifaces):
            i = d / f"{porta}:1.{n}"
            i.mkdir()
            (i / "bInterfaceClass").write_text(classe + "\n")
            self._link_driver(i, driver)

    def js(self, nome):
        d = self.root / "sys/class/input/js0/device"
        d.mkdir(parents=True)
        (d / "name").write_text(nome + "\n")


def detect(fs, comandos=None, saidas=None, usuario="ana"):
    comandos = set(comandos or [])
    saidas = saidas or {}
    run = lambda argv: saidas.get(argv[0])  # noqa: E731
    return core.detectar(fs.root, run=run, has=lambda c: c in comandos, usuario=usuario)


def by_id(items):
    return {i.id: i for i in items}


class Video(unittest.TestCase):
    def test_notebook_hibrido_intel_nvidia(self):
        fs = FakeSys()
        fs.pci("0000:00:02.0", "0300", "8086", "46a3", "i915")
        fs.pci("0000:01:00.0", "0302", "10de", "25a2", "nouveau")
        items = by_id(detect(fs, comandos={"switcherooctl"}))
        self.assertEqual(items["video-0000:00:02.0"].estado, "ok")
        nv = items["video-0000:01:00.0"]
        self.assertEqual(nv.estado, "info")
        self.assertIn("decisão 0012", nv.detalhe)
        self.assertIsNone(nv.acao, "nenhum driver proprietário é oferecido")
        self.assertIn("switcherooctl launch", items["video-hibrido"].detalhe)
        self.assertNotIn("ausente", items["video-hibrido"].detalhe)

    def test_vm_e_placa_sem_driver(self):
        fs = FakeSys()
        fs.pci("0000:00:01.0", "0300", "1234", "1111")
        fs.pci("0000:02:00.0", "0300", "1002", "73ff")
        items = by_id(detect(fs))
        self.assertEqual(items["video-0000:00:01.0"].estado, "ok")
        self.assertIn("virtual", items["video-0000:00:01.0"].dispositivo)
        self.assertEqual(items["video-0000:02:00.0"].estado, "sem_suporte")
        self.assertNotIn("video-hibrido", items)


class Rede(unittest.TestCase):
    def test_wifi_broadcom_sem_driver_e_bluetooth(self):
        fs = FakeSys()
        fs.pci("0000:03:00.0", "0280", "14e4", "43b1")
        fs.pci("0000:04:00.0", "0280", "8086", "51f0", "iwlwifi")
        fs.usb("1-10", "8087", "0026", "", [("e0", "btusb"), ("e0", "btusb")])
        items = by_id(detect(fs))
        self.assertEqual(items["rede-0000:03:00.0"].estado, "sem_suporte")
        self.assertIn("wl", items["rede-0000:03:00.0"].detalhe)
        self.assertEqual(items["rede-0000:04:00.0"].estado, "ok")
        self.assertEqual(items["rede-usb-1-10"].estado, "ok")


class Firmware(unittest.TestCase):
    def test_firmware_ausente_e_fwupd(self):
        fs = FakeSys()
        log = ("iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2\n"
               "bluetooth hci0: firmware: failed to load intel/ibt-0040-0041.sfi (-2)\n")
        items = by_id(detect(fs, comandos={"fwupdmgr", "journalctl"}, saidas={"journalctl": log}))
        self.assertIn("firmware-iwlwifi-so-a0-gf-a0-89.ucode", items)
        self.assertIn("firmware-intel/ibt-0040-0041.sfi", items)
        fw = items["firmware-fwupd"]
        self.assertEqual(fw.estado, "info", "fwupd não conta como pendente: só oferece")
        self.assertEqual(fw.acao.comandos, [["fwupdmgr", "refresh"], ["fwupdmgr", "update"]])


class Impressao(unittest.TestCase):
    def test_impressora_usb_sem_fila_e_scanner(self):
        fs = FakeSys()
        fs.usb("1-2", "03f0", "c511", "HP DeskJet", [("07", "usblp")])
        scan = "found USB scanner (vendor=0x04a9 [Canon], product=0x190e [CanoScan]) at libusb:001:005\n"
        items = by_id(detect(fs, comandos={"lpstat", "ipp-usb", "sane-find-scanner"},
                             saidas={"lpstat": "lpstat: No destinations added.", "sane-find-scanner": scan}))
        imp = items["impressora-1-2"]
        self.assertEqual(imp.estado, "pendente")
        self.assertEqual(imp.acao.comandos, [["systemsettings", "kcm_printer_manager"]])
        self.assertIn("IPP-over-USB", imp.detalhe)
        self.assertIn("scanner-04a9-190e", items)

    def test_impressora_ja_configurada_e_rede(self):
        fs = FakeSys()
        fs.usb("1-2", "03f0", "c511", "HP DeskJet", [("07", "usblp")])
        items = by_id(detect(fs, comandos={"lpstat"}, saidas={"lpstat": "device for HP: ipp://localhost:60000/ipp/print"}))
        self.assertEqual(items["impressora-1-2"].estado, "ok")
        self.assertIsNone(items["impressora-1-2"].acao)
        self.assertIn("impressao-rede", by_id(detect(FakeSys(), comandos={"lpstat", "scanimage"})))


class Controles(unittest.TestCase):
    def test_controles_e_steam(self):
        fs = FakeSys()
        fs.usb("1-3", "045e", "0b12", "Xbox Wireless Controller", [("ff", "xpad")])
        fs.usb("1-4", "045e", "07a5", "Microsoft Wireless Mouse", [("03", "usbhid")])  # mouse da Microsoft não é controle
        fs.js("Sony Interactive Entertainment DualSense Wireless Controller")
        items = by_id(detect(fs, comandos={"steam-devices"}))
        self.assertEqual(items["controle-1-3"].estado, "ok")
        self.assertNotIn("controle-1-4", items)
        self.assertTrue(any("DualSense" in i.dispositivo for i in items.values()))
        self.assertEqual(items["controles-steam"].acao.comandos, [["luma-jogos", "instalar", "steam"]])

    def test_sem_controle_sem_item(self):
        self.assertFalse([i for i in detect(FakeSys()) if i.categoria == "controles"])


class Digital(unittest.TestCase):
    def test_leitor_suportado_sem_digital(self):
        out = "found 1 devices\nDevice at /net/reactivated/Fprint/Device/0\nUser ana has no fingers enrolled for Goodix MOC.\n"
        items = by_id(detect(FakeSys(), comandos={"fprintd-list"}, saidas={"fprintd-list": out}))
        self.assertEqual(items["digital"].estado, "pendente")
        self.assertEqual(items["digital"].acao.comandos, [["systemsettings", "kcm_users"]])

    def test_leitor_sem_driver_livre(self):
        fs = FakeSys()
        fs.usb("1-6", "138a", "0097")
        items = by_id(detect(fs, comandos={"fprintd-list"}, saidas={"fprintd-list": "No devices available"}))
        self.assertEqual(items["digital"].estado, "sem_suporte")


class Perifericos(unittest.TestCase):
    def test_logitech_e_mouse_gamer(self):
        fs = FakeSys()
        fs.usb("1-7", "046d", "c548", "USB Receiver Bolt", [("03", "usbhid")])
        out = "warbling-mara:       Logitech G Pro Wireless\n"
        items = by_id(detect(fs, comandos={"solaar", "ratbagctl"}, saidas={"ratbagctl": out}))
        self.assertEqual(items["perifericos-logitech"].acao.comandos, [["solaar"]])
        piper = items["perifericos-ratbag"]
        self.assertIn("Logitech G Pro", piper.dispositivo)
        self.assertEqual(piper.acao.comandos[-1][-1], "org.freedesktop.Piper")
        self.assertIn("--user", piper.acao.comandos[-1])


class Seguranca(unittest.TestCase):
    def test_nenhuma_acao_usa_root_ou_terceiros(self):
        fs = FakeSys()
        fs.pci("0000:01:00.0", "0300", "10de", "25a2", "nouveau")
        fs.usb("1-2", "03f0", "c511", "HP", [("07", "")])
        fs.usb("1-3", "28de", "1102", "Steam Controller", [("03", "usbhid")])
        fs.usb("1-7", "046d", "c548", "USB Receiver", [])
        tudo = {"lpstat", "fwupdmgr", "fprintd-list", "ratbagctl", "solaar", "journalctl"}
        saidas = {"ratbagctl": "x: Mouse", "fprintd-list": "found 1 devices\nhas no fingers enrolled"}
        for i in detect(fs, comandos=tudo, saidas=saidas):
            for c in (i.acao.comandos if i.acao else []):
                self.assertNotIn(c[0], {"sudo", "pkexec", "rpm-ostree", "dnf", "bootc"}, i.id)
                self.assertFalse(any("rpmfusion" in a or "nvidia" in a.lower() for a in c), i.id)


class Cli(unittest.TestCase):
    def run_cli(self, *args, root):
        env = dict(os.environ, LUMA_ROOT=str(root), PYTHONPATH=str(REPO / "apps/drivers"))
        return subprocess.run([sys.executable, "-m", "luma_drivers", *args], env=env, capture_output=True, text=True)

    def test_json_e_simular(self):
        fs = FakeSys()
        fs.pci("0000:00:01.0", "0300", "1234", "1111")
        fs.usb("1-2", "03f0", "c511", "HP", [("07", "")])
        p = self.run_cli("--json", root=fs.root)
        self.assertEqual(p.returncode, 0, p.stderr)
        dados = json.loads(p.stdout)
        self.assertTrue(any(d["categoria"] == "video" for d in dados))
        lista = self.run_cli(root=fs.root)
        self.assertIn("== Vídeo", lista.stdout)
        p = self.run_cli("--simular", "aplicar", "nao-existe", root=fs.root)
        self.assertEqual(p.returncode, 64)


if __name__ == "__main__":
    unittest.main()
