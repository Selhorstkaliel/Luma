#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Trava da atualização automática da base (F6-09): o commit do bot só pode trocar os digests fixados (F6-08).
# Sai 0 sem mudança, 10 se só os digests mudaram, 1 se houver qualquer outra alteração no repositório.
set -euo pipefail
cd "${1:-.}"
[ -z "$(git status --porcelain)" ] && { echo "base igual: nada a commitar"; exit 0; }
arquivos="$(git status --porcelain | awk '{print $2}' | LC_ALL=C sort | tr '\n' ' ')"
case "$arquivos" in
	"Containerfile "|"Containerfile build/iso/Containerfile.installer "|"build/iso/Containerfile.installer ") ;;
	*) echo "FALHOU: arquivos fora do permitido: $arquivos" >&2; exit 1 ;;
esac
ruim="$(git diff -U0 -- Containerfile build/iso/Containerfile.installer | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) ' \
	| grep -vE '^[+-]ARG (BASE|TOOLS)_DIGEST=sha256:[0-9a-f]{64}$' \
	| grep -vE '^[+-]ARG TOOLS_IMAGE=quay\.io/fedora/fedora:[0-9]+@sha256:[0-9a-f]{64}$' || true)"
[ -z "$ruim" ] || { echo "FALHOU: linhas além dos digests mudaram:"; echo "$ruim"; exit 1; } >&2
echo "só os digests da base mudaram"
exit 10
