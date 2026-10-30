# SPDX-License-Identifier: GPL-2.0-or-later
"""App Ajustes do Luma: interface QML (Kirigami) + backend PySide6 que executa os comandos de core.py."""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from . import core


def _read(file: str, group: str, key: str, default: str = "") -> str:
    """Lê com kreadconfig6 (respeita ~/.config/kdedefaults e /etc/xdg, como a sessão Plasma)."""
    if not shutil.which("kreadconfig6"):
        return default
    out = subprocess.run(["kreadconfig6", "--file", file, "--group", group, "--key", key, "--default", default],
                         capture_output=True, text=True, check=False)
    return out.stdout.strip() or default


class Backend(QObject):
    changed = Signal()
    error = Signal(str)

    def _run(self, commands: list[core.Command]) -> None:
        for cmd in commands:
            try:
                res = subprocess.run(cmd.argv, capture_output=True, text=True, check=False, timeout=60)
            except (OSError, subprocess.TimeoutExpired) as e:
                self.error.emit(f"Não foi possível aplicar ({cmd.description}): {e}")
                return
            if res.returncode != 0 and cmd.argv[0] != "dbus-send":
                self.error.emit(f"Não foi possível aplicar ({cmd.description}).")
                return
        self.changed.emit()

    # --- estado atual ---
    @Property(str, notify=changed)
    def mode(self) -> str:
        return "escuro" if _read("kdeglobals", "General", "ColorScheme") == "LumaDark" else "claro"

    @Property(str, notify=changed)
    def accent(self) -> str:
        current = _read("kdeglobals", "Luma", "AccentColor").upper()
        for name, color in core.ACCENTS.items():
            if current and core.accessible_accent(color) == current:
                return name
        return "azul"

    @Property(bool, notify=changed)
    def animations(self) -> bool:
        return _read("kdeglobals", "KDE", "AnimationDurationFactor", "1") not in ("0", "0.0")

    @Property(str, notify=changed)
    def textSize(self) -> str:
        font = _read("kdeglobals", "General", "font", "Inter,10")
        try:
            size = int(font.split(",")[1])
        except (IndexError, ValueError):
            size = 10
        return min(core.TEXT_SIZES, key=lambda k: abs(core.TEXT_SIZES[k] - size))

    @Property(int, notify=changed)
    def transparency(self) -> int:
        if _read("kwinrc", "Plugins", "translucencyEnabled", "false") != "true":
            return 0
        try:
            return round((100 - int(_read("kwinrc", "Effect-translucency", "Inactive", "100"))) / 0.30)
        except ValueError:
            return 0

    @Property("QVariantList", constant=True)
    def accents(self) -> list:
        return [{"name": n, "color": c} for n, c in core.ACCENTS.items()]

    @Property("QVariantList", constant=True)
    def sections(self) -> list:
        return [{"id": i, "label": label, "icon": icon} for i, label, icon, _argv in core.SECTIONS]

    @Property("QVariantList", constant=True)
    def textSizes(self) -> list:
        return list(core.TEXT_SIZES)

    # --- ações ---
    @Slot(str)
    def setMode(self, mode: str) -> None:
        self._run(core.mode_commands(mode))

    @Slot(str)
    def setAccent(self, name: str) -> None:
        self._run(core.accent_commands(name, self.mode))

    @Slot(bool)
    def setAnimations(self, enabled: bool) -> None:
        self._run(core.animations_commands(enabled))

    @Slot(str)
    def setTextSize(self, label: str) -> None:
        self._run(core.text_size_commands(label))

    @Slot(int)
    def setTransparency(self, percent: int) -> None:
        self._run(core.transparency_commands(percent))

    @Slot(str)
    def welcomeAction(self, action_id: str) -> None:
        argv = core.WELCOME_ACTIONS.get(action_id)
        if not argv:
            return
        try:
            subprocess.Popen(argv, start_new_session=True)  # noqa: S603 — comandos fixos de core.WELCOME_ACTIONS
        except OSError as e:
            self.error.emit(f"Não foi possível abrir ({action_id}): {e}")

    @Slot()
    def finishWelcome(self) -> None:
        core.mark_welcome_done(_config_home())
        QGuiApplication.quit()

    @Slot(str)
    def openSection(self, section_id: str) -> None:
        for sid, _label, _icon, argv in core.SECTIONS:
            if sid == section_id and argv:
                subprocess.Popen(argv, start_new_session=True)  # noqa: S603 — comandos fixos de core.SECTIONS


def _config_home() -> str:
    return os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")


def main() -> int:
    args = sys.argv[1:]
    welcome = "--boas-vindas" in args
    # Boas-vindas (F3-03): só no primeiro login, a não ser com --forcar; o autoteste sempre carrega a interface
    if welcome and "--verificar" not in args and not core.should_show_welcome(_config_home(), "--forcar" in args):
        return 0
    app = QGuiApplication(sys.argv)
    app.setApplicationName("luma-boas-vindas" if welcome else "luma-ajustes")
    app.setApplicationDisplayName("Boas-vindas" if welcome else "Ajustes")
    app.setDesktopFileName("org.luma.boas-vindas" if welcome else "org.luma.ajustes")
    app.setWindowIcon(QIcon.fromTheme("luma-logo" if welcome else "preferences-system"))
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    qml = "BoasVindas.qml" if welcome else "Main.qml"
    engine.load(QUrl.fromLocalFile(str(Path(__file__).with_name("qml") / qml)))
    if not engine.rootObjects():
        return 1
    if "--verificar" in sys.argv[1:]:
        # Autoteste (testes da imagem, com QT_QPA_PLATFORM=offscreen): a interface carregou; sai sem abrir a janela
        print(f"luma-ajustes: interface carregada ({qml})")
        return 0
    return app.exec()
