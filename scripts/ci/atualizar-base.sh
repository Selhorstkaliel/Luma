#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Base fixada por digest (F6-08, decisão 0009): resolve o digest atual das imagens Fedora usadas no build e compara
# com os ARG BASE_DIGEST/TOOLS_DIGEST do Containerfile (fonte única; o Containerfile.installer repete o do tools).
# Nada muda sozinho: para trocar a base, rode com --gravar, revise e faça commit (o CI inteiro roda antes de publicar).
#   atualizar-base.sh            mostra os digests atuais e se diferem dos fixados (aviso no GitHub Actions)
#   atualizar-base.sh --gravar   reescreve os digests no Containerfile e no build/iso/Containerfile.installer
# O digest é o do índice (lista multi-arquitetura): sha256 do manifesto bruto, o mesmo que "nome@sha256:…" usa.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CF="$ROOT/Containerfile"
INST="$ROOT/build/iso/Containerfile.installer"
VERSAO="${FEDORA_VERSION:-44}"
declare -A IMAGENS=([BASE_DIGEST]="quay.io/fedora/fedora-kinoite:$VERSAO" [TOOLS_DIGEST]="quay.io/fedora/fedora:$VERSAO")
command -v skopeo >/dev/null || { echo "atualizar-base.sh: precisa do skopeo" >&2; exit 1; }
fixado() { sed -n "s/^ARG $1=//p" "$CF"; }

declare -A novo
mudou=0
for var in BASE_DIGEST TOOLS_DIGEST; do
	d="sha256:$(skopeo inspect --raw "docker://${IMAGENS[$var]}" | sha256sum | cut -c1-64)"
	novo[$var]="$d"
	velho="$(fixado "$var")"
	if [ "$d" = "$velho" ]; then
		echo "$var ${IMAGENS[$var]}: $d (igual ao fixado)"
	else
		echo "$var ${IMAGENS[$var]}: $d (fixado: ${velho:-ausente})"
		mudou=1
	fi
done

if [ "${1:-}" = --gravar ]; then
	sed -i -E "s|^ARG BASE_DIGEST=.*|ARG BASE_DIGEST=${novo[BASE_DIGEST]}|; s|^ARG TOOLS_DIGEST=.*|ARG TOOLS_DIGEST=${novo[TOOLS_DIGEST]}|" "$CF"
	sed -i -E "s|^(ARG TOOLS_IMAGE=quay\.io/fedora/fedora:[0-9]+)@sha256:[0-9a-f]{64}|\1@${novo[TOOLS_DIGEST]}|" "$INST"
	echo "gravado em $CF e $INST; revise o diff e faça commit"
elif [ "$mudou" = 1 ] && [ -n "${GITHUB_ACTIONS:-}" ]; then
	echo "::warning::Base Fedora nova disponível; rode scripts/ci/atualizar-base.sh --gravar e faça commit (F6-08)"
fi
