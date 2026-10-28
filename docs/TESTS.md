# Matriz de testes

Regra herdada do LUMA-OS: nada é APROVADO sem evidência registrada. Estados: PASSOU · FALHOU · PENDENTE · NÃO EXECUTADO (com motivo).

## Fase 0
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F0-01 | Lint (ShellCheck, ruff, segredos) sem erros | `scripts/ci/lint.sh` | PASSOU (local e CI, 2026-10-28; ShellCheck 0.9.0 do runner e 0.11.0) | [CI run 40617230109](https://github.com/Selhorstkaliel/Luma/actions/runs/40617230109), job lint-e-unit |
| F0-02 | Testes de tema portados passam | `python3 tests/unit/test_theme.py` | PASSOU (local e CI, 16/16) | idem |
| F0-03 | Testes da lógica do app Ajustes passam | `python3 tests/unit/test_settings_core.py` | PASSOU (local e CI, 11/11) | idem |
| F0-04 | Todo arquivo tem licença; nenhum ativo de marca de terceiros | `python3 tests/unit/test_licenses.py` | PASSOU (local e CI, 3/3) | idem |
| F0-05 | QML sem erros de lint | `qmllint` | NÃO EXECUTADO: sem Qt 6 no ambiente; previsto no CI da Fase 2 (container Fedora) | — |
| F0-06 | Imagem constrói a partir da Kinoite 44 e passa `bootc container lint` | CI `imagem` | PASSOU (2026-10-28): build sobre `quay.io/fedora/fedora-kinoite:44`; `bootc container lint`: "Checks passed: 14, Checks skipped: 1" | [CI run 40617230109](https://github.com/Selhorstkaliel/Luma/actions/runs/40617230109), job imagem (44) |
| F0-07 | Testes da imagem F0-I01..I12 | `tests/image/test-image.sh` no CI | FALHOU 11/12 no run 40617230109: F0-I04 exigia `PLATFORM_ID`, que a Kinoite 44 não tem (premissa errada do teste, não defeito da imagem). Teste corrigido para comparar com o os-release da base guardado em `/usr/share/luma/base-os-release`; PENDENTE nova execução | [run 40617230109](https://github.com/Selhorstkaliel/Luma/actions/runs/40617230109) |
| F0-08 | `lab.sh check` detecta firmware OVMF e `/dev/kvm` no host | laboratório | PENDENTE: exige o host do usuário | — |
| F0-09 | ISO Kinoite 44 oficial baixada e verificada (GPG + SHA-256) | `lab.sh fetch-iso` | PENDENTE: exige o host do usuário (chave do F44 fixada em `config.sh`, conferida pelo usuário em 2026-10-28) | — |
| F0-10 | VM inicia a ISO Kinoite 44 com Secure Boot ativo | `BOOT_ISO=… lab.sh run` + `lab.sh screenshot` | PENDENTE | `docs/evidence/fase0/` |

## Regressão herdada do LUMA-OS
Os critérios E1–E9 do LUMA-OS (`docs/TESTS.md` dele) servem de checklist das Fases 1, 2, 5 e 6. Cada um precisa passar de novo no Fedora ou ter a exceção registrada na decisão correspondente.
