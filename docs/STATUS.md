# Estado do projeto

Atualizado em 2026-10-30. Plano: [PLANO-MESTRE.md](PLANO-MESTRE.md). Testes: [TESTS.md](TESTS.md). Decisões: [decisions/](decisions/).

**Marco (2026-10-30):** o [run iso #23](https://github.com/Selhorstkaliel/Luma/actions/runs/40989488536) (commit d842baa) foi o primeiro inteiramente verde. Ele gera a ISO, inicia com Secure Boot até o instalador (que espera o usuário) e **instala o Luma numa VM com Secure Boot**. No sistema instalado, um usuário novo é testado de ponta a ponta (`scripts/ci/vm-test.sh`). Os critérios "VM" abaixo vêm desse teste automático: instalação automática, login automático, sem 3D. A revisão visual continua sendo do usuário, pelas capturas do artefato `…-evidencias-vm`.

| Fase | Estado |
|---|---|
| 0: Auditoria e bootstrap | **CONCLUÍDA COM EXCEÇÕES** (2026-10-28). Exceções transferidas para a Fase 1 e cobertas depois pelo teste do sistema instalado |
| 1: Fedora Core | **CONCLUÍDA NO CI, COM EXCEÇÕES**. PASSOU: ISO gerada, boot com Secure Boot até o instalador, instalação, Secure Boot ativo no sistema instalado, hostname `luma`, SELinux enforcing, zona `luma`, `luma-diagnostico`, nenhuma unidade com falha. Exceções: `sha256sum` e `lab.sh check` no PC do usuário (F1-02, F1-04); `bootc upgrade`/`rollback` (decisão 0009); a ISO depende do bootc-image-builder arquivado |
| 2: Midnight Desktop | **CONCLUÍDA NO CI; FALTA A REVISÃO VISUAL DO USUÁRIO**. PASSOU: usuário novo com Look-and-Feel escuro, papel Luma, barra superior com a Central de Controle e dock; modo desempenho; nenhuma menção a Fedora (as boas-vindas do Fedora saíram). Tela de login: não se aplica no F44 |
| 3: Luma Apps | **EM ANDAMENTO**. PASSOU: Ajustes abre e aplica os 15 comandos sem senha e sem falha; Central de Controle no painel. Boas-vindas do Luma abre no primeiro login e não reabre (iso #26), mas a do KDE ainda abriu junto (F3-03 FALHOU); correção: `plasma-welcome` removido da imagem, reavaliar no próximo run `iso`. [D] Presets do Monitor do Sistema: proposta de retirar (F3-04) |
| 4: Gaming | **CONCLUÍDA NO QUE A VM PERMITE**. PASSOU: `luma-jogos instalar steam` sem senha e o Steam abre na tela de login. Bloqueado: jogos rodando (hardware real, F4-02). Adiado: NVIDIA (F4-03) |
| 5: Segurança e desempenho | **EM ANDAMENTO**. PASSOU: nmap de fora sem nenhuma porta aberta (8080 filtrada com serviço escutando). PARCIAL: 8 AVCs no boot, todos da base Fedora (`chcon` em `tuned_t`/`initrc_t`), nenhum do Luma (F5-02). PASSOU: RAM e boot contra a Kinoite pura, mediana de 3 boots: 1458 × 1492 MiB (−2,3%), 7,8 × 7,8 s (F5-03, medicao #3). Bloqueado: bateria (hardware), updates assinados (decisão 0009) |
| 6: Instalador e atualizações | **EM ANDAMENTO**. PASSOU: o instalador para no resumo sem apagar o disco (com Secure Boot); pt-BR, teclado br e fuso de São Paulo no sistema instalado (padrão da imagem, porque o Anaconda ignora esses campos do kickstart). Em teste no CI: dual boot com Windows simulado em disco virtual (F6-04, workflow `dualboot`) e marca Luma no Anaconda (F6-05). Windows real só em hardware ou VM do usuário. Bloqueado: canal de atualização assinado (decisão 0009) |
| 7: Lume SDK | **CONCLUÍDA (0.1)**. PASSOU: testes do compilador, interface sem tela no CI e `lumec run ola.lume` no sistema instalado, com a janela "Olá do Lume" listada pelo KWin. Pendência visual: as capturas não mostram a janela (F7-01-OCR) |
| 8: Testes e lançamento | NÃO INICIADA. Depende de máquina real, da revisão visual e da decisão 0009 |

## Origem
A edição Fedora nasceu neste repositório a partir de `Selhorstkaliel/LUMA-OS@44903f2` (Luma 0.8.0, Debian 13). O LUMA-OS fica como histórico; ver [decisions/README.md](decisions/README.md).

## O que não foi executado nesta sessão
- `podman build` da imagem: o ambiente de nuvem não alcança `quay.io`; o build e os testes rodam no CI do GitHub e **passaram** (12/12 no [run 40620197044](https://github.com/Selhorstkaliel/Luma/actions/runs/40620197044)).
- Laboratório: o ambiente não tem `/dev/kvm` nem QEMU. `lab.sh check` falha como esperado; nenhum comando de VM foi testado.
- As impressões digitais das chaves do Fedora 44 e 45 foram conferidas pelo usuário em https://fedoraproject.org/security/ (2026-10-28) e fixadas em `scripts/lab/config.sh`.

## Decisões pendentes do usuário (plano §12)
1. Publicar no GHCR e assinar com cosign (0009).
2. ~~Flathub~~, ~~NVIDIA~~, ~~Steam e codecs~~: decididos em 2026-10-29 (decisão 0012).
5. Hardware de teste (SSD externo ou máquina descartável). Instalar no notebook principal continua proibido sem autorização específica.
6. Nome e logotipo definitivos (0010).
7. Arquivar o LUMA-OS. O `STATUS.md` dele diz "repositório privado", mas o repositório está público [F].

## Próximo passo
1. Usuário: baixar a ISO do run iso #23 e/ou o artefato de evidências e aprovar ou reprovar o visual (capturas `desktop-usuario-novo`, `ajustes-*`, `boot-*`).
2. Usuário: decidir a decisão 0009 (GHCR + cosign) e o hardware de teste (SSD externo ou máquina descartável).
3. Sem depender do usuário: fechar o F3-03 (boas-vindas do KDE fora) e marca Luma no Anaconda (F6-05).
