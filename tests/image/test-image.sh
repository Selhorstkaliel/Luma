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
# shellcheck disable=SC2329  # chamada indiretamente por check
enabled() { systemctl is-enabled -q "$1" 2>/dev/null || test -L "/etc/systemd/system/multi-user.target.wants/$1"; }

check F0-I01 "os-release: ID=luma" test "$(osr ID)" = luma
check F0-I02 "os-release: ID_LIKE contém fedora" grep -qw fedora <<<"$(osr ID_LIKE)"
check F0-I03 "os-release: VERSION_ID da base preservado" test -n "$(osr VERSION_ID)"
check F0-I04 "os-release: PLATFORM_ID da base preservado" test -n "$(osr PLATFORM_ID)"
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
