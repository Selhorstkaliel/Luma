# Decisões (ADRs)

A numeração continua a do LUMA-OS. As decisões 0001–0007 estão em `Selhorstkaliel/LUMA-OS@44903f2:docs/decisions/` e valem como histórico. As que a edição Fedora substitui estão marcadas abaixo.

| Nº | Título | Estado |
|---|---|---|
| 0001 | Base Debian trixie + Plasma 6.3 (LUMA-OS) | **substituída** pela 0008 |
| 0002 | Hypervisor do laboratório: QEMU/KVM + OVMF no WSL2 (LUMA-OS) | vale; o lab foi adaptado para a ISO Kinoite |
| 0003 | Central de controle (LUMA-OS) | vale; o plasmoide foi portado |
| 0004 | Loja e fontes; Flathub pendente (LUMA-OS) | **reaberta**: Flathub pendente (plano §12) |
| 0005 | ISO live com live-build (LUMA-OS) | **substituída** pela 0008/0009 |
| 0006 | Instalador Calamares (LUMA-OS) | **substituída** pela 0008 (Anaconda) |
| 0007 | Compatibilidade Windows em duas camadas (LUMA-OS) | vale o modelo; o Wine passa a ser o do Fedora |
| [0008](0008-base-fedora-kinoite-bootc.md) | Base Fedora Kinoite com imagem bootc | aceita |
| [0009](0009-build-ci-assinatura.md) | Build, CI e assinatura | aceita; publicação assinada no GHCR desde 2026-11-02 |
| [0010](0010-marca-e-licencas.md) | Marca, identidade visual e licenças | aceita; nome e logotipo pendentes |
| [0011](0011-iso-instalador.md) | ISO e instalador | aceita |
| [0012](0012-jogos-flatpak-nvidia.md) | Jogos por Flatpak; NVIDIA adiada | aceita |
| [0013](0013-lume-linguagem.md) | Linguagem Lume | aceita |
| [0014](0014-drivers-e-perifericos.md) | Drivers e periféricos: detectar e perguntar | aceita |
