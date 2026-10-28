#!/usr/bin/env python3
"""Gera theme/color-schemes/Luma{Light,Dark}.colors a partir dos tokens de docs/design/luma-visual-spec.md.

Formato seguido: /usr/share/color-schemes/BreezeLight.colors do Plasma 6.3 (Debian trixie).
Uso: python3 theme/tools/gen-color-schemes.py   (reescreve os dois arquivos)
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "color-schemes"

# Valores medidos nos mockups (docs/design/references), ajustados só o necessário para contraste AA
# (docs/design/luma-visual-spec.md).
LIGHT = dict(
    window="225,233,247", window_alt="216,225,245", view="246,248,253", view_alt="238,241,248",
    button="246,248,253", button_alt="216,225,245", header="225,233,247", header_alt="216,225,245",
    tooltip="246,248,253",
    fg="27,29,38", inactive="89,96,117", active="4,88,215", link="4,88,215", visited="108,62,190",
    neg="191,25,26", neu="150,78,0", pos="2,112,42", focus="42,126,253",
    # Seleção clara com texto escuro, como a barra lateral do mockup claro
    sel="203,221,253", sel_alt="216,225,245", sel_fg="27,29,38", sel_inactive="70,78,98",
    sel_link="4,80,200", sel_visited="98,52,180", sel_neg="170,20,22", sel_neu="130,66,0", sel_pos="2,100,38",
)
DARK = dict(
    window="32,40,64", window_alt="34,41,56", view="19,26,54", view_alt="20,26,40",
    button="34,41,56", button_alt="30,62,128", header="19,26,54", header_alt="32,40,64",
    tooltip="32,45,69",
    fg="231,233,240", inactive="166,172,191", active="123,173,255", link="123,173,255", visited="190,160,255",
    neg="255,138,138", neu="240,180,90", pos="95,208,143", focus="91,155,255",
    sel="30,62,128", sel_alt="32,40,64", sel_fg="255,255,255", sel_inactive="214,222,245",
    sel_link="255,226,160", sel_visited="236,222,255", sel_neg="255,214,214", sel_neu="255,232,190", sel_pos="214,255,228",
)
# Áreas complementares (OSD, telas de bloqueio/logout) são escuras nos dois modos
COMPLEMENTARY = dict(
    bg="15,34,69", alt="19,26,54", fg="231,233,240", inactive="166,172,191", link="123,173,255",
    visited="190,160,255", neg="255,138,138", neu="240,180,90", pos="95,208,143",
)

EFFECTS = """[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0
"""


def group(c, bg, alt, **override):
    d = dict(
        BackgroundNormal=bg, BackgroundAlternate=alt,
        DecorationFocus=c["focus"], DecorationHover=c["focus"],
        ForegroundNormal=c["fg"], ForegroundInactive=c["inactive"], ForegroundActive=c["active"],
        ForegroundLink=c["link"], ForegroundVisited=c["visited"], ForegroundNegative=c["neg"],
        ForegroundNeutral=c["neu"], ForegroundPositive=c["pos"],
    )
    d.update(override)
    return "\n".join(f"{k}={d[k]}" for k in sorted(d))


def render(name, name_pt, c):
    k = COMPLEMENTARY
    groups = {
        "Button": group(c, c["button"], c["button_alt"]),
        "Complementary": group(
            c, k["bg"], k["alt"], ForegroundNormal=k["fg"], ForegroundInactive=k["inactive"],
            ForegroundActive=k["link"], ForegroundLink=k["link"], ForegroundVisited=k["visited"],
            ForegroundNegative=k["neg"], ForegroundNeutral=k["neu"], ForegroundPositive=k["pos"],
            DecorationFocus=k["link"], DecorationHover=k["link"]),
        "Header": group(c, c["header"], c["header_alt"]),
        "Header][Inactive": group(c, c["window"], c["header"]),
        "Selection": group(c, c["sel"], c["sel_alt"], ForegroundNormal=c["sel_fg"], ForegroundActive=c["sel_fg"],
                           ForegroundInactive=c["sel_inactive"], ForegroundLink=c["sel_link"],
                           ForegroundVisited=c["sel_visited"], ForegroundNegative=c["sel_neg"],
                           ForegroundNeutral=c["sel_neu"], ForegroundPositive=c["sel_pos"],
                           DecorationFocus=c["focus"], DecorationHover=c["focus"]),
        "Tooltip": group(c, c["tooltip"], c["window"]),
        "View": group(c, c["view"], c["view_alt"]),
        "Window": group(c, c["window"], c["window_alt"]),
    }
    parts = [
        "# SPDX-FileCopyrightText: Projeto Luma\n# SPDX-License-Identifier: GPL-2.0-or-later\n"
        "# Gerado por theme/tools/gen-color-schemes.py; não editar à mão.\n",
        EFFECTS,
    ]
    parts += [f"[Colors:{g}]\n{body}\n" for g, body in groups.items()]
    parts.append(
        f"[General]\nColorScheme={name}\nName={name.replace('Luma', 'Luma ')}\nName[pt_BR]={name_pt}\n"
        "shadeSortColumn=true\n")
    parts.append("[KDE]\ncontrast=4\n")
    parts.append(
        f"[WM]\nactiveBackground={c['header']}\nactiveBlend={c['header']}\nactiveForeground={c['fg']}\n"
        f"inactiveBackground={c['window']}\ninactiveBlend={c['window']}\ninactiveForeground={c['inactive']}\n")
    return "\n".join(parts)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, pt, tokens in (("LumaLight", "Luma Claro", LIGHT), ("LumaDark", "Luma Escuro", DARK)):
        (OUT / f"{name}.colors").write_text(render(name, pt, tokens), encoding="utf-8", newline="\n")
        print(f"escrito {name}.colors")
