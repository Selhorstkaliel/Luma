#!/usr/bin/env bash
# Testes da imagem construída, executados DENTRO do container (sem boot):
#   podman run --rm -v "$PWD/tests/image:/t:ro,z" localhost/luma:44 /t/test-image.sh
# Confere o que a Fase 0 promete. O que só o boot comprova (getenforce, nmap) é teste de VM (docs/TESTS.md).
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

echo "falhas: $fails"
exit $((fails > 0))
