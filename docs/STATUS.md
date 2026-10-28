# Estado do projeto

Atualizado em 2026-10-28. Plano: [PLANO-MESTRE.md](PLANO-MESTRE.md). Testes: [TESTS.md](TESTS.md). Decisões: [decisions/](decisions/).

| Fase | Estado |
|---|---|
| 0: Auditoria e bootstrap | **EM ANDAMENTO**. Feito: estrutura, ADRs 0008–0010, ativos portados com os testes passando, Containerfile mínimo, CI (lint, unit e build da imagem passando), lab adaptado, chaves do Fedora fixadas. Falta: testes da imagem 12/12 no CI e a VM Kinoite 44 com Secure Boot no laboratório (ver TESTS.md) |
| 1: Fedora Core | NÃO INICIADA |
| 2: Midnight Desktop | NÃO INICIADA (ativos do tema claro/escuro do LUMA-OS portados; paleta Midnight não iniciada) |
| 3: Luma Apps | NÃO INICIADA (app Ajustes e Central de Controle portados, ainda não executados no Fedora) |
| 4: Gaming | NÃO INICIADA (`luma-windows-run` portado; bug do `wineboot` herdado e não investigado) |
| 5: Segurança e desempenho | NÃO INICIADA (zona firewalld `luma` criada; teste por nmap pendente) |
| 6: Instalador e atualizações | NÃO INICIADA |
| 7: Lume SDK | BLOQUEADA: o compilador lumec ainda não existe (informação do usuário) |
| 8: Testes e lançamento | NÃO INICIADA |

## Origem
A edição Fedora nasceu neste repositório a partir de `Selhorstkaliel/LUMA-OS@44903f2` (Luma 0.8.0, Debian 13). O LUMA-OS fica como histórico; ver [decisions/README.md](decisions/README.md).

## O que não foi executado nesta sessão
- `podman build` da imagem: o ambiente de nuvem não alcança `quay.io`; o build roda no CI do GitHub e **passou** (incluindo `bootc container lint`) no [run 40617230109](https://github.com/Selhorstkaliel/Luma/actions/runs/40617230109). Testes da imagem: 11/12; a falha (F0-I04) era premissa errada do teste, corrigida e aguardando nova execução.
- Laboratório: o ambiente não tem `/dev/kvm` nem QEMU. `lab.sh check` falha como esperado; nenhum comando de VM foi testado.
- As impressões digitais das chaves do Fedora 44 e 45 foram conferidas pelo usuário em https://fedoraproject.org/security/ (2026-10-28) e fixadas em `scripts/lab/config.sh`.

## Decisões pendentes do usuário (plano §12)
1. Publicar no GHCR e assinar com cosign (0009).
2. Pré-configurar o Flathub (0004 reaberta).
3. Origem do driver NVIDIA (akmods do ublue ou pipeline própria).
4. Steam e codecs na imagem ou opt-in.
5. Hardware de teste (SSD externo ou máquina descartável). Instalar no notebook principal continua proibido sem autorização específica.
6. Nome e logotipo definitivos (0010).
7. Arquivar o LUMA-OS. O `STATUS.md` dele diz "repositório privado", mas o repositório está público [F].

## Próximo passo
Ver o resultado do CI no GitHub. Depois, no laboratório do host: `lab.sh fetch-iso` (com `FEDORA_KEY_FPR`), `BOOT_ISO=… lab.sh run`, screenshot da tela de boot com Secure Boot em `docs/evidence/fase0/`.
