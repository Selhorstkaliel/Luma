# SPDX-License-Identifier: GPL-2.0-or-later
"""Lógica do app Ajustes do Luma, sem dependência de Qt (testável com unittest).

Cada ajuste vira uma lista de comandos de ferramentas que já existem no sistema:
luma-appearance, plasma-apply-colorscheme, kwriteconfig6 e qdbus6. Nada exige privilégios.
"""
from __future__ import annotations

from dataclasses import dataclass

# Cores de destaque do mockup escuro (Ajustes > Aparência), na mesma ordem
ACCENTS = {
    "azul": "#2A7EFD",
    "roxo": "#8B5CF6",
    "rosa": "#EC4899",
    "vermelho": "#EF4444",
    "laranja": "#F97316",
    "amarelo": "#F5B700",
    "verde": "#22C55E",
    "cinza": "#6B7280",
}

TEXT_SIZES = {"Pequeno": 9, "Médio": 10, "Grande": 12}
FONT_FAMILY = "Inter"


def _lin(c: float) -> float:
    c /= 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hex_color: str) -> float:
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def contrast(a: str, b: str) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def accessible_accent(hex_color: str, target: float = 4.5) -> str:
    """Escurece a cor o mínimo necessário para texto branco sobre ela atingir `target` (WCAG AA)."""
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    while contrast(f"#{r:02X}{g:02X}{b:02X}", "#FFFFFF") < target and (r or g or b):
        r, g, b = (max(0, int(x * 0.97)) for x in (r, g, b))
    return f"#{r:02X}{g:02X}{b:02X}"


def font_spec(size: int, weight: int = 400) -> str:
    """Formato de fonte do KConfig/Qt6 (família, pontos, -1, estilo, peso, ...)."""
    return f"{FONT_FAMILY},{size},-1,5,{weight},0,0,0,0,0,0,0,0,0,0,1"


@dataclass
class Command:
    argv: list[str]
    description: str


def mode_commands(mode: str) -> list[Command]:
    if mode not in ("claro", "escuro"):
        raise ValueError(f"modo inválido: {mode}")
    return [Command(["luma-appearance", mode], f"aparência {mode}")]


def accent_commands(name: str, mode: str = "claro") -> list[Command]:
    """Plasma 6.3 aplica o destaque nas cores mas não guarda a escolha; ela fica em [Luma] AccentColor
    para o app saber a cor atual e para o luma-appearance reaplicá-la ao trocar claro/escuro.
    "azul" (padrão) volta ao esquema Luma original, que tem a seleção clara do mockup."""
    if name not in ACCENTS:
        raise ValueError(f"cor de destaque desconhecida: {name}")
    if mode not in ("claro", "escuro"):
        raise ValueError(f"modo inválido: {mode}")
    kw = ["kwriteconfig6", "--file", "kdeglobals"]
    if name == "azul":
        scheme = "LumaLight" if mode == "claro" else "LumaDark"
        return [
            Command(kw + ["--group", "Luma", "--key", "AccentColor", "--delete"], "esquecer destaque"),
            # o plasma-apply-colorscheme recusa reaplicar o esquema ativo; apagar o nome força a reaplicação
            Command(kw + ["--group", "General", "--key", "ColorScheme", "--delete"], "liberar esquema"),
            Command(["plasma-apply-colorscheme", scheme], f"esquema {scheme} original"),
        ]
    color = accessible_accent(ACCENTS[name])
    return [
        Command(kw + ["--group", "Luma", "--key", "AccentColor", color], f"guardar destaque {name}"),
        Command(["plasma-apply-colorscheme", "--accent-color", color], f"destaque {name} ({color})"),
    ]


def animations_commands(enabled: bool) -> list[Command]:
    factor = "1" if enabled else "0"
    return [
        Command(["kwriteconfig6", "--file", "kdeglobals", "--group", "KDE", "--key", "AnimationDurationFactor", factor],
                "animações " + ("ligadas" if enabled else "desligadas")),
        Command(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], "recarregar KWin"),
    ]


def text_size_commands(label: str) -> list[Command]:
    if label not in TEXT_SIZES:
        raise ValueError(f"tamanho de texto desconhecido: {label}")
    size = TEXT_SIZES[label]
    cmds = []
    for key, s, w in (("font", size, 400), ("menuFont", size, 400), ("toolBarFont", size, 400),
                      ("smallestReadableFont", max(7, size - 2), 400)):
        cmds.append(Command(["kwriteconfig6", "--file", "kdeglobals", "--group", "General", "--key", key, font_spec(s, w)],
                            f"fonte {key} {s} pt"))
    cmds.append(Command(["kwriteconfig6", "--file", "kdeglobals", "--group", "WM", "--key", "activeFont", font_spec(size, 600)],
                        f"título de janela {size} pt"))
    # Avisa os apps KDE em execução (KGlobalSettings::FontChanged = 1)
    cmds.append(Command(["dbus-send", "--session", "--type=signal", "/KGlobalSettings",
                         "org.kde.KGlobalSettings.notifyChange", "int32:1", "int32:0"], "avisar troca de fonte"))
    return cmds


def transparency_commands(percent: int) -> list[Command]:
    """Transparência = efeito de translucidez do KWin para janelas inativas e em movimento.
    0 % desliga o efeito; 100 % deixa janelas inativas com 70 % de opacidade (mínimo legível)."""
    percent = max(0, min(100, int(percent)))
    enabled = "true" if percent > 0 else "false"
    opacity = str(100 - round(percent * 0.30))
    return [
        Command(["kwriteconfig6", "--file", "kwinrc", "--group", "Plugins", "--key", "translucencyEnabled", enabled],
                "efeito de translucidez " + ("ligado" if percent else "desligado")),
        Command(["kwriteconfig6", "--file", "kwinrc", "--group", "Effect-translucency", "--key", "Inactive", opacity],
                f"janelas inativas {opacity}%"),
        Command(["kwriteconfig6", "--file", "kwinrc", "--group", "Effect-translucency", "--key", "MoveResize", opacity],
                f"janelas em movimento {opacity}%"),
        Command(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], "recarregar KWin"),
    ]


# Páginas da barra lateral que abrem módulos existentes das Configurações do sistema
SECTIONS = [
    ("sistema", "Sistema", "computer-symbolic", ["systemsettings", "kcm_about-distro"]),
    ("aparencia", "Aparência", "preferences-desktop-theme-global-symbolic", None),
    ("rede", "Rede", "network-wireless-symbolic", ["systemsettings", "kcm_networkmanagement"]),
    ("aplicativos", "Aplicativos", "preferences-desktop-default-applications-symbolic", ["systemsettings", "kcm_componentchooser"]),
    ("privacidade", "Privacidade", "preferences-desktop-user-password-symbolic", ["systemsettings", "kcm_screenlocker"]),
    ("atualizacoes", "Atualizações", "system-software-update-symbolic", ["plasma-discover", "--mode", "update"]),
]
