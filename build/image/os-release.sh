#!/usr/bin/env bash
# Reescreve a identidade do sistema em os-release a partir do arquivo da base.
# Mantém VERSION_ID, SUPPORT_END (fim de suporte da base), PLATFORM_ID quando existir (a Kinoite 44 não o traz,
# visto no CI) e demais campos de versão (dnf, toolbox e bootc dependem deles) e troca
# só nome, ID e endereços. ID=luma com ID_LIKE=fedora é hipótese a validar na VM [H] (decisão 0010).
# uso: os-release.sh ARQUIVO VERSAO_LUMA
set -euo pipefail
f="${1:?uso: os-release.sh ARQUIVO VERSAO_LUMA}"
v="${2:?uso: os-release.sh ARQUIVO VERSAO_LUMA}"
[ -f "$f" ] || { echo "os-release não encontrado: $f" >&2; exit 1; }
f="$(realpath "$f")"   # /etc/os-release costuma ser link para /usr/lib/os-release
grep -q '^VERSION_ID=' "$f" || { echo "base sem VERSION_ID em $f" >&2; exit 1; }
base_version="$(sed -n 's/^VERSION_ID=//p' "$f" | tr -d '"')"

tmp="$(mktemp)"
# Remove os campos que passam a ser do Luma; o restante da base é preservado na ordem original
grep -vE '^(NAME|PRETTY_NAME|ID|ID_LIKE|VARIANT|VARIANT_ID|HOME_URL|DOCUMENTATION_URL|SUPPORT_URL|BUG_REPORT_URL|LOGO|ANSI_COLOR|CPE_NAME|DEFAULT_HOSTNAME|IMAGE_VERSION|REDHAT_[A-Z_]*)=' "$f" > "$tmp" || true
{
	echo 'NAME="Luma-OS"'
	echo "PRETTY_NAME=\"Luma-OS $v Midnight (base Fedora $base_version)\""
	echo 'ID=luma'
	echo 'ID_LIKE="fedora"'
	echo 'VARIANT="Midnight Edition"'
	echo 'VARIANT_ID=midnight'
	echo "IMAGE_VERSION=\"$v\""
	echo 'DEFAULT_HOSTNAME="luma"'
	echo 'HOME_URL="https://github.com/Selhorstkaliel/Luma"'
	echo 'BUG_REPORT_URL="https://github.com/Selhorstkaliel/Luma/issues"'
	echo 'LOGO=luma-logo'
	cat "$tmp"
} > "$f"
rm -f "$tmp"
