# Imagem bootc do Luma-OS (decisão 0008): derivada da Fedora Kinoite oficial.
# Identidade (os-release), firewall de entrada fechada e, desde a Fase 2 (incremento 1), o tema Luma como padrão.
#   podman build --build-arg FEDORA_VERSION=44 -t localhost/luma:44 .
# A base ainda é referenciada por tag; fixar por digest é tarefa da Fase 1 (decisão 0009).
ARG BASE_IMAGE=quay.io/fedora/fedora-kinoite
ARG TOOLS_IMAGE=quay.io/fedora/fedora
ARG FEDORA_VERSION=44

# Estágio de montagem do tema: rasteriza os wallpapers (rsvg-convert) sem levar a ferramenta para a imagem final
FROM ${TOOLS_IMAGE}:${FEDORA_VERSION} AS tema
RUN dnf -y install librsvg2-tools && dnf clean all
COPY themes/ /src/themes/
COPY plasma/ /src/plasma/
COPY icons/ /src/icons/
COPY wallpapers/ /src/wallpapers/
RUN /src/themes/build.sh /out

FROM ${BASE_IMAGE}:${FEDORA_VERSION}

ARG FEDORA_VERSION
ARG LUMA_VERSION=0.9.0-dev

COPY configs/usr/ /usr/
COPY configs/etc/ /etc/
COPY --from=tema /out/usr/ /usr/
COPY themes/bin/luma-appearance /usr/bin/luma-appearance
# App Ajustes (Fase 3): módulo Python + QML; PySide6 entra pelo build.sh
COPY apps/settings/luma_ajustes/ /usr/share/luma-ajustes/luma_ajustes/
COPY apps/settings/data/luma-ajustes /usr/bin/luma-ajustes
COPY apps/settings/data/org.luma.ajustes.desktop /usr/share/applications/org.luma.ajustes.desktop
COPY apps/settings/data/luma-ajustes.1 /usr/share/man/man1/luma-ajustes.1
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
