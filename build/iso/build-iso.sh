#!/usr/bin/env bash
# Gera a ISO de instalação do Luma com o image-builder do osbuild (decisão 0011).
# Executar como root (o image-builder lê as imagens do armazenamento de containers do root).
#   build-iso.sh IMAGEM_LUMA IMAGEM_INSTALADOR DIR_SAIDA VERSAO
# Tenta o tipo bootc-installer do image-builder e, se falhar, o anaconda-iso do bootc-image-builder antigo
# (o image-builder não tem mais anaconda-iso e indica o bib na própria mensagem de erro; run iso #1).
# O log de cada tentativa fica em DIR_SAIDA. Nada é publicado aqui.
set -euo pipefail
payload="${1:?uso: build-iso.sh IMAGEM_LUMA IMAGEM_INSTALADOR DIR_SAIDA VERSAO}"
installer="${2:?}"; out="${3:?}"; version="${4:?}"
IB_IMAGE="${IB_IMAGE:-ghcr.io/osbuild/image-builder-cli:latest}"
BIB_IMAGE="${BIB_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}"   # arquivado; disponibilidade [H]
[ "$(id -u)" = 0 ] || { echo "build-iso.sh: execute como root" >&2; exit 77; }

mkdir -p "$out"
out="$(realpath "$out")"
storage="$(podman info --format '{{.Store.GraphRoot}}')"
podman pull -q "$IB_IMAGE" >/dev/null

# Kickstart do Luma sem nada destrutivo (instalador interativo); o bib lê /config.toml e o image-builder o
# recebe como blueprint (--blueprint)
CONFIG="${CONFIG:-$(cd "$(dirname "$0")" && pwd)/config.toml}"
[ -r "$CONFIG" ] || { echo "build-iso.sh: configuração do instalador ausente: $CONFIG" >&2; exit 1; }
# uso: run_tool IMAGEM DIR LOG ARGUMENTOS...  (a ferramenta enxerga o armazenamento no MESMO caminho do host)
run_tool() {
	local image="$1" dir="$2" log="$3"; shift 3
	rm -rf "$dir"; mkdir -p "$dir"
	podman run --rm --privileged --security-opt label=type:unconfined_t \
		-v "$storage:/var/lib/containers/storage" -v "$dir:/output" -v "$CONFIG:/config.toml:ro" \
		"$image" "$@" >"$log" 2>&1
}
[ "$storage" = /var/lib/containers/storage ] || echo "AVISO: armazenamento em $storage; o image-builder espera /var/lib/containers/storage" >&2

tool="$IB_IMAGE"; type=bootc-installer; dir="$out/ib-bootc-installer"; ib_fail=""
if ! run_tool "$IB_IMAGE" "$dir" "$out/image-builder-bootc-installer.log" \
	build --blueprint /config.toml --bootc-ref "$installer" --bootc-installer-payload-ref "$payload" --output-dir /output bootc-installer; then
	echo "bootc-installer falhou (log em $out/image-builder-bootc-installer.log); tentando anaconda-iso do bootc-image-builder" >&2
	tail -n 30 "$out/image-builder-bootc-installer.log" >&2
	ib_fail="$(tail -n 3 "$out/image-builder-bootc-installer.log" | tr '\n' ' ' | cut -c1-300)"
	podman pull -q "$BIB_IMAGE" >/dev/null || { echo "build-iso.sh: $BIB_IMAGE indisponível" >&2; exit 1; }
	tool="$BIB_IMAGE"; type=anaconda-iso; dir="$out/bib-anaconda-iso"
	if ! run_tool "$BIB_IMAGE" "$dir" "$out/bootc-image-builder-anaconda-iso.log" \
		--type anaconda-iso --rootfs btrfs --output /output "$payload"; then
		tail -n 30 "$out/bootc-image-builder-anaconda-iso.log" >&2
		echo "build-iso.sh: as duas ferramentas falharam" >&2
		exit 1
	fi
fi
tool_digest="$(podman image inspect "$tool" --format '{{.Digest}}')"

found="$(find "$dir" -type f -name '*.iso' | head -n1)"
[ -n "$found" ] || { echo "build-iso.sh: $tool terminou sem gerar .iso" >&2; exit 1; }
name="luma-${version}-x86_64.iso"
mv "$found" "$out/$name"
rm -rf "$out/ib-bootc-installer" "$out/bib-anaconda-iso"
(cd "$out" && sha256sum "$name" > "$name.sha256")
{
	echo "iso: $name"
	echo "sha256: $(cut -d' ' -f1 "$out/$name.sha256")"
	echo "tamanho_bytes: $(stat -c %s "$out/$name")"
	echo "tipo: $type"
	echo "kickstart: $(sha256sum "$CONFIG" | cut -d' ' -f1) ($(basename "$CONFIG"))"
	echo "ferramenta: $tool@$tool_digest"
	[ -z "$ib_fail" ] || echo "bootc_installer_falhou: $ib_fail"
	echo "imagem_luma: $payload@$(podman image inspect "$payload" --format '{{.Digest}}')"
	echo "imagem_instalador: $installer@$(podman image inspect "$installer" --format '{{.Digest}}')"
	echo "data: $(date -u +%FT%TZ)"
} > "$out/luma-${version}-x86_64.manifest"
cat "$out/luma-${version}-x86_64.manifest"
