# Imagem bootc do Luma-OS (decisão 0008): derivada da Fedora Kinoite oficial.
# Fase 0: só identidade (os-release) e firewall de entrada fechada. Tema, apps e gaming vêm nas fases seguintes.
#   podman build --build-arg FEDORA_VERSION=44 -t localhost/luma:44 .
# A base ainda é referenciada por tag; fixar por digest é tarefa da Fase 1 (decisão 0009).
ARG BASE_IMAGE=quay.io/fedora/fedora-kinoite
ARG FEDORA_VERSION=44
FROM ${BASE_IMAGE}:${FEDORA_VERSION}

ARG FEDORA_VERSION
ARG LUMA_VERSION=0.9.0-dev

COPY configs/usr/ /usr/
COPY build/image/ /tmp/luma-build/
RUN LUMA_VERSION="${LUMA_VERSION}" FEDORA_VERSION="${FEDORA_VERSION}" /tmp/luma-build/build.sh && \
    rm -rf /tmp/luma-build

# Verificação do próprio bootc sobre a imagem final (falha o build se a imagem não for inicializável)
RUN bootc container lint

LABEL org.opencontainers.image.title="Luma-OS" \
      org.opencontainers.image.description="Luma-OS Midnight Edition (base Fedora Kinoite)" \
      org.opencontainers.image.source="https://github.com/Selhorstkaliel/Luma" \
      org.opencontainers.image.version="${LUMA_VERSION}" \
      containers.bootc="1"
