#!/usr/bin/env bash
# Executado dentro do Containerfile, como root, sobre a Fedora Kinoite. Cada passo confere o próprio resultado.
set -euo pipefail
: "${LUMA_VERSION:?}" "${FEDORA_VERSION:?}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Guarda o os-release da base antes de reescrevê-lo: registro do que veio do Fedora e referência dos testes
install -D -m 0644 "$(realpath /usr/lib/os-release)" /usr/share/luma/base-os-release
"$HERE/os-release.sh" /usr/lib/os-release "$LUMA_VERSION"

# Firewall: zona "luma" (entrada fechada, decisão 0008) como padrão. A ferramenta oficial grava a
# configuração onde o firewalld a procura; o resultado é conferido em vez de presumido.
firewall-offline-cmd --set-default-zone=luma >/dev/null
zone="$(firewall-offline-cmd --get-default-zone)"
[ "$zone" = luma ] || { echo "zona padrão do firewalld é '$zone', esperado 'luma'" >&2; exit 1; }
systemctl enable firewalld.service
# Hostname genérico do instalador vira o padrão Luma, uma vez (configs/usr/libexec/luma/luma-hostname)
systemctl enable luma-hostname.service

# Tema (Fase 2, incremento 1): ícones Papirus (GPL-3.0) e fonte Inter (OFL-1.1) usados pelos pacotes Look-and-Feel
dnf -y install papirus-icon-theme rsms-inter-fonts
# Sem pipe: com pipefail, "fc-list | grep -q" falha por SIGPIPE quando acha (run ci 40634925786)
[ -n "$(fc-list Inter family)" ] || { echo "fonte Inter não encontrada após instalar rsms-inter-fonts" >&2; exit 1; }

# Marca: sem logos do Fedora (decisão 0010). generic-logos fornece o mesmo "system-logos" com arte neutra.
dnf -y swap fedora-logos generic-logos
! rpm -q fedora-logos >/dev/null 2>&1 || { echo "fedora-logos continua instalado" >&2; exit 1; }

# Tela de boot Luma (Plymouth) e initramfs regenerado; antes da limpeza do dnf (pode instalar o spinner)
"$HERE/plymouth.sh"

dnf clean all
# Resíduo do dnf em /var e /run vira aviso do bootc container lint (run ci 40635971059); /var é do sistema instalado
rm -rf /var/lib/dnf /var/cache/libdnf5 /var/log/dnf5.log* /run/dnf

# Dock: o nome do .desktop do Firefox varia entre versões do Fedora; usar o que a base realmente tem
ff=""
for cand in org.mozilla.firefox.desktop firefox.desktop; do
	[ -f "/usr/share/applications/$cand" ] && { ff="$cand"; break; }
done
for layout in /usr/share/plasma/look-and-feel/org.luma*/contents/layouts/org.kde.plasma.desktop-layout.js; do
	if [ -n "$ff" ]; then
		sed -i "s/applications:org\.mozilla\.firefox\.desktop/applications:$ff/" "$layout"
	else
		sed -i '/applications:org\.mozilla\.firefox\.desktop/d' "$layout"
	fi
done
echo "luma: Firefox no dock: ${ff:-ausente na base, removido}"

# Evidência para a precedência dos padrões (kde-settings × /etc/xdg); conferida em tests/image/test-image.sh
echo "--- XDG_CONFIG_DIRS e LookAndFeelPackage definidos pela base ---"
grep -rsn 'XDG_CONFIG_DIRS' /etc/profile.d /etc/xdg/plasma-workspace/env || true
grep -rsn 'LookAndFeelPackage' /etc/xdg /usr/share/kde-settings || true
echo "---"


# SELinux continua enforcing (padrão do Fedora); falhar se a base vier diferente
grep -qx 'SELINUX=enforcing' /etc/selinux/config || { echo "SELinux não está enforcing em /etc/selinux/config" >&2; exit 1; }

echo "luma: imagem $LUMA_VERSION sobre Fedora Kinoite $FEDORA_VERSION preparada"
