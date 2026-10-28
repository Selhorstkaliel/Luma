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
| F1-03 | ISO inicia até o instalador em QEMU + OVMF com Secure Boot no CI | CI `iso`, passo de boot | INCONCLUSIVO: o runner tem `/dev/kvm` e a captura após 240 s tem conteúdo ("VIVA"), mas o detector não distingue o instalador do Boot Manager do OVMF. Na VM do usuário (Fedora 44, SB + chaves registradas, q35) a ISO caiu no Boot Manager sem entrada de DVD (2026-10-28). Corrigir o smoke test para exigir sinal do instalador (log serial/texto da tela) | [run 40626540431](https://github.com/Selhorstkaliel/Luma/actions/runs/40626540431) |
| F1-04 | `lab.sh check` no host do usuário (ex-F0-08) | laboratório | PENDENTE: exige o PC do usuário | — |
| F1-05 | ISO do Luma inicia com Secure Boot na VM do usuário (ex-F0-10) | `BOOT_ISO=… lab.sh run` + screenshot | PENDENTE | `docs/evidence/fase1/` |
| F1-06 | Instalação em disco virtual e primeiro boot do sistema instalado | laboratório | PENDENTE | — |
| F1-07 | QML sem erros (ex-F0-05) | `qmllint` no container Fedora | PENDENTE | — |

## Regressão herdada do LUMA-OS
Os critérios E1–E9 do LUMA-OS (`docs/TESTS.md` dele) servem de checklist das Fases 1, 2, 5 e 6. Cada um precisa passar de novo no Fedora ou ter a exceção registrada na decisão correspondente.
