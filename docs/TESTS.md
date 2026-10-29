# Matriz de testes

Regra herdada do LUMA-OS: nada é APROVADO sem evidência registrada. Estados: PASSOU · FALHOU · PENDENTE · NÃO EXECUTADO (com motivo).

## Fase 0
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F0-01 | Lint (ShellCheck, ruff, segredos) sem erros | `scripts/ci/lint.sh` | PASSOU (local e CI, 2026-10-28; ShellCheck 0.9.0 do runner e 0.11.0) | [CI run 40617230109](https://github.com/Selhorstkaliel/Luma/actions/runs/40617230109), job lint-e-unit |
| F0-02 | Testes de tema portados passam | `python3 tests/unit/test_theme.py` | PASSOU (local e CI, 16/16) | idem |
| F0-03 | Testes da lógica do app Ajustes passam | `python3 tests/unit/test_settings_core.py` | PASSOU (local e CI, 11/11) | idem |
| F0-04 | Todo arquivo tem licença; nenhum ativo de marca de terceiros | `python3 tests/unit/test_licenses.py` | PASSOU (local e CI, 3/3) | idem |
| F0-05 | QML sem erros de lint | `qmllint` | TRANSFERIDO para a Fase 1 por decisão do usuário (2026-10-28: "a fase 0 já acabou"); não executado: sem Qt 6 no ambiente | — |
| F0-06 | Imagem constrói a partir da Kinoite 44 e passa `bootc container lint` | CI `imagem` | PASSOU (2026-10-28): build sobre `quay.io/fedora/fedora-kinoite:44`; `bootc container lint`: "Checks passed: 14, Checks skipped: 1" | [CI run 40617230109](https://github.com/Selhorstkaliel/Luma/actions/runs/40617230109), job imagem (44) |
| F0-07 | Testes da imagem F0-I01..I12 | `tests/image/test-image.sh` no CI | PASSOU 12/12 no run 40620197044 (commit 118ef43). Antes, 11/12 no run 40617230109 por premissa errada do teste (`PLATFORM_ID`). Base registrada no log: Fedora 44 Kinoite, `SUPPORT_END=2027-05-19`, sem `PLATFORM_ID`; imagem 7,36 GB, 1755 pacotes | [CI run 40620197044](https://github.com/Selhorstkaliel/Luma/actions/runs/40620197044), job imagem (44); artefato manifesto-luma-44 |
| F0-08 | `lab.sh check` detecta firmware OVMF e `/dev/kvm` no host | laboratório | TRANSFERIDO para a Fase 1 por decisão do usuário (2026-10-28: "a fase 0 já acabou"); não executado (vira F1-04) | — |
| F0-09 | ISO Kinoite 44 oficial baixada e verificada (GPG + SHA-256) | `lab.sh fetch-iso` | TRANSFERIDO para a Fase 1 por decisão do usuário (2026-10-28: "a fase 0 já acabou"); não executado (dispensável: a Fase 1 testa a ISO do próprio Luma) | — |
| F0-10 | VM inicia a ISO Kinoite 44 com Secure Boot ativo | lab | TRANSFERIDO para a Fase 1 por decisão do usuário (2026-10-28: "a fase 0 já acabou"); não executado (vira F1-05 com a ISO do Luma) | — |

## Fase 1 (incremento 1: primeira ISO)
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F1-01 | ISO de instalação gerada a partir da imagem Luma | CI `iso` (`build/iso/build-iso.sh`) | PASSOU no run iso #2: `luma-0.9.0-dev-x86_64.iso`, 4.503.046.144 bytes, gerada pelo **fallback** `anaconda-iso` do bootc-image-builder. O tipo principal `bootc-installer` falhou (log de 79 bytes, motivo a investigar). Run #1 falhou antes (caminho do armazenamento) | [run 40626540431](https://github.com/Selhorstkaliel/Luma/actions/runs/40626540431), artefato 12790019241 |
| F1-02 | `.sha256` publicado junto confere com a ISO baixada | `sha256sum -c` no PC do usuário | PENDENTE: aguardando o usuário | — |
| F1-03 | ISO inicia até o instalador em QEMU + OVMF com Secure Boot no CI | CI `iso`, passo de boot | INCONCLUSIVO: o runner tem `/dev/kvm` e a captura após 240 s tem conteúdo ("VIVA"), mas o detector não distingue o instalador do Boot Manager do OVMF. Na VM do usuário (Fedora 44, SB + chaves registradas, q35) a ISO caiu no Boot Manager sem entrada de DVD (2026-10-28). Corrigido no commit seguinte a 0ccde06: duas capturas (90 s e final) e OCR (tesseract) com veredito INSTALADOR/FALHA/INCONCLUSIVO; o Boot Manager do OVMF agora reprova | [run 40626540431](https://github.com/Selhorstkaliel/Luma/actions/runs/40626540431) |
| F1-04 | `lab.sh check` no host do usuário (ex-F0-08) | laboratório | PENDENTE: exige o PC do usuário | — |
| F1-05 | ISO do Luma inicia com Secure Boot na VM do usuário (ex-F0-10) | `BOOT_ISO=… lab.sh run` + screenshot | PENDENTE com SB. Sem SB (libvirt q35, `--boot uefi`, host Fedora 44 do usuário, 2026-10-28) a ISO chegou ao GRUB "Install Luma-OS 44" e ao Anaconda. Com SB e chaves registradas a VM parou no Boot Manager do OVMF; a entrada "UEFI Misc Device" não foi testada | prints do usuário na conversa (não versionados) |
| F1-06 | Instalação em disco virtual e primeiro boot do sistema instalado | laboratório | PARCIAL (2026-10-28): instalado em VM sem SB, sessão Plasma abre; `/etc/os-release` do sistema instalado mostra `NAME="Luma-OS"`, `ID=luma`, `VERSION="44.20261028.1 (Kinoite)"`. Hostname ficou `fedora`, apesar de `DEFAULT_HOSTNAME=luma` [H: definido pelo instalador]. Faltam `getenforce`, zona do firewalld e `bootc status` | print do usuário (Konsole na VM) |
| F1-07 | QML sem erros (ex-F0-05) | `qmllint` dentro da imagem Luma no CI (job imagem) | EM COLETA: o passo roda no CI sem bloquear, para registrar a saída real antes de virar critério | — |
| F1-08 | Hostname do sistema instalado é `luma` (o instalador gravava `fedora`) | `luma-hostname.service` (teste unitário `tests/unit/test_hostname.py`, 3/3 local) + `hostnamectl` na VM | PENDENTE na VM | — |
| F1-09 | Evidências da VM num comando: `sudo luma-diagnostico` (SELinux, Secure Boot, firewall, portas, `bootc status`, logos, tema) | F1-I02 no CI + execução na VM | PENDENTE | — |

## Fase 2 (incremento 1: tema Luma na imagem)
Motivo: na VM o sistema instalado tinha o visual da Kinoite (comentário do usuário: "não foi a luma, foi o fedora"). Até aqui a imagem só trocava o os-release e o firewall.
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F2-I01..I08 | Tema instalado (Look-and-Feel, cores, Aurorae, Central de Controle, wallpaper, ícone), padrão `org.luma.dark.desktop` efetivo pelo `XDG_CONFIG_DIRS` da sessão, Papirus e Inter presentes, sem `fedora-logos`, lançadores do dock existentes | `tests/image/test-image.sh` no CI | PASSOU (testes da imagem 20/20, commit 00850f9). Evidência do log: `fedora-logos` 42.0.1 trocado por `generic-logos` 18.0.0; Firefox no dock = `org.mozilla.firefox.desktop`; a base define `XDG_CONFIG_DIRS=/etc/xdg:/usr/share/kde-settings/kde-profile/default/xdg` (`/etc/xdg/plasma-workspace/env/env.sh`); o Fedora põe `org.fedoraproject.fedora.desktop` no segundo diretório, e o valor efetivo é `org.luma.dark.desktop`. Imagem: 1760 pacotes, 7,70 GB. Antes, o run 40634925786 (commit 95f7ad5) falhou por erro do script (`fc-list \| grep -q` sob `pipefail`, SIGPIPE). Pendência: o `bootc container lint` passou com 3 avisos novos (resíduo do dnf em `/run/dnf`, `/var/log`, `/var/lib/dnf`, `/var/cache/libdnf5`) | [run ci 40635971059](https://github.com/Selhorstkaliel/Luma/actions/runs/40635971059), job imagem (44) |
| F2-01 | Usuário **novo** recebe o visual Luma escuro sem passo manual (barra superior, dock, wallpaper, decoração) | VM do usuário, ISO nova, usuário criado na instalação | PENDENTE | — |
| F2-03 | Tela de boot Luma (Plymouth: logotipo sobre #080D19) no initramfs | `build/image/plymouth.sh` + F2-I09/F2-I10 no CI; boot na VM | PENDENTE (CI e VM) | — |
| F2-04 | Modo desempenho (`luma-appearance desempenho ligado/desligado`: sem desfoque, sem contraste extra, animações zeradas) | stub local das chaves gravadas (2026-10-29: 3 chaves gravadas e 3 removidas, argumento inválido → 64) + efeito na VM | PARCIAL: lógica conferida localmente; efeito visual na VM PENDENTE | — |
| F2-05 | Tela de login com visual Luma | — | NÃO SE APLICA no F44: o Plasma Login Manager não aceita tema próprio (fixo no Breeze, proposta de mudança do Fedora 44). A tela de **bloqueio** usa o papel de parede Luma (`/etc/xdg/kscreenlockerrc`) | https://fedoraproject.org/wiki/Changes/PlasmaLoginManager |
| F2-02 | Paleta Midnight medida no mockup aplicada ao esquema escuro, com contraste AA | `tests/unit/test_theme.py` + `docs/design/midnight-tokens.md` | PASSOU na parte automática (2026-10-29): tokens medidos no mockup (mediana por região) e aplicados ao `LumaDark` e ao Aurorae `LumaEscuro`; 16/16 testes de tema, incluindo contraste AA. Revisão visual na VM PENDENTE | `docs/design/midnight-tokens.md` |

## Fase 3 (incremento 1: app Ajustes na imagem)
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F3-I01..I03 | PySide6 e `luma_ajustes` importam; a interface QML (Kirigami) carrega sem tela (`luma-ajustes --verificar`, offscreen); `.desktop` válido | `tests/image/test-image.sh` no CI | PENDENTE (CI) | — |
| F3-01 | Ajustes abre pelo dock e aplica claro/escuro, destaque, animações, texto e transparência sem pedir senha | VM, usuário novo | PENDENTE | — |
| F3-02 | Central de Controle (barra superior) mostra Wi-Fi, Bluetooth, Não perturbe, brilho e volume | VM | PENDENTE | — |
| F3-03 | Boas-vindas (extensão do Plasma Setup) e presets do Monitor do Sistema | — | NÃO INICIADO (próximos incrementos) | — |

## Regressão herdada do LUMA-OS
Os critérios E1–E9 do LUMA-OS (`docs/TESTS.md` dele) servem de checklist das Fases 1, 2, 5 e 6. Cada um precisa passar de novo no Fedora ou ter a exceção registrada na decisão correspondente.
