#!/usr/bin/env bash
# Testes da imagem construída, executados DENTRO do container (sem boot):
#   podman run --rm -v "$PWD/tests/image:/t:ro,z" localhost/luma:44 /t/test-image.sh
# Confere o que as Fases 0 a 4 prometem. O que só o boot comprova (getenforce, nmap) é teste de VM (docs/TESTS.md).
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
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
initramfs_has_luma() {
	local img listing
	img="$(ls /usr/lib/modules/*/initramfs.img)"
	listing="$(lsinitrd "$img")"
	grep -q 'plymouth/themes/luma/luma.plymouth' <<<"$listing"
}
check F2-I09 "tela de boot: tema Plymouth padrão = luma" test "$(plymouth-set-default-theme)" = luma
check F2-I10 "tema Plymouth luma dentro do initramfs" initramfs_has_luma
check F3-I01 "Ajustes: PySide6 e módulo luma_ajustes importam" env PYTHONPATH=/usr/share/luma-ajustes python3 -c "import PySide6.QtQml, luma_ajustes.core, luma_ajustes.app"
check F3-I02 "Ajustes: interface QML (Kirigami) carrega" env QT_QPA_PLATFORM=offscreen HOME=/tmp luma-ajustes --verificar
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
desktop_ok() {
	local f=/usr/share/applications/org.luma.ajustes.desktop
	if command -v desktop-file-validate >/dev/null; then desktop-file-validate "$f"; else grep -qx 'Exec=luma-ajustes' "$f"; fi
}
check F3-I03 "Ajustes: lançador .desktop válido" desktop_ok
check F4-I01 "jogos: gamemoderun, mangohud e gamescope presentes" bash -c 'command -v gamemoderun && command -v mangohud && command -v gamescope'
check F4-I02 "jogos: luma-jogos gera os comandos Flatpak de usuário" bash -c 'luma-jogos --simular instalar steam | grep -q "flatpak install --user"'
# A Kinoite traz arquivos .repo do RPM Fusion DESABILITADOS (fedora-workstation-repositories) [H]; a decisão
# 0012 proíbe pacotes do RPM Fusion e repositório RPM Fusion habilitado, não os arquivos da base (ci #21).
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
no_rpmfusion() {
	local repos pkgs
	repos="$(grep -lis '^enabled *= *1' /etc/yum.repos.d/*rpmfusion*.repo 2>/dev/null || true)"
	pkgs="$(rpm -qa --qf '%{NAME} %{VENDOR} %{PACKAGER}\n' | grep -i rpmfusion || true)"
	[ -z "$repos" ] || { echo "repositório RPM Fusion habilitado: $repos" >&2; return 1; }
	[ -z "$pkgs" ] || { echo "pacotes do RPM Fusion: $pkgs" >&2; return 1; }
}
check F4-I03 "jogos: nenhum pacote nem repositório habilitado do RPM Fusion (decisão 0012)" no_rpmfusion
# Fase 5: controles estáticos de segurança (os dinâmicos, como nmap e AVCs, são da VM: sudo luma-diagnostico)
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
luma_files_not_world_writable() {
	local bad
	bad="$(find /usr/bin/luma-* /usr/libexec/luma /usr/share/luma-ajustes /usr/share/plasma/look-and-feel/org.luma* \
		/usr/share/plymouth/themes/luma /etc/xdg/kdeglobals /etc/xdg/kwinrc /etc/xdg/kscreenlockerrc \
		/usr/lib/firewalld/zones/luma.xml -perm -0002 ! -type l 2>/dev/null)"
	[ -z "$bad" ] || { echo "graváveis por todos: $bad" >&2; return 1; }
}
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
sshd_not_enabled() { ! enabled sshd.service; }
check F5-I01 "SSH desligado por padrão" sshd_not_enabled
check F5-I02 "arquivos do Luma não graváveis por todos" luma_files_not_world_writable
# shellcheck disable=SC2317,SC2329  # chamada indiretamente por check
zone_not_accept() { ! grep -q 'target="ACCEPT"' /usr/lib/firewalld/zones/luma.xml; }
check F5-I03 "zona luma sem alvo ACCEPT (entrada recusada por padrão)" zone_not_accept
check F5-I04 "luma-diagnostico mede boot, RAM e AVCs" grep -q 'ausearch -m avc' /usr/bin/luma-diagnostico
check F1-I01 "luma-hostname habilitado no boot" enabled luma-hostname.service
check F1-I02 "luma-diagnostico instalado" test -x /usr/bin/luma-diagnostico
default_lnf || true
launchers_exist || true
echo "--- arquivos RPM Fusion da base (evidência) ---"
for f in /etc/yum.repos.d/*rpmfusion*.repo; do [ -e "$f" ] && echo "$f: $(grep -ci '^enabled *= *1' "$f") seção(ões) habilitada(s)"; done
no_rpmfusion || true
echo "--- luma-ajustes --verificar (evidência) ---"; QT_QPA_PLATFORM=offscreen HOME=/tmp luma-ajustes --verificar 2>&1 | tail -n 20 || true

echo "falhas: $fails"
exit $((fails > 0))
