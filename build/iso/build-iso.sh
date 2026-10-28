#!/usr/bin/env bash
# Gera a ISO de instalação do Luma com o image-builder do osbuild (decisão 0011).
# Executar como root (o image-builder lê as imagens do armazenamento de containers do root).
#   build-iso.sh IMAGEM_LUMA IMAGEM_INSTALADOR DIR_SAIDA VERSAO
# Tenta o tipo bootc-installer (recomendado pelo osbuild) e, se falhar, anaconda-iso (antigo, ainda aceito
# segundo a documentação [H]); o log de cada tentativa fica em DIR_SAIDA. Nada é publicado aqui.
set -euo pipefail
payload="${1:?uso: build-iso.sh IMAGEM_LUMA IMAGEM_INSTALADOR DIR_SAIDA VERSAO}"
installer="${2:?}"; out="${3:?}"; version="${4:?}"
IB_IMAGE="${IB_IMAGE:-ghcr.io/osbuild/image-builder-cli:latest}"
[ "$(id -u)" = 0 ] || { echo "build-iso.sh: execute como root" >&2; exit 77; }

mkdir -p "$out"
out="$(realpath "$out")"
storage="$(podman info --format '{{.Store.GraphRoot}}')"
podman pull -q "$IB_IMAGE" >/dev/null
ib_digest="$(podman image inspect "$IB_IMAGE" --format '{{.Digest}}')"

# uso: ib TIPO LOG ARGUMENTOS...
ib() {
	local type="$1" log="$2"; shift 2
	rm -rf "$out/ib-$type"; mkdir -p "$out/ib-$type"
	podman run --rm --privileged --security-opt label=type:unconfined_t \
		-v "$storage:/var/lib/containers/storage" -v "$out/ib-$type:/output" \
		"$IB_IMAGE" build "$@" --output-dir /output "$type" >"$log" 2>&1
}

type=bootc-installer
if ! ib bootc-installer "$out/image-builder-bootc-installer.log" --bootc-ref "$installer" --bootc-installer-payload-ref "$payload"; then
	echo "bootc-installer falhou (log em $out/image-builder-bootc-installer.log); tentando anaconda-iso" >&2
	tail -n 30 "$out/image-builder-bootc-installer.log" >&2
	type=anaconda-iso
	if ! ib anaconda-iso "$out/image-builder-anaconda-iso.log" --bootc-ref "$payload"; then
		tail -n 30 "$out/image-builder-anaconda-iso.log" >&2
		echo "build-iso.sh: os dois tipos de ISO falharam" >&2
		exit 1
	fi
fi

found="$(find "$out/ib-$type" -type f -name '*.iso' | head -n1)"
[ -n "$found" ] || { echo "build-iso.sh: o image-builder terminou sem gerar .iso" >&2; exit 1; }
name="luma-${version}-x86_64.iso"
mv "$found" "$out/$name"
rm -rf "$out/ib-bootc-installer" "$out/ib-anaconda-iso"
(cd "$out" && sha256sum "$name" > "$name.sha256")
{
	echo "iso: $name"
	echo "sha256: $(cut -d' ' -f1 "$out/$name.sha256")"
	echo "tamanho_bytes: $(stat -c %s "$out/$name")"
	echo "tipo_image_builder: $type"
	echo "image_builder: $IB_IMAGE@$ib_digest"
	echo "imagem_luma: $payload@$(podman image inspect "$payload" --format '{{.Digest}}')"
	echo "imagem_instalador: $installer@$(podman image inspect "$installer" --format '{{.Digest}}')"
	echo "data: $(date -u +%FT%TZ)"
} > "$out/luma-${version}-x86_64.manifest"
cat "$out/luma-${version}-x86_64.manifest"
