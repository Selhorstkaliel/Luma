#!/usr/bin/env bash
# Marca Luma no Anaconda (F6-05): rasteriza o fundo da barra lateral, a faixa superior e o logotipo para os
# nomes que o CSS do Anaconda carrega de /usr/share/anaconda/pixmaps [H: nomes; o Containerfile.installer
# registra no log quais o CSS realmente usa]. Arte original (decisão 0010).
#   build.sh DIR_REPO DIR_SAIDA
set -euo pipefail
src="${1:?uso: build.sh DIR_REPO DIR_SAIDA}"; out="${2:?}"
command -v rsvg-convert >/dev/null || { echo "rsvg-convert ausente (Fedora: librsvg2-tools)" >&2; exit 2; }
mkdir -p "$out"
rsvg-convert -w 300 -h 1600 "$src/installer/anaconda/sidebar-bg.svg" -o "$out/sidebar-bg.png"
rsvg-convert -w 64 -h 64 "$src/installer/anaconda/topbar-bg.svg" -o "$out/topbar-bg.png"
rsvg-convert -w 128 -h 128 "$src/icons/luma-logo.svg" -o "$out/sidebar-logo.png"
ls -l "$out"
