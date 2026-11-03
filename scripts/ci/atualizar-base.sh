#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Base fixada por digest (F6-08, decisão 0009): resolve o digest atual das imagens Fedora usadas no build e compara
# com build/base.env. Nada muda sozinho: para trocar a base, rode com --gravar, revise e faça commit (o CI inteiro
# roda antes de publicar).
#   atualizar-base.sh            mostra os digests atuais e se diferem do base.env (aviso no GitHub Actions)
#   atualizar-base.sh --gravar   reescreve build/base.env com os digests atuais
# O digest é o do índice (lista multi-arquitetura): sha256 do manifesto bruto, o mesmo que "nome@sha256:…" usa.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV="$ROOT/build/base.env"
VERSAO="${FEDORA_VERSION:-44}"
declare -A IMAGENS=([BASE_DIGEST]="quay.io/fedora/fedora-kinoite:$VERSAO" [TOOLS_DIGEST]="quay.io/fedora/fedora:$VERSAO")
command -v skopeo >/dev/null || { echo "atualizar-base.sh: precisa do skopeo" >&2; exit 1; }
atual() { grep -E "^$1=" "$ENV" 2>/dev/null | cut -d= -f2 || true; }

declare -A novo
mudou=0
for var in BASE_DIGEST TOOLS_DIGEST; do
	d="sha256:$(skopeo inspect --raw "docker://${IMAGENS[$var]}" | sha256sum | cut -c1-64)"
	novo[$var]="$d"
	velho="$(atual "$var")"
	if [ "$d" = "$velho" ]; then
		echo "$var ${IMAGENS[$var]}: $d (igual ao base.env)"
	else
		echo "$var ${IMAGENS[$var]}: $d (base.env: ${velho:-ausente})"
		mudou=1
	fi
done

if [ "${1:-}" = --gravar ]; then
	{
		echo "# Gerado por scripts/ci/atualizar-base.sh em $(date -u +%F) (Fedora $VERSAO). Não editar à mão."
		echo "BASE_DIGEST=${novo[BASE_DIGEST]}"
		echo "TOOLS_DIGEST=${novo[TOOLS_DIGEST]}"
	} >"$ENV"
	echo "gravado: $ENV"
elif [ "$mudou" = 1 ] && [ -n "${GITHUB_ACTIONS:-}" ]; then
	echo "::warning::Base Fedora nova disponível; rode scripts/ci/atualizar-base.sh --gravar e faça commit (F6-08)"
fi
