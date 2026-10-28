#!/usr/bin/env bash
# Monta a árvore instalável do tema em ${1:-build/theme-root}.
# Herdado do LUMA-OS (debian/rules); na edição Fedora será usado pelo build da imagem (Fase 2).
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(realpath -m "${1:-../build/theme-root}")"
command -v rsvg-convert >/dev/null || { echo "rsvg-convert ausente (Fedora: librsvg2-tools; Debian: librsvg2-bin)" >&2; exit 2; }
rm -rf "$OUT"
share="$OUT/usr/share"
mkdir -p "$share/plasma/look-and-feel" "$share/color-schemes" "$share/wallpapers/Luma/contents/images" "$share/wallpapers/Luma/contents/images_dark"
for p in look-and-feel/*/; do
	id="$(basename "$p")"
	cp -r "$p" "$share/plasma/look-and-feel/$id"
	mkdir -p "$share/plasma/look-and-feel/$id/contents/layouts"
	cp ../plasma/layouts/luma-layout.js "$share/plasma/look-and-feel/$id/contents/layouts/org.kde.plasma.desktop-layout.js"
done
cp color-schemes/*.colors "$share/color-schemes/"
mkdir -p "$share/aurorae/themes" "$share/icons/hicolor/scalable/apps"
cp -r aurorae/Luma aurorae/LumaEscuro "$share/aurorae/themes/"
cp ../icons/luma-logo.svg ../icons/luma-controlcenter.svg "$share/icons/hicolor/scalable/apps/"
mkdir -p "$share/plasma/plasmoids"
cp -r ../plasma/plasmoids/org.luma.controlcenter "$share/plasma/plasmoids/"
cp ../wallpapers/Luma/metadata.json "$share/wallpapers/Luma/"
for size in 1366x768 1920x1080 2560x1440 3840x2160; do
	w="${size%x*}"; h="${size#*x}"
	rsvg-convert -w "$w" -h "$h" ../wallpapers/Luma/src/luma-ondas-claro.svg -o "$share/wallpapers/Luma/contents/images/$size.png"
	rsvg-convert -w "$w" -h "$h" ../wallpapers/Luma/src/luma-ondas-escuro.svg -o "$share/wallpapers/Luma/contents/images_dark/$size.png"
done
rsvg-convert -w 440 -h 247 ../wallpapers/Luma/src/luma-ondas-claro.svg -o "$share/wallpapers/Luma/contents/screenshot.png"
echo "tema montado em $OUT"
