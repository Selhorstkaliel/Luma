#!/usr/bin/env bash
# Testes da imagem construída, executados DENTRO do container (sem boot):
#   podman run --rm -v "$PWD/tests/image:/t:ro,z" localhost/luma:44 /t/test-image.sh
# Confere o que as Fases 0 e 2 prometem. O que só o boot comprova (getenforce, nmap) é teste de VM (docs/TESTS.md).
set -uo pipefail
fails=0
check() {
	local id="$1" desc="$2"; shift 2
	if "$@" >/dev/null 2>&1; then echo "PASSOU $id $desc"; else echo "FALHOU $id $desc"; fails=$((fails + 1)); fi
}
osr() { sed -n "s/^$1=//p" /usr/lib/os-release | tr -d '"'; }
# Sem systemd em execução no container, is-enabled pode não responder; o link criado pelo enable também vale
# Chamada indiretamente por check (SC2317 no ShellCheck 0.9 do CI, SC2329 nas versões novas)
# shellcheck disable=SC2317,SC2329
enabled() { systemctl is-enabled -q "$1" 2>/dev/null || test -L "/etc/systemd/system/multi-user.target.wants/$1"; }

check F0-I01 "os-release: ID=luma" test "$(osr ID)" = luma
check F0-I02 "os-release: ID_LIKE contém fedora" grep -qw fedora <<<"$(osr ID_LIKE)"
check F0-I03 "os-release: VERSION_ID da base preservado" test -n "$(osr VERSION_ID)"
# Campos que o Luma substitui (os-release.sh); todo o resto da base precisa continuar idêntico
OWN='^(NAME|PRETTY_NAME|ID|ID_LIKE|VARIANT|VARIANT_ID|HOME_URL|DOCUMENTATION_URL|SUPPORT_URL|BUG_REPORT_URL|LOGO|ANSI_COLOR|CPE_NAME|DEFAULT_HOSTNAME|IMAGE_VERSION|REDHAT_[A-Z_]*)='
BASE=/usr/share/luma/base-os-release
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
base_fields_kept() {
	[ -s "$BASE" ] || return 1
	local missing
	missing="$(grep -E '^[A-Z_]+=' "$BASE" | grep -vE "$OWN" | grep -vxF -f /usr/lib/os-release)"
	[ -z "$missing" ] || { echo "campos da base alterados ou ausentes:" >&2; echo "$missing" >&2; return 1; }
}
echo "--- os-release da base (evidência) ---"; cat "$BASE" 2>/dev/null || echo "(ausente)"; echo "---"
check F0-I04 "os-release: demais campos da base preservados" base_fields_kept
check F0-I05 "zona luma instalada" test -f /usr/lib/firewalld/zones/luma.xml
check F0-I06 "zona padrão do firewalld = luma" test "$(firewall-offline-cmd --get-default-zone)" = luma
check F0-I07 "zona luma sem serviços além de dhcpv6-client" test "$(firewall-offline-cmd --zone=luma --list-services)" = dhcpv6-client
check F0-I08 "zona luma sem portas abertas" test -z "$(firewall-offline-cmd --zone=luma --list-ports)"
check F0-I09 "firewalld habilitado no boot" enabled firewalld.service
check F0-I10 "SELinux configurado enforcing" grep -qx 'SELINUX=enforcing' /etc/selinux/config
check F0-I11 "bootc presente" command -v bootc
check F0-I12 "sem resíduo do build" test ! -e /tmp/luma-build

# Fase 2, incremento 1: tema Luma instalado e padrão para usuários novos
# XDG_CONFIG_DIRS como a sessão o recebe: scripts de login e de ambiente do Plasma (aproximação [H]; a VM confirma)
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
session_xdg() {
	bash -c 'for f in /etc/profile.d/*.sh /etc/xdg/plasma-workspace/env/*.sh; do [ -r "$f" ] && . "$f"; done >/dev/null 2>&1; echo "${XDG_CONFIG_DIRS:-/etc/xdg}"'
}
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
default_lnf() {
	local home v
	home="$(mktemp -d)"
	v="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_CONFIG_DIRS="$(session_xdg)" kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)"
	rm -rf "$home"
	echo "LookAndFeelPackage efetivo: $v (XDG_CONFIG_DIRS=$(session_xdg))"
	test "$v" = org.luma.dark.desktop
}
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
launchers_exist() {
	local f l rc=0
	for f in /usr/share/plasma/look-and-feel/org.luma*/contents/layouts/org.kde.plasma.desktop-layout.js; do
		for l in $(grep -o '"applications:[^"]*"' "$f" | tr -d '"' | sed 's/^applications://'); do
			[ -f "/usr/share/applications/$l" ] || { echo "lançador ausente: $l ($f)" >&2; rc=1; }
		done
	done
	return $rc
}
LNF=/usr/share/plasma/look-and-feel
check F2-I01 "Look-and-Feel Luma claro e escuro com layout" test -f $LNF/org.luma.desktop/contents/layouts/org.kde.plasma.desktop-layout.js -a -f $LNF/org.luma.dark.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
check F2-I02 "esquemas de cores, Aurorae e Central de Controle" test -f /usr/share/color-schemes/LumaDark.colors -a -f /usr/share/aurorae/themes/LumaEscuro/decoration.svg -a -f /usr/share/plasma/plasmoids/org.luma.controlcenter/metadata.json
check F2-I03 "wallpaper Luma rasterizado (claro e escuro)" test -s /usr/share/wallpapers/Luma/contents/images/1920x1080.png -a -s /usr/share/wallpapers/Luma/contents/images_dark/1920x1080.png
check F2-I04 "ícone luma-logo e luma-appearance" test -f /usr/share/icons/hicolor/scalable/apps/luma-logo.svg -a -x /usr/bin/luma-appearance
check F2-I05 "LookAndFeelPackage padrão = org.luma.dark.desktop" default_lnf
check F2-I06 "dependências do tema (Papirus-Dark, fonte Inter)" test -d /usr/share/icons/Papirus-Dark -a -n "$(fc-list Inter family)"
check F2-I07 "sem fedora-logos" bash -c '! rpm -q fedora-logos'
check F2-I08 "lançadores do dock existem na imagem" launchers_exist
default_lnf || true
launchers_exist || true

echo "falhas: $fails"
exit $((fails > 0))
