# Estado do projeto

Atualizado em 2026-10-28. Plano: [PLANO-MESTRE.md](PLANO-MESTRE.md). Testes: [TESTS.md](TESTS.md). Decisões: [decisions/](decisions/).

| Fase | Estado |
|---|---|
| 0: Auditoria e bootstrap | **CONCLUÍDA COM EXCEÇÕES** (2026-10-28, decisão do usuário). CI verde: lint, unit, build da imagem, `bootc container lint` e testes da imagem 12/12 ([run 40620197044](https://github.com/Selhorstkaliel/Luma/actions/runs/40620197044)). Não executados e transferidos para a Fase 1: qmllint e laboratório no PC do usuário |
| 1: Fedora Core | **EM ANDAMENTO**, falta só o que depende da VM do usuário. Feito: imagem testada no CI (22 verificações), ISO gerada no CI, smoke test de boot com OCR, hostname `luma`, comando `luma-diagnostico`. Falta: `sudo luma-diagnostico` na VM (F1-06, F1-08, F1-09), boot com Secure Boot (F1-05), `sha256sum` (F1-02), `bootc upgrade`/`rollback` (depende de registro, decisão 0009) e varredura nmap da VM. Exceção conhecida: a ISO depende do bootc-image-builder arquivado (motivo da falha do `bootc-installer` passa a sair no manifesto) |
| 2: Midnight Desktop | **EM ANDAMENTO**, falta só a revisão visual na VM do usuário. Na imagem: tema Luma escuro por padrão com paleta Midnight medida no mockup, decoração de janelas, barra superior e dock, Papirus, Inter, `generic-logos`, tela de boot Plymouth Luma, modo desempenho (`luma-appearance desempenho`). Fora: tela de login (o Plasma Login Manager do F44 não aceita tema próprio) e marca do instalador (Fase 6). Falta: F2-01, F2-03 e F2-04 na VM e as capturas de referência |
| 3: Luma Apps | **EM ANDAMENTO**. Incremento 1: o app Ajustes (PySide6 + Kirigami) entra na imagem e volta ao dock, com autoteste da interface no CI; a Central de Controle está na barra superior desde a Fase 2. Próximos: Boas-vindas (Plasma Setup) e presets do Monitor do Sistema |
| 4: Gaming | **EM ANDAMENTO** (decisão 0012). Incremento 1: GameMode, MangoHud e gamescope do Fedora na imagem; `luma-jogos` e atalho "Jogos" instalam Steam, Lutris, Heroic e Bottles via Flathub, sem root e sem RPM Fusion. NVIDIA adiada. Medição de jogos exige hardware real |
| 5: Segurança e desempenho | **EM ANDAMENTO**. Incremento 1: controles estáticos no CI (SSH desligado, permissões, zona do firewall) e medições no `sudo luma-diagnostico` (boot, serviços lentos, RAM, energia, AVCs, roteiro de nmap). Os critérios de aceite dependem da VM (nmap, AVCs, comparação com a Kinoite), de hardware (bateria) e da decisão 0009 (updates assinados) |
| 6: Instalador e atualizações | **EM ANDAMENTO**. Incremento 1: kickstart próprio sem nada destrutivo (o instalador deve esperar o usuário em vez de apagar o disco sozinho), teste unitário que barra comandos destrutivos, teste de boot que reprova instalação sem interação, guia `docs/usuario/recuperacao.md`. Bloqueado: canal de atualização assinado (decisão 0009). Pendente: dual boot em disco virtual, marca do Anaconda |
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
2. ~~Flathub~~, ~~NVIDIA~~, ~~Steam e codecs~~: decididos em 2026-10-29 (decisão 0012).
5. Hardware de teste (SSD externo ou máquina descartável). Instalar no notebook principal continua proibido sem autorização específica.
6. Nome e logotipo definitivos (0010).
7. Arquivar o LUMA-OS. O `STATUS.md` dele diz "repositório privado", mas o repositório está público [F].

## Próximo passo
1. CI `ci` e `iso` do incremento de tema: ler os testes F2-I01..I08 e a evidência de `XDG_CONFIG_DIRS` no log.
2. Na VM do usuário: reinstalar com a ISO nova e criar um usuário novo (F2-01). Usuários já existentes mantêm a configuração própria; para eles: `luma-appearance escuro --reset-layout`.
3. Ainda da Fase 1: `getenforce`, zona do firewalld e `bootc status` na VM (F1-06); boot com Secure Boot (F1-05); `sha256sum -c` (F1-02).
