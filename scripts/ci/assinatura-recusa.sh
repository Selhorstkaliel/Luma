#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# F6-07: o Luma recusa imagem do seu canal (ghcr.io/selhorstkaliel/luma) sem assinatura ou assinada por outra chave.
# Executar como root no runner do CI, depois da publicação assinada (iso.yml):
#   assinatura-recusa.sh IMAGEM_LOCAL    (ex.: localhost/luma:44)
# Nada sem assinatura vai para o GHCR: as imagens de teste ficam num registro local (localhost:5000), servido como
# MIRROR de ghcr.io/selhorstkaliel/luma. Com mirror, o containers/image avalia a política pelo nome lógico
# (ghcr.io/...), então vale a regra sigstoreSigned da própria imagem. A verificação roda DENTRO da imagem Luma, com
# o skopeo dela (o mesmo que o bootc usa pelo containers-image-proxy [H]).
set -euo pipefail
img="${1:?uso: assinatura-recusa.sh IMAGEM_LOCAL}"
CANAL=ghcr.io/selhorstkaliel/luma
REG=localhost:5000
tmp="$(mktemp -d /var/tmp/luma-recusa.XXXXXX)"
log() { printf '[F6-07] %s\n' "$*" >&2; }
# Chamada pelo trap (SC2317/SC2329 no ShellCheck)
# shellcheck disable=SC2317,SC2329
limpa() { podman rm -f luma-reg >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap limpa EXIT

# 1. Registro local descartável
podman run -d --name luma-reg -p 5000:5000 docker.io/library/registry:2.8.3 >/dev/null
for _ in $(seq 1 20); do curl -sf "http://$REG/v2/" >/dev/null && break; sleep 1; done

# 2. Imagens de teste mínimas (a política vale pelo nome do repositório, não pelo conteúdo)
mkdir -p "$tmp/ctx"
echo "imagem de teste F6-07: não é o Luma" >"$tmp/ctx/LEIA-ME"
printf 'FROM scratch\nCOPY LEIA-ME /LEIA-ME\n' >"$tmp/ctx/Containerfile"
podman build -q -t "$REG/luma:teste-sem-assinatura" "$tmp/ctx" >/dev/null
podman tag "$REG/luma:teste-sem-assinatura" "$REG/luma:teste-chave-errada"
podman push -q --tls-verify=false "$REG/luma:teste-sem-assinatura"
podman push -q --tls-verify=false "$REG/luma:teste-chave-errada"

# Chave descartável, gerada aqui e apagada no fim; nunca a chave do projeto. Sem envio ao Rekor público.
(cd "$tmp" && COSIGN_PASSWORD=teste-f6-07 cosign generate-key-pair >/dev/null 2>&1)
COSIGN_PASSWORD=teste-f6-07 cosign sign --yes --key "$tmp/cosign.key" --tlog-upload=false --allow-insecure-registry \
	"$REG/luma:teste-chave-errada" >/dev/null 2>&1
log "imagens de teste no registro local: teste-sem-assinatura (nenhuma assinatura), teste-chave-errada (chave descartável)"

# 3. Mirror do canal e anexos sigstore também no mirror
cat >"$tmp/99-luma-teste.conf" <<EOF
[[registry]]
prefix = "$CANAL"
location = "$CANAL"
[[registry.mirror]]
location = "$REG/luma"
insecure = true
EOF
printf 'docker:\n  %s/luma:\n    use-sigstore-attachments: true\n' "$REG" >"$tmp/luma-teste.yaml"
mkdir -p "$tmp/out"

tenta() {
	podman run --rm --network host \
		-v "$tmp/99-luma-teste.conf:/etc/containers/registries.conf.d/99-luma-teste.conf:ro" \
		-v "$tmp/luma-teste.yaml:/etc/containers/registries.d/luma-teste.yaml:ro" \
		-v "$tmp/out:/out" "$img" \
		skopeo copy "docker://$CANAL:$1" "dir:/out/$1" 2>&1
}
podman run --rm "$img" sh -c 'command -v skopeo' >/dev/null || { log "FALHOU: a imagem não tem skopeo"; exit 1; }
log "política da imagem para o canal: $(podman run --rm "$img" python3 -c "import json; print(json.load(open('/etc/containers/policy.json'))['transports']['docker'].get('$CANAL'))")"

falhas=0
for tag in teste-sem-assinatura teste-chave-errada; do
	if out="$(tenta "$tag")"; then
		log "FALHOU: $CANAL:$tag foi ACEITA: $(tail -n 3 <<<"$out" | tr '\n' ' ')"; falhas=$((falhas + 1))
	elif grep -qiE 'signature|signed' <<<"$out"; then
		log "PASSOU: $CANAL:$tag recusada: $(grep -iE 'signature|signed' <<<"$out" | tail -n 1)"
	else
		log "FALHOU: $CANAL:$tag deu erro, mas não de assinatura (rede?): $(tail -n 3 <<<"$out" | tr '\n' ' ')"; falhas=$((falhas + 1))
	fi
done
# Controle positivo: a imagem assinada do canal continua aceita com o mirror configurado
if out="$(tenta "${POSITIVO_TAG:-44}")"; then
	log "PASSOU: $CANAL:${POSITIVO_TAG:-44} (assinada pela chave do projeto) aceita"
else
	log "FALHOU: a imagem assinada foi recusada: $(tail -n 3 <<<"$out" | tr '\n' ' ')"; falhas=$((falhas + 1))
fi
rm -rf "$tmp/out"
[ "$falhas" = 0 ] && { log "F6-07 PASSOU"; exit 0; }
log "F6-07 FALHOU ($falhas)"; exit 1
