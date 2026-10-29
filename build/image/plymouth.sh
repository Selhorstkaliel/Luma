#!/usr/bin/env bash
# Tela de boot Luma (Fase 2): tema Plymouth "luma" = módulo two-step do tema "spinner" do Fedora, com o
# logotipo Luma (watermark.png, gerado no estágio "tema") sobre o fundo Midnight (#080D19, barra superior
# do mockup; docs/design/midnight-tokens.md). O tema vai no initramfs, então o initramfs é regenerado aqui.
set -euo pipefail
dst=/usr/share/plymouth/themes/luma
src=/usr/share/plymouth/themes/spinner
[ -s "$dst/watermark.png" ] || { echo "plymouth: watermark.png do Luma ausente" >&2; exit 1; }
[ -f "$src/spinner.plymouth" ] || dnf -y install plymouth-theme-spinner
# Animação e demais imagens do spinner; o watermark do Luma não é sobrescrito
cp -n "$src"/*.png "$dst/"
sed -e 's/^Name=.*/Name=Luma/' \
    -e 's/^Description=.*/Description=Luma Midnight: logotipo Luma sobre fundo escuro/' \
    -e "s#^ImageDir=.*#ImageDir=$dst#" \
    -e 's/^BackgroundStartColor=.*/BackgroundStartColor=0x080d19/' \
    -e 's/^BackgroundEndColor=.*/BackgroundEndColor=0x080d19/' \
    "$src/spinner.plymouth" > "$dst/luma.plymouth"
echo "--- luma.plymouth (evidência) ---"; cat "$dst/luma.plymouth"; echo "---"
grep -qx "ImageDir=$dst" "$dst/luma.plymouth" || { echo "plymouth: ImageDir não ajustado" >&2; exit 1; }
plymouth-set-default-theme luma
[ "$(plymouth-set-default-theme)" = luma ] || { echo "plymouth: tema padrão não é luma" >&2; exit 1; }

# Initramfs com o tema novo (padrão das imagens bootc derivadas: dracut no build, kernel único da imagem)
kver="$(ls /usr/lib/modules)"
[ "$(wc -w <<<"$kver")" = 1 ] || { echo "plymouth: esperado 1 kernel, encontrado: $kver" >&2; exit 1; }
dracut --no-hostonly --kver "$kver" --reproducible --zstd --add ostree -f "/usr/lib/modules/$kver/initramfs.img"
# Sem "| grep -q": com pipefail o SIGPIPE do lsinitrd viraria falha (mesmo erro do run ci 40634925786)
listing="$(lsinitrd "/usr/lib/modules/$kver/initramfs.img")"
grep -q 'plymouth/themes/luma/luma.plymouth' <<<"$listing" \
	|| { echo "plymouth: tema luma não entrou no initramfs" >&2; exit 1; }
echo "plymouth: tema luma no initramfs de $kver"
