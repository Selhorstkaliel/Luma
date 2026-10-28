# Luma-OS Midnight Edition

Distribuição Linux baseada na **Fedora Kinoite** (Fedora 44, KDE Plasma 6, Wayland), entregue como imagem **bootc**, com identidade visual própria "Midnight", foco em jogos e apps próprios em Qt/QML.

> **Estado: Fase 0 (bootstrap).** Ainda não há ISO nem sistema instalável. Nada aqui foi testado em hardware real. Veja [docs/STATUS.md](docs/STATUS.md).

## Documentos
- [Plano mestre](docs/PLANO-MESTRE.md): arquitetura, fases, riscos e critérios de aceite.
- [Estado atual](docs/STATUS.md) · [Matriz de testes](docs/TESTS.md) · [Decisões](docs/decisions/)

## Estrutura
| Pasta | Conteúdo |
|---|---|
| `Containerfile`, `build/image/` | Imagem bootc derivada da Kinoite |
| `configs/` | Arquivos copiados para a imagem (`/usr`, `/etc`) |
| `themes/`, `plasma/`, `icons/`, `wallpapers/` | Identidade visual (herdada do LUMA-OS; paleta Midnight na Fase 2) |
| `apps/` | Apps próprios (`settings/` = Ajustes) |
| `gaming/` | Camada de jogos e Windows (`wine/`) |
| `scripts/lab/` | Laboratório QEMU/KVM + OVMF com Secure Boot |
| `scripts/ci/`, `.github/workflows/` | Lint, testes e build no CI (sem publicação) |
| `tests/` | `unit/` (sem Qt), `image/` (dentro do container) |
| `packages/`, `branding/`, `qml/`, `security/`, `installer/`, `lume-sdk/` | Reservadas para as próximas fases (ver o README de cada uma) |

## Uso rápido
```sh
scripts/ci/lint.sh && scripts/ci/unit.sh                          # verificações locais
podman build --build-arg FEDORA_VERSION=44 -t localhost/luma:44 .  # imagem
podman run --rm -v "$PWD/tests/image:/t:ro" localhost/luma:44 /t/test-image.sh
```

## Origem e licenças
Começou como `Selhorstkaliel/LUMA-OS` (Luma 0.8.0, base Debian). Os ativos agnósticos vieram do commit 44903f2. As licenças por arquivo estão em [LICENSES.toml](LICENSES.toml): o código é GPL-2.0-or-later, e wallpapers e documentação são CC-BY-SA-4.0.
Não é um produto do Projeto Fedora nem é endossado por ele.
