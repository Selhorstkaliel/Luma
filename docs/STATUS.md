# Estado do projeto

Atualizado em 2026-10-28. Plano: [PLANO-MESTRE.md](PLANO-MESTRE.md). Testes: [TESTS.md](TESTS.md). Decisões: [decisions/](decisions/).

| Fase | Estado |
|---|---|
| 0: Auditoria e bootstrap | **CONCLUÍDA COM EXCEÇÕES** (2026-10-28, decisão do usuário). CI verde: lint, unit, build da imagem, `bootc container lint` e testes da imagem 12/12 ([run 40620197044](https://github.com/Selhorstkaliel/Luma/actions/runs/40620197044)). Não executados e transferidos para a Fase 1: qmllint e laboratório no PC do usuário |
| 1: Fedora Core | **EM ANDAMENTO**. Primeira ISO gerada no CI ([run 40626540431](https://github.com/Selhorstkaliel/Luma/actions/runs/40626540431), artefato de 7 dias, 4,5 GB) pelo fallback `anaconda-iso` do bootc-image-builder. Falta: entender a falha do `bootc-installer`, confirmar que o boot chega ao instalador e o teste de instalação na VM do usuário (F1-02, F1-05, F1-06) |
| 2: Midnight Desktop | **EM ANDAMENTO**. Incremento 1: tema Luma (escuro por padrão), Papirus, Inter e `generic-logos` no lugar de `fedora-logos` entram na imagem; aguardando CI e teste na VM. Paleta Midnight medida, tema de login e Anaconda com marca própria ficam para os próximos incrementos |
| 3: Luma Apps | NÃO INICIADA (app Ajustes e Central de Controle portados, ainda não executados no Fedora) |
| 4: Gaming | NÃO INICIADA (`luma-windows-run` portado; bug do `wineboot` herdado e não investigado) |
| 5: Segurança e desempenho | NÃO INICIADA (zona firewalld `luma` criada; teste por nmap pendente) |
| 6: Instalador e atualizações | NÃO INICIADA |
| 7: Lume SDK | BLOQUEADA: o compilador lumec ainda não existe (informação do usuário) |
| 8: Testes e lançamento | NÃO INICIADA |

## Origem
A edição Fedora nasceu neste repositório a partir de `Selhorstkaliel/LUMA-OS@44903f2` (Luma 0.8.0, Debian 13). O LUMA-OS fica como histórico; ver [decisions/README.md](decisions/README.md).

## O que não foi executado nesta sessão
- `podman build` da imagem: o ambiente de nuvem não alcança `quay.io`; o build e os testes rodam no CI do GitHub e **passaram** (12/12 no [run 40620197044](https://github.com/Selhorstkaliel/Luma/actions/runs/40620197044)).
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
1. CI `ci` e `iso` do incremento de tema: ler os testes F2-I01..I08 e a evidência de `XDG_CONFIG_DIRS` no log.
2. Na VM do usuário: reinstalar com a ISO nova e criar um usuário novo (F2-01). Usuários já existentes mantêm a configuração própria; para eles: `luma-appearance escuro --reset-layout`.
3. Ainda da Fase 1: `getenforce`, zona do firewalld e `bootc status` na VM (F1-06); boot com Secure Boot (F1-05); `sha256sum -c` (F1-02).
