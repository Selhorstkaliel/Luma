#!/usr/bin/env python3
"""Gera luma-ondas-claro.svg e luma-ondas-escuro.svg (arte original, CC-BY-SA-4.0).
Faixas de "seda" com sombreamento ao longo da largura e reflexos finos nas bordas."""
import math

W, H = 1920, 1080

def ribbon(y0, amp, phase, thick, tilt, n=9):
    """Faixa ondulada: borda superior e inferior com a mesma onda, espessura variável."""
    xs = [-200 + i * (W + 400) / (n - 1) for i in range(n)]
    top = [(x, y0 + tilt * x + amp * math.sin(phase + x / 260)) for x in xs]
    bot = [(x, y + thick * (0.65 + 0.35 * math.cos(phase * 1.7 + x / 330))) for x, y in top]
    def smooth(pts):
        d = f"{pts[0][0]:.0f},{pts[0][1]:.0f}"
        for i in range(1, len(pts)):
            x0, y0_ = pts[i - 1]; x1, y1 = pts[i]
            mx = (x0 + x1) / 2
            d += f" C{mx:.0f},{y0_:.0f} {mx:.0f},{y1:.0f} {x1:.0f},{y1:.0f}"
        return d
    edge = "M" + smooth(top)
    shape = edge + " L" + smooth(list(reversed(bot))) + " Z"
    return shape, edge

def build(bg, glow, bands, shine, shine_op):
    defs, body = [], []
    for i, (y0, amp, ph, th, tilt, c0, c1, c2, op) in enumerate(bands):
        shape, edge = ribbon(y0, amp, ph, th, tilt)
        defs.append(f'<linearGradient id="g{i}" x1="0" y1="0" x2="0.15" y2="1">'
                    f'<stop offset="0" stop-color="{c0}"/><stop offset="0.45" stop-color="{c1}"/>'
                    f'<stop offset="1" stop-color="{c2}"/></linearGradient>')
        body.append(f'<path d="{shape}" fill="url(#g{i})" fill-opacity="{op}" filter="url(#s)"/>')
        body.append(f'<path d="{edge}" fill="none" stroke="{shine}" stroke-opacity="{shine_op}" stroke-width="2.5" filter="url(#f)"/>')
        body.append(f'<path d="{edge}" fill="none" stroke="{shine}" stroke-opacity="{shine_op * 0.45}" stroke-width="14" filter="url(#h)"/>')
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- Luma Ondas — arte original do Projeto Luma no estilo dos mockups do usuário. SPDX-License-Identifier: CC-BY-SA-4.0 -->
<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
 <defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{bg[0]}"/><stop offset="0.5" stop-color="{bg[1]}"/><stop offset="1" stop-color="{bg[2]}"/></linearGradient>
  <radialGradient id="glow" cx="0.68" cy="0.35" r="0.6"><stop offset="0" stop-color="{glow}" stop-opacity="0.6"/><stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient>
  <filter id="s" x="-5%" y="-20%" width="110%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
  <filter id="f" x="-5%" y="-20%" width="110%" height="140%"><feGaussianBlur stdDeviation="1.2"/></filter>
  <filter id="h" x="-5%" y="-50%" width="110%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
  {"".join(defs)}
 </defs>
 <rect width="{W}" height="{H}" fill="url(#bg)"/>
 <rect width="{W}" height="{H}" fill="url(#glow)"/>
 {"".join(body)}
</svg>
'''

#        y0  amp  fase  esp  incl   cor topo   cor meio   cor base  opac
light = build(("#EEE8FC", "#DCE6FC", "#C2D4F8"), "#FFFFFF", [
    (120, 70, 0.3, 230, -0.10, "#FFFFFF", "#E4DDFA", "#BFD0F6", 0.80),
    (330, 90, 1.4, 260, -0.12, "#FDFBFF", "#D6E2FB", "#A9C1F2", 0.80),
    (560, 80, 2.6, 240, -0.10, "#FFFFFF", "#E2D8F8", "#9DB8EE", 0.78),
    (790, 70, 3.5, 300, -0.08, "#F4F7FE", "#C7D8F7", "#86A8E9", 0.85),
], "#FFFFFF", 0.85)
dark = build(("#030716", "#08144A", "#170B44"), "#3D6BFF", [
    (110, 70, 0.3, 220, -0.10, "#5B8BFF", "#1F3FC8", "#0B1460", 0.75),
    (320, 90, 1.4, 260, -0.12, "#7AA2FF", "#2A52E8", "#1A0F70", 0.80),
    (560, 80, 2.6, 240, -0.10, "#9A7BFF", "#4A2BD8", "#140A5A", 0.78),
    (790, 70, 3.5, 300, -0.08, "#4F7BFF", "#1C36B8", "#0A0C40", 0.85),
], "#BFD3FF", 0.75)
open("luma-ondas-claro.svg", "w", encoding="utf-8", newline="\n").write(light)
open("luma-ondas-escuro.svg", "w", encoding="utf-8", newline="\n").write(dark)
print("ok")
