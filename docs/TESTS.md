# Matriz de testes

Regra herdada do LUMA-OS: nada é APROVADO sem evidência registrada. Estados: PASSOU · FALHOU · PENDENTE · NÃO EXECUTADO (com motivo).

## Fase 0
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F0-01 | Lint (ShellCheck, ruff, segredos) sem erros | `scripts/ci/lint.sh` | PASSOU (local, 2026-10-28) | saída da sessão: "lint OK (11 scripts shell, 11 Python)" |
| F0-02 | Testes de tema portados passam | `python3 tests/unit/test_theme.py` | PASSOU (local, 16/16) | idem |
| F0-03 | Testes da lógica do app Ajustes passam | `python3 tests/unit/test_settings_core.py` | PASSOU (local, 11/11) | idem |
| F0-04 | Todo arquivo tem licença; nenhum ativo de marca de terceiros | `python3 tests/unit/test_licenses.py` | PASSOU (local, 3/3) | idem |
| F0-05 | QML sem erros de lint | `qmllint` | NÃO EXECUTADO: sem Qt 6 no ambiente; previsto no CI da Fase 2 (container Fedora) | — |
| F0-06 | Imagem constrói a partir da Kinoite 44 e passa `bootc container lint` | CI `imagem` | PENDENTE: aguardando o primeiro CI no GitHub | — |
| F0-07 | Testes da imagem F0-I01..I12 | `tests/image/test-image.sh` no CI | PENDENTE | — |
| F0-08 | `lab.sh check` detecta firmware OVMF e `/dev/kvm` no host | laboratório | PENDENTE: exige o host do usuário | — |
| F0-09 | ISO Kinoite 44 oficial baixada e verificada (GPG + SHA-256) | `lab.sh fetch-iso` | PENDENTE: exige `FEDORA_KEY_FPR` conferida pelo usuário | — |
| F0-10 | VM inicia a ISO Kinoite 44 com Secure Boot ativo | `BOOT_ISO=… lab.sh run` + `lab.sh screenshot` | PENDENTE | `docs/evidence/fase0/` |

## Regressão herdada do LUMA-OS
Os critérios E1–E9 do LUMA-OS (`docs/TESTS.md` dele) servem de checklist das Fases 1, 2, 5 e 6. Cada um precisa passar de novo no Fedora ou ter a exceção registrada na decisão correspondente.
