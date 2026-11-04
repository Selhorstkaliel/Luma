# Imagem bootc do Luma-OS (decisão 0008): derivada da Fedora Kinoite oficial.
# Identidade (os-release), firewall de entrada fechada e, desde a Fase 2 (incremento 1), o tema Luma como padrão.
#   podman build --build-arg FEDORA_VERSION=44 -t localhost/luma:44 .
# Base fixada por digest (F6-08, decisão 0009): trocar só com scripts/ci/atualizar-base.sh --gravar e commit revisado.
ARG BASE_IMAGE=quay.io/fedora/fedora-kinoite
ARG TOOLS_IMAGE=quay.io/fedora/fedora
ARG FEDORA_VERSION=44
ARG BASE_DIGEST=sha256:7b2a47a009e38d8bc952f5cae5da3fd33e04253783eaf7b709dcd8b21c0ace8c
ARG TOOLS_DIGEST=sha256:4688bc8003a1a6a7815e5f9d1f1b5c6bc9cafa582654af7cec61435d91655e3b

# Estágio de montagem do tema: rasteriza os wallpapers (rsvg-convert) sem levar a ferramenta para a imagem final
FROM ${TOOLS_IMAGE}:${FEDORA_VERSION}@${TOOLS_DIGEST} AS tema
RUN dnf -y install librsvg2-tools && dnf clean all
COPY themes/ /src/themes/
COPY plasma/ /src/plasma/
COPY icons/ /src/icons/
COPY wallpapers/ /src/wallpapers/
RUN /src/themes/build.sh /out

FROM ${BASE_IMAGE}:${FEDORA_VERSION}@${BASE_DIGEST}

ARG FEDORA_VERSION
ARG BASE_DIGEST
ARG TOOLS_DIGEST
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
# Boas-vindas do Luma (F3-03): uma vez por usuário no primeiro login, e no menu para abrir de novo
COPY apps/settings/data/luma-boas-vindas /usr/bin/luma-boas-vindas
COPY apps/settings/data/org.luma.boas-vindas.desktop /usr/share/applications/org.luma.boas-vindas.desktop
COPY apps/settings/data/org.luma.boas-vindas-autostart.desktop /etc/xdg/autostart/org.luma.boas-vindas.desktop
# Assistente de drivers (decisão 0014): detecta o hardware e oferece ações, só com confirmação do usuário
COPY apps/drivers/luma_drivers/ /usr/share/luma-drivers/luma_drivers/
COPY apps/drivers/data/luma-drivers /usr/bin/luma-drivers
# Onde está o código-fonte e a oferta escrita (F6-10)
COPY docs/FONTES.md /usr/share/doc/luma/FONTES.md
COPY apps/drivers/data/org.luma.drivers-aviso.desktop /etc/xdg/autostart/org.luma.drivers-aviso.desktop
# Jogos (Fase 4): lojas via Flathub sob demanda, sem RPM Fusion na imagem (decisão 0012)
COPY gaming/bin/luma-jogos /usr/bin/luma-jogos
COPY gaming/data/org.luma.jogos.desktop /usr/share/applications/org.luma.jogos.desktop
COPY build/image/ /tmp/luma-build/
RUN LUMA_VERSION="${LUMA_VERSION}" FEDORA_VERSION="${FEDORA_VERSION}" /tmp/luma-build/build.sh && \
    rm -rf /tmp/luma-build

# Verificação do próprio bootc sobre a imagem final (falha o build se a imagem não for inicializável)
RUN bootc container lint

LABEL org.opencontainers.image.title="Luma-OS" \
      org.opencontainers.image.description="Luma-OS Midnight Edition (base Fedora Kinoite)" \
      org.opencontainers.image.source="https://github.com/Selhorstkaliel/Luma" \
      org.opencontainers.image.version="${LUMA_VERSION}" \
      org.luma.base.digest="${BASE_DIGEST}" \
      org.luma.tools.digest="${TOOLS_DIGEST}" \
      containers.bootc="1"
