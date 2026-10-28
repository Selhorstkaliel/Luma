#!/usr/bin/env bash
# Executado dentro do Containerfile, como root, sobre a Fedora Kinoite. Cada passo confere o próprio resultado.
set -euo pipefail
: "${LUMA_VERSION:?}" "${FEDORA_VERSION:?}"
HERE="$(cd "$(dirname "$0")" && pwd)"

"$HERE/os-release.sh" /usr/lib/os-release "$LUMA_VERSION"

# Firewall: zona "luma" (entrada fechada, decisão 0008) como padrão. A ferramenta oficial grava a
# configuração onde o firewalld a procura; o resultado é conferido em vez de presumido.
firewall-offline-cmd --set-default-zone=luma >/dev/null
zone="$(firewall-offline-cmd --get-default-zone)"
[ "$zone" = luma ] || { echo "zona padrão do firewalld é '$zone', esperado 'luma'" >&2; exit 1; }
systemctl enable firewalld.service

# SELinux continua enforcing (padrão do Fedora); falhar se a base vier diferente
grep -qx 'SELINUX=enforcing' /etc/selinux/config || { echo "SELinux não está enforcing em /etc/selinux/config" >&2; exit 1; }

echo "luma: imagem $LUMA_VERSION sobre Fedora Kinoite $FEDORA_VERSION preparada"
