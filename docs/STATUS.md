# Estado do projeto

Atualizado em 2026-10-30. Plano: [PLANO-MESTRE.md](PLANO-MESTRE.md). Testes: [TESTS.md](TESTS.md). Decisões: [decisions/](decisions/).

**Marco (2026-10-30):** o [run iso #23](https://github.com/Selhorstkaliel/Luma/actions/runs/40989488536) (commit d842baa) foi o primeiro inteiramente verde. Ele gera a ISO, inicia com Secure Boot até o instalador (que espera o usuário) e **instala o Luma numa VM com Secure Boot**. No sistema instalado, um usuário novo é testado de ponta a ponta (`scripts/ci/vm-test.sh`). Os critérios "VM" abaixo vêm desse teste automático: instalação automática, login automático, sem 3D. A revisão visual continua sendo do usuário, pelas capturas do artefato `…-evidencias-vm`.

| Fase | Estado |
|---|---|
| 0: Auditoria e bootstrap | **CONCLUÍDA COM EXCEÇÕES** (2026-10-28). Exceções transferidas para a Fase 1 e cobertas depois pelo teste do sistema instalado |
| 1: Fedora Core | **CONCLUÍDA NO CI, COM EXCEÇÕES**. PASSOU: ISO gerada, boot com Secure Boot até o instalador, instalação, Secure Boot ativo no sistema instalado, hostname `luma`, SELinux enforcing, zona `luma`, `luma-diagnostico`, nenhuma unidade com falha. Exceções: `sha256sum` e `lab.sh check` no PC do usuário (F1-02, F1-04); `bootc upgrade`/`rollback` (decisão 0009); a ISO depende do bootc-image-builder arquivado |
| 2: Midnight Desktop | **CONCLUÍDA** (revisão visual aprovada pelo usuário em 2026-11-02, F2-07). PASSOU: usuário novo com Look-and-Feel escuro, papel Luma, barra superior com a Central de Controle e dock; modo desempenho; nenhuma menção a Fedora (as boas-vindas do Fedora saíram). Tela de login: não se aplica no F44 |
| 3: Luma Apps | **CONCLUÍDA** (2026-10-31). PASSOU: Ajustes abre e aplica os 15 comandos sem senha e sem falha; Central de Controle no painel; Boas-vindas do Luma no primeiro login, sozinha (a do KDE saiu da imagem), e não reabre depois de concluir (iso #27). Presets do Monitor do Sistema retirados da fase por decisão do usuário (F3-04). Em andamento (decisão 0014, 2026-11-02): assistente de drivers `luma-drivers` (vídeo, rede, firmware, impressão, controles, digital, periféricos), que detecta e só age com confirmação; NVIDIA só detectada. Unitário PASSOU; imagem e VM no próximo iso; página no Ajustes e aviso no primeiro login no incremento seguinte |
| 4: Gaming | **CONCLUÍDA NO QUE A VM PERMITE**. PASSOU: `luma-jogos instalar steam` sem senha e o Steam abre na tela de login. Bloqueado: jogos rodando (hardware real, F4-02). Adiado: NVIDIA (F4-03) |
| 5: Segurança e desempenho | **EM ANDAMENTO**. PASSOU: nmap de fora sem nenhuma porta aberta (8080 filtrada com serviço escutando). PASSOU: AVCs explicados, os mesmos da Kinoite pura (`tuned_t/mac_admin` ×6), nenhum do Luma (F5-02, medicao #4). PASSOU: RAM e boot contra a Kinoite pura, mediana de 3 boots: 1352 × 1497 MiB (−9,7%), 7,9 × 7,8 s (F5-03, medicao #5). Bloqueado: bateria (hardware), updates assinados (decisão 0009) |
| 6: Instalador e atualizações | **EM ANDAMENTO**. PASSOU: o instalador para no resumo sem apagar o disco (com Secure Boot); pt-BR, teclado br e fuso de São Paulo no sistema instalado (padrão da imagem, porque o Anaconda ignora esses campos do kickstart). PASSOU: dual boot com Windows simulado em disco virtual: o outro sistema fica intacto, o Luma usa o mesmo ESP e inicia com Secure Boot (F6-04, dualboot #1). Em correção: marca Luma no Anaconda (F6-05): a ISO ainda sai do bootc-image-builder, que ignora a imagem de instalador do Luma. Windows real só em hardware ou VM do usuário. Canal de atualização assinado: **publicado** (iso #45, 2026-11-02): `ghcr.io/selhorstkaliel/luma:44`, assinada com a chave cosign do projeto e verificada no CI; falta testar `bootc switch`/`upgrade`/rollback no sistema instalado (F6-06) |
| 7: Lume SDK | **CONCLUÍDA (0.1)**. PASSOU: testes do compilador, interface sem tela no CI e `lumec run ola.lume` no sistema instalado, com a janela "Olá do Lume" listada pelo KWin. Pendência visual: as capturas não mostram a janela (F7-01-OCR) |
| 8: Testes e lançamento | **BLOQUEADA**: o usuário não tem hardware de teste (2026-11-02). O plano exige pelo menos 1 máquina real, então o Luma fica **pré-alpha só para VM**. Revisão visual aprovada e canal assinado publicado em 2026-11-02 |

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

## Roteiro do que falta (aprovado pelo usuário em 2026-11-03)
Uma etapa por vez; cada uma só fecha com evidência em [TESTS.md](TESTS.md).

| Etapa | Conteúdo | Fecha quando |
|---|---|---|
| A | Recusa de imagem sem assinatura (F6-07) e drivers no Ajustes (F3-06), já no CI | as duas PASSOU no iso |
| B | Base Kinoite por digest e atualização controlada (F6-08) | build com `@sha256` resolvido no próprio run e registrado nas labels da imagem; teste que impede build sem resolver a base |
| C | Instalador com a marca Luma, em português e teclado br (F6-05) | ISO entregue com instalador Luma interativo, verificado no CI |
| D | Primeiro boot (assistente do KDE) e tela de boot (F2-03) | decisão e teste do 1º boot; Plymouth confirmado |
| E | Registros desatualizados do TESTS e travamento intermitente do instalador no CI | TESTS bate com o CI; causa do travamento com log |
| F | Migração para Fedora 45 | build, testes e VM verdes no 45 |
| G | Decisões do usuário: nome/logotipo (0010) e Flathub (0004) | decisões registradas |
| H | Hardware real e lançamento (Fase 8) | bloqueada até existir máquina de teste |

**Agora:** etapa A fechada (2026-11-03). Etapa B reaberta em 2026-11-04: o quay.io apagou os digests fixados em menos de um dia e todos os builds quebraram (ci #89 e #91); corrigida resolvendo o digest em cada build (F6-08), confirmada no ci #92, iso #58 e instalador-ib #10: **fechada**. Atual: **etapa C** (instalador com a marca Luma): no instalador-ib #15 o instalador do image-builder abriu gráfico, com a marca Luma, a cor Midnight e em português; confirmado no #16; a ISO entregue sai do image-builder desde o iso #64 (verde e publicado). **Etapa C fechada em 2026-11-08.** Atual: **etapa D** (primeiro boot e Plymouth, F2-03).

## Próximo passo
1. Usuário: seguir [docs/usuario/passos-do-usuario.md](usuario/passos-do-usuario.md):
   - A: chave cosign para a publicação assinada;
   - B: revisão visual das capturas;
   - C (opcional): ISO numa VM;
   - D: hardware de teste.
2. Sem depender do usuário: interface interativa do Anaconda na ISO do image-builder (F6-05; o sistema instalado por ela já passa em todos os critérios).
