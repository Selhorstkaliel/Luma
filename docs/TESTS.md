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
| F1-03 | ISO inicia até o instalador em QEMU + OVMF com Secure Boot no CI | CI `iso`, passo de boot com OCR | PASSOU (2026-10-29, run iso #8, commit 6624f56): OVMF `OVMF_CODE_4M.secboot.fd` + `OVMF_VARS_4M.ms.fd`; OCR da captura de 240 s: "INSTALLATION PROGRESS LUMA-OS 44 INSTALLATION … /run/install/repo/container". O script deu INCONCLUSIVO porque o marcador "INSTALLATION PROGRESS" faltava; corrigido. **Risco registrado:** a instalação começou sozinha, sem nenhuma interação (kickstart do bootc-image-builder), ou seja, a ISO apaga o disco sem perguntar. Aviso reforçado no LEIA-ME; instalador interativo pendente | [run 40804904677](https://github.com/Selhorstkaliel/Luma/actions/runs/40804904677) |
| F1-04 | `lab.sh check` no host do usuário (ex-F0-08) | laboratório | PENDENTE: exige o PC do usuário | — |
| F1-05 | ISO do Luma inicia com Secure Boot na VM do usuário (ex-F0-10) | `BOOT_ISO=… lab.sh run` + screenshot | PASSOU no sistema **instalado** com Secure Boot (run iso #16 = 40916788628, commit 4b6a478, sistema instalado em QEMU + OVMF com Secure Boot (`scripts/ci/vm-test.sh`)): `SecureBoot=1`, `mokutil`: "SecureBoot enabled". Na VM do usuário: sem SB (2026-10-28) | prints do usuário na conversa (não versionados) |
| F1-06 | Instalação em disco virtual e primeiro boot do sistema instalado | laboratório | PASSOU na instalação automática do CI (run iso #16 = 40916788628, commit 4b6a478, sistema instalado em QEMU + OVMF com Secure Boot (`scripts/ci/vm-test.sh`)): kickstart do CI instalou e desligou em ~8 min; o primeiro boot levou 22,9 s (`systemd-analyze`). Instalação interativa: PARCIAL (VM do usuário, sem SB, 2026-10-28) | print do usuário (Konsole na VM) |
| F1-07 | QML sem erros (ex-F0-05) | `qmllint` dentro da imagem Luma no CI (job imagem) | EM COLETA (2026-10-29, ci #16): só avisos de estilo (`unqualified`, sugestão de `pragma ComponentBehavior: Bound`) em `org.luma.controlcenter/main.qml`; no trecho lido não aparece erro. Passo ainda não bloqueante | [ci 40866760583](https://github.com/Selhorstkaliel/Luma/actions/runs/40866760583) |
| F1-08 | Hostname do sistema instalado é `luma` (o instalador gravava `fedora`) | `luma-hostname.service` (teste unitário `tests/unit/test_hostname.py`, 3/3 local) + `hostnamectl` na VM | PASSOU (run iso #16 = 40916788628, commit 4b6a478, sistema instalado em QEMU + OVMF com Secure Boot (`scripts/ci/vm-test.sh`)): `hostnamectl hostname` = luma, `/etc/hostname` = luma (gravado pelo instalador antes do primeiro boot) | — |
| F1-09 | Evidências da VM num comando: `sudo luma-diagnostico` (SELinux, Secure Boot, firewall, portas, `bootc status`, logos, tema) | F1-I02 no CI + execução na VM | PASSOU (run iso #16 = 40916788628, commit 4b6a478, sistema instalado em QEMU + OVMF com Secure Boot (`scripts/ci/vm-test.sh`)): `sudo luma-diagnostico` rc=0, relatório gravado | — |
| F1-10 | Nenhuma unidade com falha no boot do sistema instalado | `systemctl --failed` no teste do sistema instalado | PASSOU (run iso #20 = 40951701007, commit 5512c1e): 0 unidades com falha no boot. `mcelog` (AMD) e `systemd-remount-fs` (raiz composefs) passam a ser puladas por condição (F1-I03, ci #31). Antes: FALHOU no run iso #19 | — |

## Fase 2 (incremento 1: tema Luma na imagem)
Motivo: na VM o sistema instalado tinha o visual da Kinoite (comentário do usuário: "não foi a luma, foi o fedora"). Até aqui a imagem só trocava o os-release e o firewall.
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F2-I01..I08 | Tema instalado (Look-and-Feel, cores, Aurorae, Central de Controle, wallpaper, ícone), padrão `org.luma.dark.desktop` efetivo pelo `XDG_CONFIG_DIRS` da sessão, Papirus e Inter presentes, sem `fedora-logos`, lançadores do dock existentes | `tests/image/test-image.sh` no CI | PASSOU (testes da imagem 20/20, commit 00850f9). Evidência do log: `fedora-logos` 42.0.1 trocado por `generic-logos` 18.0.0; Firefox no dock = `org.mozilla.firefox.desktop`; a base define `XDG_CONFIG_DIRS=/etc/xdg:/usr/share/kde-settings/kde-profile/default/xdg` (`/etc/xdg/plasma-workspace/env/env.sh`); o Fedora põe `org.fedoraproject.fedora.desktop` no segundo diretório, e o valor efetivo é `org.luma.dark.desktop`. Imagem: 1760 pacotes, 7,70 GB. Antes, o run 40634925786 (commit 95f7ad5) falhou por erro do script (`fc-list \| grep -q` sob `pipefail`, SIGPIPE). Pendência: o `bootc container lint` passou com 3 avisos novos (resíduo do dnf em `/run/dnf`, `/var/log`, `/var/lib/dnf`, `/var/cache/libdnf5`) | [run ci 40635971059](https://github.com/Selhorstkaliel/Luma/actions/runs/40635971059), job imagem (44) |
| F2-01 | Usuário **novo** recebe o visual Luma escuro sem passo manual (barra superior, dock, wallpaper, decoração) | VM do usuário, ISO nova, usuário criado na instalação | PASSOU (run iso #18 = 40931657896, commit b9bc3ad, sistema instalado em QEMU + OVMF com Secure Boot): usuário novo com `LookAndFeelPackage=org.luma.dark.desktop`, papel `file:///usr/share/wallpapers/Luma`, painel superior (kickoff, appmenu, bandeja, `org.luma.controlcenter`, relógio) e dock inferior (icontasks, lixeira); captura `desktop-usuario-novo` no artefato para a revisão visual do usuário | — |
| F2-03 | Tela de boot Luma (Plymouth: logotipo sobre #080D19) no initramfs | `build/image/plymouth.sh` + F2-I09/F2-I10 no CI; boot na VM | PENDENTE (CI e VM) | — |
| F2-04 | Modo desempenho (`luma-appearance desempenho ligado/desligado`: sem desfoque, sem contraste extra, animações zeradas) | stub local das chaves gravadas (2026-10-29: 3 chaves gravadas e 3 removidas, argumento inválido → 64) + efeito na VM | PASSOU (run iso #16 = 40916788628, commit 4b6a478, sistema instalado em QEMU + OVMF com Secure Boot (`scripts/ci/vm-test.sh`)): ligado → blurEnabled=false, contrastEnabled=false, AnimationDurationFactor=0; desligado → chaves removidas | — |
| F2-05 | Tela de login com visual Luma | — | NÃO SE APLICA no F44: o Plasma Login Manager não aceita tema próprio (fixo no Breeze, proposta de mudança do Fedora 44). A tela de **bloqueio** usa o papel de parede Luma (`/etc/xdg/kscreenlockerrc`) | https://fedoraproject.org/wiki/Changes/PlasmaLoginManager |
| F2-06 | Nenhuma tela do usuário novo apresenta o sistema como Fedora (decisão 0010) | OCR da área de trabalho e das boas-vindas no teste do sistema instalado | PASSOU (run iso #20 = 40951701007, commit 5512c1e): sem o `plasma-welcome-fedora` (F2-I11, ci #31), nem a área de trabalho nem a boas-vindas do primeiro login mencionam Fedora (OCR). Antes: FALHOU no run iso #19 ("Bem-vindo ao Fedora!") | — |
| F2-02 | Paleta Midnight medida no mockup aplicada ao esquema escuro, com contraste AA | `tests/unit/test_theme.py` + `docs/design/midnight-tokens.md` | PASSOU na parte automática (2026-10-29): tokens medidos no mockup (mediana por região) e aplicados ao `LumaDark` e ao Aurorae `LumaEscuro`; 16/16 testes de tema, incluindo contraste AA. Revisão visual na VM PENDENTE | `docs/design/midnight-tokens.md` |

## Fase 3 (incremento 1: app Ajustes na imagem)
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F3-I01..I03 | PySide6 e `luma_ajustes` importam; a interface QML (Kirigami) carrega sem tela (`luma-ajustes --verificar`, offscreen); `.desktop` válido | `tests/image/test-image.sh` no CI | PASSOU (2026-10-29): passo "Testes da imagem" verde no ci #15 (8dc7c00) e no ci #16 (f69b10a); o passo falha se qualquer verificação falhar | [ci 40866760583](https://github.com/Selhorstkaliel/Luma/actions/runs/40866760583) |
| F3-01 | Ajustes abre pelo dock e aplica claro/escuro, destaque, animações, texto e transparência sem pedir senha | VM, usuário novo | PASSOU (run iso #18 = 40931657896, commit b9bc3ad, sistema instalado em QEMU + OVMF com Secure Boot): janela aberta (OCR: "Ajustes … Aparência … Cor de destaque"); os 15 comandos dos botões como o usuário, 0 privilegiados, 0 falhas; claro, destaque #C83C81 (variante acessível do rosa), animações 0, Inter 12, translucidez ligada. Defeito do `qdbus6` (iso #16) corrigido. Pelo dock, com clique: não automatizado | — |
| F3-02 | Central de Controle (barra superior) mostra Wi-Fi, Bluetooth, Não perturbe, brilho e volume | VM | PASSOU na presença (run iso #18 = 40931657896, commit b9bc3ad, sistema instalado em QEMU + OVMF com Secure Boot): `org.luma.controlcenter` no painel superior do usuário novo. Conteúdo do painel (Wi-Fi, Bluetooth, brilho, volume): revisão visual | — |
| F3-03 | Boas-vindas do Luma no primeiro login (no lugar da do KDE), sem reabrir depois de "Concluir" | `luma-boas-vindas` (modo do app Ajustes: 4 passos — boas-vindas, claro/escuro, jogos, atualizações), autostart em `/etc/xdg/autostart`, autostart da do KDE com `Hidden=true`; testes unitários (marca por versão, ações sem privilégio), F3-I05/F3-I06 na imagem e o teste do sistema instalado (o KWin lista "Boas-vindas ao Luma", o `plasma-welcome` não roda, depois da marca `luma-boas-vindas` sai sem janela) | IMPLEMENTADO (2026-10-30); PENDENTE de CI. Os presets do Monitor do Sistema saíram deste critério, ver F3-04 | — |
| F3-04 | Presets do Monitor do Sistema | — | [D] PROPOSTA: retirar da Fase 3. O formato `.page` do plasma-systemmonitor não está documentado [H] e quebra entre versões do Plasma; a página "Visão geral" já cobre CPU, memória, disco e rede, e a boas-vindas abre o Monitor. Decisão do usuário | — |

## Fase 4 (incremento 1: ferramentas de jogo e lojas via Flatpak, decisão 0012)
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F4-U01 | `luma-jogos` gera só comandos Flatpak de usuário, recusa app desconhecido e não usa RPM Fusion | `tests/unit/test_jogos.py` (`--simular`) | PASSOU (local, 4/4) | — |
| F4-I01..I03 | GameMode, MangoHud e gamescope na imagem; `luma-jogos` presente; nenhum pacote nem repositório **habilitado** do RPM Fusion (os `.repo` desabilitados da base são permitidos; a premissa anterior, "nenhum arquivo", derrubou o ci #21 e o iso #11) | `tests/image/test-image.sh` no CI | PASSOU (2026-10-29: ci #22 = ce190d2, ci #24, ci #25 e iso #14; o passo sai com erro se qualquer verificação falhar) | — |
| F4-01 | `luma-jogos instalar steam` instala o Steam sem senha e ele abre | VM do usuário | PASSOU (run iso #20 = 40951701007, commit 5512c1e): `luma-jogos instalar steam` como usuário, sem senha, em 34 s; aberto como o menu abre (systemd --user, com DISPLAY=:0 e WAYLAND_DISPLAY=wayland-0 da sessão), o Steam mostrou a tela de login (OCR: "SIGN IN WITH ACCOUNT NAME … OR SIGN IN WITH QR"). Correção registrada: o "PASSOU" dos runs #16/#18 era falso (aviso de sessão sem DISPLAY lido como "Steam") | — |
| F4-02 | 3 jogos (1 nativo, 2 Proton, sem anticheat) abrem e rodam 10 min | **hardware real** (VM sem 3D) | BLOQUEADO: falta hardware de teste autorizado | — |
| F4-03 | Variante NVIDIA | — | ADIADO (decisão 0012) | — |

## Fase 5 (incremento 1: controles estáticos e instrumentos de medição)
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F5-I01..I04 | SSH desligado por padrão; arquivos do Luma não graváveis por todos; zona `luma` sem ACCEPT; `luma-diagnostico` mede boot, RAM e AVCs | `tests/image/test-image.sh` no CI | PENDENTE (CI) | — |
| F5-01 | Nenhuma porta aberta vista de fora | `sudo nmap -Pn -sS -p- --open <IP da VM>` no host (o `luma-diagnostico` imprime o comando) | PASSOU (run iso #16 = 40916788628, commit 4b6a478, sistema instalado em QEMU + OVMF com Secure Boot (`scripts/ci/vm-test.sh`)): `nmap -Pn -sS -p- -T4` do host por uma tap: nenhuma porta aberta; 8080/tcp **filtered** com um serviço escutando na VM | — |
| F5-02 | Zero AVCs não explicados após uso normal (sessão, Ajustes, `luma-jogos`) | seção AVC do `sudo luma-diagnostico` | PARCIAL (run iso #19 = 40940343912, commit 969cc3c): 8 AVCs desde o boot, **0 do Luma**, 8 da base (`mac_admin` de `chcon` em `tuned_t` ×6 e `initrc_t` ×2, antes do login). Nenhum AVC da sessão, do Ajustes, do Lume, do `luma-jogos` ou do Steam. [H] Os mesmos AVCs na Kinoite pura (comparação no F5-03) | — |
| F5-03 | Boot e RAM ociosa ≤ Kinoite pura +10% / +15% | workflow `medicao` (sob demanda): Luma × Kinoite 44 pura, mesma VM (6 GiB, 4 CPUs, Secure Boot, sem 3D), mesmo kickstart, usuário novo com login automático; 120 s parado após o login; RAM usada = MemTotal − MemAvailable; boot = fim do userspace; mediana de 3 boots; PSS por processo (`scripts/ci/vm-medicao.sh`, `scripts/ci/medicao-compara.py`) | PENDENTE (primeira medição no próximo run `medicao`). Referência sem comparação: 1675–1803 MiB de RAM usada nos runs iso #16–#23, medida pelo roteiro funcional 60 s após o login, com o teste rodando — não serve para o critério. Limite declarado: sem 3D (llvmpipe usa RAM comum), os números absolutos não valem para hardware real; a diferença relativa é a medida [H] | — |
| F5-04 | Bateria em repouso ≤ Kinoite pura +5% | `upower`, hardware real | BLOQUEADO: hardware | — |
| F5-05 | Atualização assinada e rollback | — | BLOQUEADO: decisão 0009 (GHCR + cosign) | — |

## Fase 6 (incremento 1: instalador interativo e guia de recuperação)
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F6-U01 | Kickstart da ISO sem comando destrutivo nem modo automático | `tests/unit/test_installer.py` sobre `build/iso/config.toml` | PASSOU (local, 2/2) | — |
| F6-01 | O instalador para na tela de resumo e espera o usuário (não apaga o disco sozinho) | CI `iso`: OCR aos 240 s deve achar "INSTALLATION SUMMARY"/"RESUMO DA INSTALAÇÃO"; "INSTALLATION PROGRESS" sem interação reprova | PASSOU (2026-10-29, run iso #14 = 40887691891, commit 36b943c, OVMF com Secure Boot): veredito INSTALADOR; OCR aos 240 s: "INSTALLATION SUMMARY ... Installation Destination ... Root account is disabled ... No user will be created ... Begin installation  We won't touch your disks until you click 'Begin Installation'". Observação [H]: a interface apareceu em inglês e o indicador de teclado em "us" no OCR; se o kickstart `lang`/`keyboard` vale para o sistema instalado é o F6-02 | — |
| F6-02 | Idioma pt-BR, teclado br e hostname `luma` vêm do kickstart | VM | PASSOU (run iso #18 = 40931657896, commit b9bc3ad, sistema instalado em QEMU + OVMF com Secure Boot): LANG=pt_BR.UTF-8, teclado br-abnt2/br, fuso America/Sao_Paulo. Vêm do `/etc` da imagem (F6-I01), porque o Anaconda com ostreecontainer não aplica `lang`/`keyboard`/`timezone` do kickstart (iso #16); o hostname vem do kickstart. A interface do instalador continua em inglês | — |
| F6-03 | Recuperação documentada (rollback, entrada anterior do GRUB, TTY, reinstalação) | `docs/usuario/recuperacao.md` | ESCRITO; os passos de rollback estão BLOQUEADOS pela decisão 0009 (não há segunda versão) | — |
| F6-04 | Dual boot com Windows em disco virtual | VM com Windows | PENDENTE | — |
| F6-05 | Marca Luma no Anaconda (logos/cores) | — | NÃO INICIADO; hoje só o nome do produto é Luma-OS | — |
| F6-06 | Canal de atualização assinado | — | BLOQUEADO: decisão 0009 (usuário: "ainda não", 2026-10-29) | — |

## Fase 7 (Lume 0.1, decisão 0013)
| ID | Critério | Como | Estado | Evidência |
|---|---|---|---|---|
| F7-U01 | Lexer, parser e verificador (posições, precedência, erros) | `lume/tests/test_lume_frontend.py` | PASSOU (local, 12/12) | — |
| F7-U02 | Semântica do Python gerado (recursão, laços, closures, if/else if, nomes reservados, erro de execução com linha do .lume) | `lume/tests/test_lume_semantics.py` | PASSOU (local, 9/9) | — |
| F7-I01 | Janela do `ola.lume` e botão do `contador.lume` funcionam sem tela | `test_lume_ui.py` (offscreen) | PASSOU localmente (2026-10-29, PySide6 6.12.0 via pip, Qt offscreen, 2/2: título e visibilidade da janela; 2 cliques → "Cliques: 2"). No CI, dentro da imagem com o `python3-pyside6` do Fedora: PASSOU (ci #24 = 40883325392 e ci #25 = 40887691692; o passo sai com erro se o Qt faltar, `LUME_EXIGIR_QT=1`) | — |
| F7-01 | "hello world" Lume com janela Qt no Luma (critério da Fase 7) | VM: `python3 lume/bin/lumec run lume/examples/ola.lume` | PASSOU (run iso #22 = 40982053266, commit e8b7bb3): `lumec run ola.lume` como o usuário novo e o **KWin lista a janela** "Olá do Lume" na Área de trabalho 1 (`busctl … /WindowsRunner org.kde.krunner1 Match` → `"Ol\303\241 do Lume" "wayland"`); o OCR leu o texto da janela no run #18; nos #20–#22 a captura não mostrou a janela (pendência visual, ver `lume-ola.png`) | — |

## Teste do sistema instalado no CI (desde 2026-10-29)
Os critérios marcados "VM" acima passam a ter uma execução automática no workflow `iso`, depois do envio da ISO do usuário (`scripts/ci/vm-test.sh`):
- uma ISO **de teste** é gerada com o kickstart do CI (`tests/vm/ks-ci.sh`): o kickstart real, mais apagar o disco virtual, o usuário `teste` e o desligamento no fim. Essa ISO nunca vai para artefato e é apagada logo após a instalação;
- a instalação roda sem interação no QEMU com OVMF, Secure Boot e chaves Microsoft;
- o sistema instalado liga com o login automático do usuário novo. `tests/vm/guest/luma-ci-checks.sh` confere por dentro: hostname, SELinux, Secure Boot, zona, idioma, teclado e fuso; Look-and-Feel, painéis e Central de Controle; os comandos do Ajustes como usuário, sem senha; o modo desempenho; `lumec run ola.lume`; `luma-jogos instalar steam` e o Steam abrindo; os AVCs; e o `luma-diagnostico`;
- o host faz as capturas com OCR e o `nmap -p-` de fora, por uma tap só com o host, com um serviço escutando na 8080 da VM.

Limites declarados:
- é a instalação **automática**, não a interativa da ISO entregue; ela é a mesma, menos as escolhas da tela de resumo;
- o login é automático (`/etc/plasmalogin.conf` só na instalação de teste);
- os comandos de teste rodam como o usuário, via `runuser`, e não pelos cliques no dock;
- sem 3D (llvmpipe);
- a revisão visual continua sendo humana: as capturas vão no artefato `…-evidencias-vm`.

Resultados:
- iso #15 (bf11941): não avaliou nada. O roteiro não entrou na instalação (o `%post` do instalador não gravou os arquivos) e o veredito caiu com arquivo ausente. Defeitos do teste, corrigidos.
- iso #16 (4b6a478): primeira execução completa.
- iso #17 (3c1743b): não chegou à VM (erro de digitação no F4-I01 e upload sem pasta; corrigidos).
- iso #18 (b9bc3ad): F6-02, F3-01, F2-01, F3-02 e F7-01 passam a PASSOU; ficam F5-02 (AVCs da base) e F1-10. Boot 15,7 s; RAM 1803 MiB.
- iso #19 (969cc3c): F5-02 sem nenhum AVC do Luma; causas das duas unidades com falha (base); dois achados novos: o Steam não abriu (o PASSOU anterior era falso, por OCR frouxo) e a boas-vindas diz "Fedora" (F2-06).
- iso #20 (5512c1e): F1-10, F2-06 e F4-01 PASSOU; todos os demais critérios de VM PASSOU, exceto o F5-02 (PARCIAL: 8 AVCs, 0 do Luma) e o OCR da janela do Lume (captura sem texto legível; o processo estava vivo e o mesmo OCR passou no #18), que agora tem espera maior, duas capturas e OCR ampliado. Boot 23,2 s; RAM 1675 MiB.
- iso #21 (d6702c8): mesmo quadro do #20. O OCR do Lume de novo sem a janela (processo vivo). A prova passa a ser o KWin listar a janela pelo título (F7-01-JANELA), e o OCR vira evidência visual.
- iso #22 (e8b7bb3): o KWin listou a janela do Lume ("Ol\303\241 do Lume", Área de trabalho 1); o FALHOU do F7-01-JANELA foi meu (o `busctl` escreve UTF-8 em octal e o grep procurava "Olá"). Corrigido. Todo o resto igual ao #20/#21.
- **iso #23 (d842baa, run 40989488536): primeiro run inteiramente verde.** Todos os critérios PASSOU, inclusive o F7-01-JANELA (o KWin lista "Olá do Lume"). Únicos não-PASSOU: F5-02 PARCIAL (8 AVCs da base, 0 do Luma) e as INFO visuais (F7-01-OCR, F2-03). Boot 17,2 s; RAM 1691 MiB. Medidas: boot 22,9 s; RAM 1793 MiB usada 60 s após o login, sem apps abertos (VM de 6 GiB, sem comparação com a Kinoite pura ainda).

## Regressão herdada do LUMA-OS
Os critérios E1–E9 do LUMA-OS (`docs/TESTS.md` dele) servem de checklist das Fases 1, 2, 5 e 6. Cada um precisa passar de novo no Fedora ou ter a exceção registrada na decisão correspondente.
