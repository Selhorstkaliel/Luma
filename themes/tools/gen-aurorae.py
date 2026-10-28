#!/usr/bin/env python3
"""Gera os temas de decoração Aurorae "Luma" (claro) e "LumaEscuro" em theme/aurorae/.

Formato: temas SVG do motor Aurorae incluído em kwin-common (Plasma 6.3, Debian trixie).
Botões circulares vermelho/amarelo/verde à esquerda, título à esquerda, cantos superiores
arredondados e sombra desenhada com gradientes (o QtSvg não suporta filtros de desfoque).
Cores dos mockups: docs/design/luma-visual-spec.md. Uso: python3 theme/tools/gen-aurorae.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "aurorae"

P = 18        # área de sombra em volta da janela (PaddingLeft/Right/Top/Bottom)
R = 12        # raio dos cantos superiores
TITLE = 40    # altura total da barra de título
BORDER = 1    # borda fina nas laterais e embaixo
BTN = 20      # área de cada botão
DOT = 13      # diâmetro do círculo

THEMES = {
    "Luma": dict(name="Luma Claro", title="#E1E9F7", title_inactive="#EEF2FA", border="#C7D3EC",
                 text="#1B1D26", text_inactive="#6B7186", shadow="#1E3A78", shadow_op=0.18,
                 off="#C4CBDA", glyph="#4A1010"),
    "LumaEscuro": dict(name="Luma Escuro", title="#131A36", title_inactive="#1A2140", border="#2A3456",
                       text="#E7E9F0", text_inactive="#9AA1B6", shadow="#000000", shadow_op=0.45,
                       off="#3A4260", glyph="#2B0808"),
}
BUTTONS = {"close": "#FD4D56", "minimize": "#FECB18", "maximize": "#2CD656", "restore": "#2CD656"}
GLYPHS = {  # desenhados só no estado "hover", como nos sistemas de referência
    "close": "M-3,-3 L3,3 M3,-3 L-3,3",
    "minimize": "M-3.5,0 L3.5,0",
    "maximize": "M-3,-3 L3,-3 L3,3 Z M-3,3 L-3,-3",
    "restore": "M-3.5,0 L3.5,0 M0,-3.5 L0,3.5",
}


def shadow_defs(c):
    """Gradientes em espaço local (userSpaceOnUse). Opacidade = op na borda da janela e 0 a P px dela,
    igual nos cantos (radiais centrados no arco) e nas bordas (lineares): sem emendas entre elementos."""
    s, o = c["shadow"], c["shadow_op"]
    k = R / (P + R)
    stop = lambda: f'<stop offset="0" stop-color="{s}" stop-opacity="{o}"/><stop offset="1" stop-color="{s}" stop-opacity="0"/>'
    return f"""
  <radialGradient id="sh-tl" gradientUnits="userSpaceOnUse" cx="{P + R}" cy="{P + R}" r="{P + R}"><stop offset="{k}" stop-color="{s}" stop-opacity="{o}"/><stop offset="1" stop-color="{s}" stop-opacity="0"/></radialGradient>
  <radialGradient id="sh-tr" gradientUnits="userSpaceOnUse" cx="0" cy="{P + R}" r="{P + R}"><stop offset="{k}" stop-color="{s}" stop-opacity="{o}"/><stop offset="1" stop-color="{s}" stop-opacity="0"/></radialGradient>
  <radialGradient id="sh-bl" gradientUnits="userSpaceOnUse" cx="{P + BORDER}" cy="0" r="{P}">{stop()}</radialGradient>
  <radialGradient id="sh-br" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="{P}">{stop()}</radialGradient>
  <linearGradient id="sh-top" gradientUnits="userSpaceOnUse" x1="0" y1="{P}" x2="0" y2="0">{stop()}</linearGradient>
  <linearGradient id="sh-bottom" gradientUnits="userSpaceOnUse" x1="0" y1="{BORDER}" x2="0" y2="{BORDER + P}">{stop()}</linearGradient>
  <linearGradient id="sh-left" gradientUnits="userSpaceOnUse" x1="{P}" y1="0" x2="0" y2="0">{stop()}</linearGradient>
  <linearGradient id="sh-right" gradientUnits="userSpaceOnUse" x1="{BORDER}" y1="0" x2="{BORDER + P}" y2="0">{stop()}</linearGradient>"""


def frame(prefix, x0, c, active):
    """Nove elementos da moldura (KSvg FrameSvg), lado a lado a partir de x0. Retorna (svg, largura usada)."""
    bg = c["title"] if active else c["title_inactive"]
    b = c["border"]
    cw, ch = P + R, P + TITLE          # canto superior
    mid = 20                           # largura/altura dos elementos esticáveis
    bw = P + BORDER                    # cantos inferiores e laterais
    parts = []
    # Canto superior esquerdo: sombra radial no quadrado do arco, sombra linear abaixo, arco preenchido
    parts.append(f'<g id="{prefix}topleft" transform="translate({x0},0)">'
                 f'<rect width="{cw}" height="{ch}" fill="none"/>'
                 f'<rect width="{cw}" height="{cw}" fill="url(#sh-tl)"/>'
                 f'<rect y="{cw}" width="{P}" height="{ch - cw}" fill="url(#sh-left)"/>'
                 f'<path d="M{P},{ch} L{P},{P + R} A{R},{R} 0 0 1 {P + R},{P} L{cw},{P} L{cw},{ch} Z" fill="{bg}"/>'
                 f'<path d="M{P + 0.5},{ch} L{P + 0.5},{P + R} A{R - 0.5},{R - 0.5} 0 0 1 {P + R},{P + 0.5} L{cw},{P + 0.5}" fill="none" stroke="{b}" stroke-width="{BORDER}"/></g>')
    x = x0 + cw + 2
    parts.append(f'<g id="{prefix}top" transform="translate({x},0)">'
                 f'<rect width="{mid}" height="{P}" fill="url(#sh-top)"/>'
                 f'<rect y="{P}" width="{mid}" height="{TITLE}" fill="{bg}"/>'
                 f'<rect y="{P}" width="{mid}" height="{BORDER}" fill="{b}"/></g>')
    x += mid + 2
    parts.append(f'<g id="{prefix}topright" transform="translate({x},0)">'
                 f'<rect width="{cw}" height="{ch}" fill="none"/>'
                 f'<rect width="{cw}" height="{cw}" fill="url(#sh-tr)"/>'
                 f'<rect x="{R}" y="{cw}" width="{P}" height="{ch - cw}" fill="url(#sh-right)"/>'
                 f'<path d="M0,{ch} L0,{P} A{R},{R} 0 0 1 {R},{P + R} L{R},{ch} Z" fill="{bg}"/>'
                 f'<path d="M0,{P + 0.5} A{R - 0.5},{R - 0.5} 0 0 1 {R - 0.5},{P + R} L{R - 0.5},{ch}" fill="none" stroke="{b}" stroke-width="{BORDER}"/></g>')
    x += cw + 2
    parts.append(f'<g id="{prefix}left" transform="translate({x},0)">'
                 f'<rect width="{P}" height="{mid}" fill="url(#sh-left)"/>'
                 f'<rect x="{P}" width="{BORDER}" height="{mid}" fill="{b}"/></g>')
    x += bw + 2
    parts.append(f'<g id="{prefix}center" transform="translate({x},0)"><rect width="{mid}" height="{mid}" fill="{bg}" fill-opacity="0"/></g>')
    x += mid + 2
    parts.append(f'<g id="{prefix}right" transform="translate({x},0)">'
                 f'<rect width="{BORDER}" height="{mid}" fill="{b}"/>'
                 f'<rect x="{BORDER}" width="{P}" height="{mid}" fill="url(#sh-right)"/></g>')
    x += bw + 2
    parts.append(f'<g id="{prefix}bottomleft" transform="translate({x},0)">'
                 f'<rect width="{bw}" height="{bw}" fill="none"/>'
                 f'<rect width="{P}" height="{BORDER}" fill="url(#sh-left)"/>'
                 f'<rect y="{BORDER}" width="{bw}" height="{P}" fill="url(#sh-bl)"/>'
                 f'<rect x="{P}" width="{BORDER}" height="{BORDER}" fill="{b}"/></g>')
    x += bw + 2
    parts.append(f'<g id="{prefix}bottom" transform="translate({x},0)">'
                 f'<rect width="{mid}" height="{BORDER}" fill="{b}"/>'
                 f'<rect y="{BORDER}" width="{mid}" height="{P}" fill="url(#sh-bottom)"/></g>')
    x += mid + 2
    parts.append(f'<g id="{prefix}bottomright" transform="translate({x},0)">'
                 f'<rect width="{bw}" height="{bw}" fill="none"/>'
                 f'<rect x="{BORDER}" width="{P}" height="{BORDER}" fill="url(#sh-right)"/>'
                 f'<rect y="{BORDER}" width="{bw}" height="{P}" fill="url(#sh-br)"/>'
                 f'<rect width="{BORDER}" height="{BORDER}" fill="{b}"/></g>')
    x += bw + 2
    return "\n".join(parts), x


def decoration_svg(c):
    a, x = frame("decoration-", 0, c, True)
    i, _ = frame("decoration-inactive-", x + 10, c, False)
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<!-- Projeto Luma — SPDX-License-Identifier: GPL-2.0-or-later -->\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="900" height="80"><defs>{shadow_defs(c)}\n</defs>\n{a}\n{i}\n</svg>\n')


def button_svg(kind, c):
    color = BUTTONS[kind]
    r = DOT / 2
    def dot(state, x, fill, glyph=False, darker=False):
        g = (f'<path d="{GLYPHS[kind]}" transform="translate({BTN / 2},{BTN / 2})" stroke="{c["glyph"]}" '
             f'stroke-width="1.4" stroke-linecap="round" fill="none"/>') if glyph else ""
        shade = '<circle cx="{0}" cy="{0}" r="{1}" fill="#000000" fill-opacity="0.15"/>'.format(BTN / 2, r) if darker else ""
        return (f'<g id="{state}-center" transform="translate({x},0)"><rect width="{BTN}" height="{BTN}" fill="none"/>'
                f'<circle cx="{BTN / 2}" cy="{BTN / 2}" r="{r}" fill="{fill}"/>{shade}{g}</g>')
    states = [("active", color, False, False), ("hover", color, True, False), ("pressed", color, True, True),
              ("inactive", c["off"], False, False), ("deactivated", c["off"], False, False)]
    body = "".join(dot(s, n * (BTN + 4), f, gl, dk) for n, (s, f, gl, dk) in enumerate(states))
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<!-- Projeto Luma — SPDX-License-Identifier: GPL-2.0-or-later -->\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{5 * (BTN + 4)}" height="{BTN}">{body}</svg>\n')


def rc(theme, c):
    return f"""[General]
ActiveTextColor={c['text']}
InactiveTextColor={c['text_inactive']}
TitleAlignment=Left
TitleVerticalAlignment=Center
Animation=150
UseTextShadow=false
Shadow=true

[Layout]
BorderLeft={BORDER}
BorderRight={BORDER}
BorderBottom={BORDER}
TitleEdgeTop=10
TitleEdgeBottom=10
TitleEdgeLeft=14
TitleEdgeRight=14
TitleBorderLeft=12
TitleBorderRight=12
TitleHeight={TITLE - 20}
ButtonWidth={BTN}
ButtonHeight={BTN}
ButtonSpacing=2
ButtonMarginTop=0
ExplicitButtonSpacer=10
PaddingTop={P}
PaddingBottom={P}
PaddingLeft={P}
PaddingRight={P}
"""


def metadata(theme, c):
    import json
    return json.dumps({
        "KPackageStructure": "KWin/Aurorae",
        "KPlugin": {"Authors": [{"Name": "Projeto Luma"}], "Id": theme, "License": "GPL-2.0-or-later",
                    "Name": c["name"], "Name[pt_BR]": c["name"], "Version": "0.5.0"},
    }, ensure_ascii=False, indent=4) + "\n"


if __name__ == "__main__":
    for theme, c in THEMES.items():
        d = OUT / theme
        d.mkdir(parents=True, exist_ok=True)
        (d / "decoration.svg").write_text(decoration_svg(c), encoding="utf-8", newline="\n")
        for kind in BUTTONS:
            (d / f"{kind}.svg").write_text(button_svg(kind, c), encoding="utf-8", newline="\n")
        (d / f"{theme}rc").write_text(rc(theme, c), encoding="utf-8", newline="\n")
        (d / "metadata.json").write_text(metadata(theme, c), encoding="utf-8", newline="\n")
        print(f"tema {theme} escrito em {d}")
