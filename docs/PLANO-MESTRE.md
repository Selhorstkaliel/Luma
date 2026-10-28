# Luma-OS Midnight Edition: plano mestre (aprovado em 2026-10-28)

Legenda: **[F]** fato verificado nesta sessão · **[H]** hipótese a validar · **[D]** decisão pendente do usuário.
Classificação geral da proposta: **Aprovada com ressalvas** (ver §0).

---

## 0. Contexto e veredito

**Objetivo:** transformar o Luma (hoje uma derivada Debian validada em VM) numa distribuição baseada em Fedora 44, com KDE Plasma, visual "Midnight", foco em jogos e apps próprios, instalável em hardware real.

**Ressalvas que mudam o plano (confrontos):**
1. **Não se começa do zero.** [F] `Selhorstkaliel/LUMA-OS` tem a v0.8.0: 521 arquivos, 9 etapas com evidências e ISO instalável testada em VM (66/66 normal, 42/42 LUKS). Parte disso é reaproveitável e parte é específica do Debian (§2). Ignorar esse histórico desperdiçaria trabalho já validado.
2. **O Fedora 44 está perto do fim do ciclo.** [F] Ele saiu em 28/04/2026. [F] O Fedora 45 passou do beta (15/09), e o lançamento de 20/10 foi adiado, com datas de contingência em 27/10 ou 03/11. [H] O F44 deve perder suporte cerca de 4 semanas depois do lançamento do F46, por volta de meados de 2027. **Recomendação:** desenvolver no 44, como você pediu, mas com a versão parametrizada (`FEDORA_VERSION`) e com um rebase para o 45 planejado antes da alpha. Com bootc, o rebase é a troca de uma tag mais uma nova rodada de validação.
3. **O escopo é grande para uma pessoa.** O plano junta 7 apps próprios, modo gaming e uma linguagem nova (Lume). [F] Segundo você, o lumec ainda não existe. Criar uma linguagem é um projeto à parte. Ele **não pode ficar no caminho crítico do sistema operacional** (§7, Fase 7).
4. **A referência visual tem riscos jurídicos.** [F] O mockup mostra o **logotipo da Apple** na barra superior, o tema "WhiteSur", os logotipos de YouTube, Netflix, Spotify e Amazon, e a capa do álbum "After Dark/Mr.Kitty". Nada disso pode ir para a distribuição. Vale o que o projeto já decidiu (`luma-visual-spec.md`): reproduzir o **estilo**, não os ativos. Os wallpapers do mockup têm origem e licença desconhecidas, então só entram com licença comprovada ou como arte original.
5. **Marca Fedora.** [H] Pelas diretrizes de marca do Fedora, uma derivada com repositórios de terceiros (RPM Fusion, Steam) não pode usar o nome nem o logotipo do Fedora. É preciso trocar `fedora-logos` por logos próprios ou genéricos e não se apresentar como "Fedora". Validar com o texto oficial na Fase 0.

---

## 1. Diagnóstico técnico do repositório

| Item | Situação |
|---|---|
| `Selhorstkaliel/Luma` (branch alvo `claude/eager-franklin-mb8qmf`) | [F] Vazio: 0 commits, 0 branches. É onde a edição Fedora vai nascer. |
| `Selhorstkaliel/LUMA-OS` | [F] **Público** (o STATUS.md diz "privado": inconsistência a corrigir ou ao menos registrar). Última versão 0.8.0 (01/10/2026), descrita como "projeto encerrado pelo usuário". 62 MB, quase tudo de evidências (PNG/logs). A varredura de segredos (`$6$`, `$y$`, chaves privadas) não achou nada [F]. |
| Base atual | [F] Debian 13 trixie, Plasma 6.3.6, Qt 6.8, live-build, Calamares 3.3.14, ufw, AppArmor, APT/`.deb` (`debian/control`: luma-theme, luma-session, luma-firewall, luma-ajustes, luma-live, luma-windows). |
| Laboratório | [F] QEMU/KVM + OVMF com Secure Boot dentro do WSL2 (host Windows 11, i5-12450HX, **7,7 GiB de RAM**, RTX 3050 híbrida). Foi apagado; precisa ser recriado. Não há aceleração 3D na VM. |
| CI | [F] `.github/workflows/lint.yml`: shellcheck, AST de Python e varredura de segredos. |
| Etapa 6 (Windows) | [F] Suspensa: `wineboot -u` falhou na VM ("could not load kernel32.dll"), causa não investigada. |

### Matriz de reaproveitamento (o que vem do LUMA-OS)
| Componente (LUMA-OS) | Destino | Observação |
|---|---|---|
| `theme/color-schemes`, `theme/tools/gen-color-schemes.py`, `theme/tests/test_theme.py` | **Reaproveitar**: ganham a paleta Midnight | Agnósticos de distro; o teste de contraste AA continua obrigatório. |
| `theme/aurorae/*`, `theme/tools/gen-aurorae.py` | Reaproveitar e ajustar | [H] Aurorae no Plasma 6.6: validar. |
| `theme/look-and-feel/*`, `theme/layouts/luma-layout.js` | Reaproveitar e adaptar | `firefox-esr.desktop` vira `org.mozilla.firefox.desktop`/`firefox.desktop`; [H] API de scripting 6.6. |
| `theme/plasmoids/org.luma.controlcenter` | Reaproveitar (vira a base do Luma Control Center) | Usa só NM, BlueZ, notificações e PipeWire: portável. |
| `theme/bin/luma-appearance` | Reaproveitar e **revalidar** | O contorno era para um bug do Plasma 6.3 [F]; [H] pode ser desnecessário no 6.6. |
| `apps/ajustes` (PySide6 + Kirigami, 11 testes) | Reaproveitar (vira Luma Settings > Aparência) | [H] `python3-pyside6` empacotado no F44: verificar. |
| `session/xdg/*` (kdeglobals, kwinrc, kscreenlockerrc) | Adaptar | No Fedora, os padrões do KDE vêm de `kde-settings`; [H] precedência do `/etc/xdg` × `/usr/share/kde-settings`. |
| `windows/luma-windows-run` (+ man e .desktop) | Reaproveitar | Wine do Fedora (WoW64); o bug de `wineboot` precisa ser retestado. |
| `scripts/lab/*` (lab.sh, qga.py, QMP screendump, OVMF SB) | Adaptar | O conceito é bom; trocar o preseed Debian por kickstart/ISO bootc. |
| `docs/decisions` (0001–0007), `TESTS.md`, modelo de ameaças, método "sem evidência não é APROVADA" | Manter o **método**; reescrever o conteúdo | ADRs novas a partir da 0008, com a 0001 marcada como "substituída". |
| `debian/`, `live/` (live-build), Calamares, `luma-live`, `build-debs.sh`, `build-iso.sh`, preseed, fixtures de APT | **Descartar** (ficam no arquivo do LUMA-OS) | Calamares não instala sistemas ostree/bootc. |
| `security/firewall` (ufw) | Reescrever em firewalld | [H] A zona padrão do Fedora KDE pode **liberar as portas 1025–65535 de entrada** (zona FedoraWorkstation). Isso regride o controle E7-01; tratar na Fase 5. |
| Referências a AppArmor | Trocar por SELinux enforcing | |

---

## 2. Arquitetura definitiva recomendada

**Decisão do usuário: Atomic.** A imagem bootc/OCI é derivada da **Fedora Kinoite 44** oficial (`quay.io/fedora/fedora-kinoite:44`). É o modelo usado por Bazzite e Aurora, mas sem depender deles na base.

```
┌──────────────────────────────────────────────────────────────┐
│ Luma Apps (Qt6/QML)   Control Center · Settings · Welcome     │
│                       Gaming Hub · (Monitor/Update = KDE)     │
├──────────────────────────────────────────────────────────────┤
│ Midnight Desktop: Look-and-Feel · color scheme · Aurorae ·    │
│ layout (barra + dock) · plasmoids · Kvantum? · login/splash   │
├──────────────────────────────────────────────────────────────┤
│ KDE Plasma 6.6 · KWin (Wayland, sem fork) · Plasma Login Mgr  │
│ · Plasma Setup (1º boot) · Discover (backend rpm-ostree/      │
│ Flatpak)                                                      │
├──────────────────────────────────────────────────────────────┤
│ Gaming layer: Steam (RPM Fusion) · gamescope-session ·        │
│ MangoHud · GameMode · Lutris/Heroic (Flatpak) · Wine          │
├──────────────────────────────────────────────────────────────┤
│ Fedora Kinoite 44: kernel · rpm-ostree/bootc · SELinux ·      │
│ firewalld · PipeWire/WirePlumber · Mesa · NVIDIA (variante)   │
└──────────────────────────────────────────────────────────────┘
Fora da imagem base: Lume SDK (repositório próprio; entregue por Flatpak/toolbox/RPM opcional)
```

**Pilares:**
- **Imagem:** `Containerfile` com `FROM quay.io/fedora/fedora-kinoite:${FEDORA_VERSION}`. Pacotes extras via `dnf`/`rpm-ostree` no build; componentes Luma em RPMs próprios (`luma-*.spec`), construídos num estágio multi-stage.
- **Variantes:** `luma` (Mesa: Intel/AMD) e `luma-nvidia` (kmod proprietário pré-compilado e assinado). **[D]** NVIDIA via akmods do Universal Blue (pronto, mas é dependência de terceiros) ou pipeline própria de kmod. Recomendação: começar pelos akmods do ublue e registrar a dependência numa ADR.
- **Atualizações:** `bootc upgrade` a partir de um registro OCI, com rollback atômico (entrada anterior no GRUB). Imagens **assinadas com cosign** e política em `/etc/containers/policy.json` que recusa imagem não assinada.
- **Apps gráficos de terceiros:** Flatpak/Flathub. **[D]** Isso reabre a decisão 0004. Recomendação: pré-configurar o Flathub, porque Lutris, Heroic e Bottles dependem dele, e manter o filtro de verificados como opcional.
- **Instalador:** Anaconda gerado pelo image-builder. [F] O `bootc-image-builder` foi arquivado (jun/2026) e incorporado ao `image-builder`. O tipo `anaconda-iso` deu lugar a `bootc-generic-iso`/`bootc-installer`. [H] Comandos e nomes exatos devem ser conferidos na documentação atual na Fase 1.
- **Sessão Live:** [H] as ISOs Atomic oficiais são só de instalação. A live é possível com Titanoboa (ublue) ou com uma ISO live própria. É **opcional** e não bloqueia a alpha.
- **Plasma 6.6 no F44:** [F] traz o Plasma Login Manager no lugar do SDDM e o **Plasma Setup** como assistente de primeiro boot. Consequência: a "Luma Welcome" deve **estender o Plasma Setup** em vez de criar outro assistente, e o tema da tela de login vira tema do Plasma Login Manager.

**Princípio:** KDE nativo primeiro. Nenhum fork do KWin. Componente próprio só quando não existe equivalente:

| App pedido | Recomendação | Motivo |
|---|---|---|
| Luma Control Center | Próprio (plasmoide que já existe) | O mockup pede um painel unificado. |
| Luma Settings / Appearance | Próprio e **um app só** (Ajustes) | Appearance vira seção, para não duplicar. |
| Luma Welcome | Extensão ou páginas do **Plasma Setup** + app curto pós-login | Evita um segundo assistente. |
| Luma System Monitor | **plasma-systemmonitor** com páginas e tema Luma | Reescrever não traz ganho mensurável. |
| Luma Update | **Discover** (rpm-ostree + Flatpak) + notificação | Atualização é crítica; não reinventar. |
| Luma Gaming Hub | Próprio e fino (atalhos, perfis, estado de drivers) | Só depois da Fase 4 validada. |

---

## 3. Estratégia de migração para Fedora 44

1. O LUMA-OS fica congelado como **"Luma Debian Edition 0.8.0 (arquivada)"**. Nada é apagado.
2. Os ativos agnósticos (§1) são portados para o repo `Luma`, com **histórico de origem citado** (commit 44903f2) na ADR 0008.
3. Os testes são reescritos por camada: unit (Python/QML), imagem (`podman run` + checagens de arquivo, RPM e SELinux), VM (boot, instalação, sessão, via QMP) e hardware.
4. Equivalências: `apt`/`dpkg` → `rpm-ostree`/`bootc`/`dnf` (no build); ufw → firewalld; AppArmor → SELinux; live-build → Containerfile + image-builder; Calamares → Anaconda; `.deb` → `.spec`; `/etc/xdg` → validar contra `kde-settings`.
5. Os critérios de aceite antigos (E1–E9) servem de **checklist de regressão**: tudo o que passou no Debian precisa passar de novo no Fedora, ou ter a exceção registrada.

---

## 4. Estratégia de construção da ISO e da imagem

| Etapa | Ferramenta | Onde |
|---|---|---|
| Build da imagem OCI | `podman build` (Containerfile multi-stage, RPMs Luma no estágio 1) | GitHub Actions (runner Linux) e WSL2 Fedora local |
| Teste da imagem | `podman run` + `bootc container lint` [H] + checagens próprias | CI |
| Assinatura | cosign (chave em GitHub Secrets) | CI, **só com autorização para publicar** |
| ISO de instalação | `image-builder` (`bootc-installer`/`bootc-generic-iso`) [H] | CI (privilegiado) ou WSL2 |
| Artefatos | `luma-<ver>-x86_64.iso`, `.sha256`, manifesto (`rpm -qa`, digest da imagem), log | CI |
| Reprodutibilidade | Base fixada por **digest**, `dnf` com versões registradas, diff de manifestos entre builds | Não prometer bit a bit (mesma postura da 0005) |

[F] O host tem 7,7 GiB de RAM. Builds e ISO vão para o **CI**; o laptop fica para testes em VM, uma por vez. **[D]** Usar GitHub Actions e GHCR conta como publicação e exige sua autorização (regra do CLAUDE.md antigo). Sem essa autorização, tudo roda local no WSL2: mais lento, e já travou antes (etapa 8, falha1).

---

## 5. Plano da interface Midnight

**Tokens Midnight** (a medir na referência, como foi feito na 0.6.1): fundo `#0B0F1F`–`#141A2E`, superfícies translúcidas azul-escuro, acento violeta/rosa (`#8B5CF6`/`#EC4899`), texto com contraste ≥ 4,5:1. [H] Os valores finais saem da medição.

| Elemento | Implementação (nativo primeiro) |
|---|---|
| Barra superior global | Painel do Plasma + `appmenu` + bandeja + Control Center (layout.js existente) |
| Dock flutuante / dock lateral opcional | Painel `floating` + `icontasks`; a lateral é um segundo layout escolhido em Ajustes |
| Blur e transparência | Efeito Blur nativo do KWin + estilo Plasma translúcido; **modo desempenho reduzido** desliga blur e animações (perfil detectado por GPU/RAM, ajustável) |
| Cantos arredondados nas janelas | [H] Aurorae arredonda só os cantos de cima. A opção é o KWin effect "Rounded Corners" (terceiros), mas a recomendação é **não** incluir na alpha, por risco de quebrar a cada versão do Plasma |
| Launcher com pesquisa em grade | Kickoff em grade (já usado) → avaliar um plasmoide próprio só se o Kickoff não alcançar o mockup |
| Central de controle com widgets e mídia | Plasmoide `org.luma.controlcenter` + MPRIS (`org.kde.plasma.mediacontroller`) |
| Dashboard de desempenho | Páginas do plasma-systemmonitor + widget de sensores |
| Gerenciador de arquivos e terminal | Dolphin e Konsole com esquema e perfil Luma (sem fork) |
| Tela de login e bloqueio | Tema do Plasma Login Manager + kscreenlocker com wallpaper panorâmico **original** |
| Boot | Plymouth Luma; GRUB com tema; sem logos Fedora |
| HiDPI e multimonitor | Nativo do KWin; testes em 100/150/200% e com 2 monitores (VM: 2 saídas virtio) |
| Ícones | Papirus (GPL-3.0) ou set próprio; **sem ícones de marcas** |

---

## 6. Gaming e compatibilidade

- **Steam:** RPM do RPM Fusion nonfree, na imagem. **[D]** Distribuir o Steam embutido segue o modelo do Bazzite, mas a licença de redistribuição precisa ser confirmada. A alternativa sem esse risco é o Steam Flatpak instalado no primeiro boot.
- **Proton:** vem pelo Steam. Proton-GE fica opcional, via ProtonUp-Qt (Flatpak).
- **Vulkan:** Mesa (RADV/ANV) e NVIDIA proprietário na variante. 32 bits (`mesa-*.i686`) para o Steam.
- **Modo gaming em tela cheia:** sessão `gamescope-session` (projeto ChimeraOS/Bazzite) como sessão no Plasma Login Manager, com o Steam Big Picture. [H] Empacotamento no F44: verificar.
- **Lutris e Heroic:** Flatpak. **Wine:** RPM do Fedora (no build) + `luma-windows-run`.
- **Controles:** `steam-devices` (udev), `game-devices-udev` [H].
- **Ferramentas:** GameMode, MangoHud (medição), `tuned-ppd`.
- **Codecs:** **[D]** `ffmpeg` completo e Mesa freeworld (RPM Fusion) trazem risco de patente (H.264/HEVC), que varia por jurisdição. Recomendação: incluir, com uma ADR jurídica e um aviso.
- **Sem promessas:** jogos com anticheat em kernel, apps UWP/iOS e "qualquer .exe". Vale o modelo de duas camadas da ADR 0007.
- **Benchmarks:** [F] a VM não tem 3D, então **otimização de jogos só com hardware real**. Método: o mesmo jogo, a mesma cena e a mesma configuração, Kinoite puro × Luma, com 3 execuções, mediana e desvio, medindo FPS médio e 1% low pelo MangoHud. Nenhum número antes disso.

---

## 7. Modelo de segurança

| Controle | Mecanismo | Teste |
|---|---|---|
| SELinux enforcing | Política do Fedora; **nenhum módulo próprio** salvo necessidade comprovada | `getenforce`; `ausearch -m avc` vazio após o roteiro de sessão e jogo |
| Firewall: entrada negada | firewalld com zona `luma` padrão (deny incoming, exceto o que o usuário liberar) | varredura `nmap` a partir do host da VM (como na E7-01) |
| Sistema imutável | `/usr` só leitura (ostree) | tentativa de escrita falha; `rpm-ostree status` |
| Atualização íntegra | cosign + `policy.json` recusando imagem não assinada | teste com imagem adulterada e com chave errada (paralelo à E7-03) |
| Rollback | entrada anterior no GRUB; `bootc rollback` | atualização propositalmente quebrada, com boot da anterior |
| Disco | LUKS2 pelo Anaconda (opcional e recomendado em notebook); [H] desbloqueio por TPM2 só depois | `cryptsetup luksDump` mostra versão 2 |
| Secure Boot | shim/GRUB/kernel Fedora assinados; a variante NVIDIA exige **inscrição de MOK** | boot com SB ativo (OVMF com chaves MS) |
| Apps | Flatpak (sandbox por permissão); apps nativos **não confinados** (limite declarado) | — |
| Wine | Não é barreira de segurança (aviso já existente) | E6 |
| Cadeia de suprimentos | Base fixada por digest; Dependabot/Renovate para digests; chave cosign fora do repo | revisão de PR |

**Ponto crítico:** o CI vira o ponto único de confiança. Um CI comprometido entrega imagem maliciosa para todos os usuários. Mitigações: branch protegida, revisão obrigatória, ambiente de release com aprovação manual e escopo mínimo do token.

---

## 8. Estrutura do repositório `Luma`

```
Containerfile                 # imagem bootc (ARG FEDORA_VERSION, VARIANT)
build/        image/ (scripts executados no build), iso/ (config image-builder, kickstart)
packages/     lists/{base,gaming,remove}.txt · specs/luma-{theme,session,settings,…}.spec
configs/      usr/ e etc/ espelhados (xdg, firewalld, systemd presets, polkit, containers/policy.json)
branding/     os-release, logos, plymouth, grub, plasma-login
themes/       color-schemes/, aurorae/, look-and-feel/, tools/ (geradores)  ← do LUMA-OS
icons/        wallpapers/ (fonte SVG + gerador, só arte original)
plasma/       plasmoids/ (controlcenter), layouts/, kwin/ (configs, sem fork)
qml/          org.luma.components (biblioteca QML compartilhada)
apps/         settings/ (← ajustes), welcome/, gaming-hub/
gaming/       gamescope-session/, mangohud/, udev/
security/     firewalld/, threat-model.md
installer/    anaconda branding, kickstart
lume-sdk/     README + contrato de integração (código em repo separado)
scripts/      lab/ (← LUMA-OS adaptado), ci/
tests/        unit/, image/, vm/, visual/
docs/         decisions/ (0008+), STATUS.md, TESTS.md, design/, usuario/
.github/workflows/  (ci/ como scripts chamados pelos workflows)
```

---

## 9. Roadmap por fase

Complexidade: P (pequena) · M · G · XG. **Não há estimativa em dias** porque falta dado de disponibilidade.

### Fase 0: Auditoria e bootstrap · M
- **Objetivo:** repo `Luma` estruturado; ADRs 0008 (Fedora Atomic), 0009 (registro/CI), 0010 (marca); portar os ativos reaproveitáveis; laboratório WSL2 Fedora + QEMU/OVMF recriado.
- **Dependências:** suas decisões [D] (§12).
- **Arquivos:** toda a árvore de §8; `docs/decisions/0008..0010`; `scripts/lab/*`.
- **Testes automatizados:** lint (shellcheck, ruff, qmllint), `test_theme.py` e `test_core.py` passando no novo repo.
- **Aceite / avanço:** CI verde; inventário de licenças de cada ativo portado; lab sobe uma VM Kinoite 44 oficial com SB.

### Fase 1: Fedora Core · G
- **Objetivo:** imagem `luma:44` mínima (Kinoite + os-release + logos próprios + firewalld `luma`), sua ISO de instalação e o boot instalado.
- **Riscos:** nomes e opções do image-builder [H]; tamanho da ISO; WSL sem memória.
- **Testes automatizados:** build da imagem; `bootc container lint`; checagem de os-release, ausência de `fedora-logos` e `getenforce` no container; boot da ISO em OVMF+SB via QMP; instalação desassistida por kickstart; `bootc status` após o boot.
- **Manuais:** instalação interativa normal e com LUKS2.
- **Aceite:** ISO instala e inicia com SB, SELinux enforcing, firewall deny-in comprovado por nmap, `bootc upgrade` e `rollback` funcionando entre duas builds.

### Fase 2: Midnight Desktop · G
- **Objetivo:** tema, layout, Control Center, login, Plymouth, wallpapers originais e modo de desempenho reduzido.
- **Testes automatizados:** contraste AA; screenshots QMP em 1366×768, 1920×1080 e 150%, comparadas com uma referência aprovada (diff perceptual com limiar); `kreadconfig6` confere os padrões de um usuário novo.
- **Manuais:** revisão visual contra o mockup, com uma lista de diferenças aceitas.
- **Aceite:** usuário novo recebe o Midnight sem passo manual; RAM ociosa ≤ Kinoite puro +15%.

### Fase 3: Luma Apps · G
- **Objetivo:** Settings (Aparência, Layout, Desempenho), Control Center completo, Welcome (Plasma Setup + pós-login) e os presets do System Monitor.
- **Testes:** unit da lógica sem Qt (padrão do `core.py`); qmltestrunner; testes de sessão na VM.
- **Aceite:** nenhuma ação exige root fora do polkit; todos os apps em pt-BR; zero AVC.

### Fase 4: Gaming Experience · G (validação: XG, depende de hardware)
- **Objetivo:** Steam, gamescope-session, MangoHud, GameMode, Lutris, Heroic, Wine e a variante NVIDIA.
- **Bloqueio:** benchmarks e FPS só em hardware real; o lab só valida instalação e abertura.
- **Aceite:** 3 jogos definidos por você (1 nativo, 2 Proton, sem anticheat) instalam, abrem e são jogáveis 10 min sem crash; métricas Kinoite × Luma registradas.

### Fase 5: Segurança e desempenho · M
- **Objetivo:** controles da §7 com evidência; perfis de energia; medição de boot e RAM.
- **Aceite:** todos os controles da §7 com teste PASSOU; consumo da bateria medido (W em idle, via `upower`) contra o Kinoite puro.

### Fase 6: Instalador e atualizações · M
- **Objetivo:** branding do Anaconda, canal de updates assinado, recuperação documentada (rollback + ISO), dual boot testado **em disco virtual**.
- **Aceite:** update assinado aplicado; adulterado recusado; rollback; guia do usuário testado passo a passo.

### Fase 7: Lume SDK · XG (projeto separado)
- **Pré-requisito:** o lumec existir e compilar programas reais no seu próprio repo.
- **Integração:** SDK entregue por toolbox/Flatpak ou RPM opcional, **nunca** na imagem base e nunca em app crítico (Settings, Update) até o runtime ter versão estável e testes.
- **Aceite:** "hello world" Lume com UI Qt rodando no Luma; sem regressão na imagem.

### Fase 8: Testes e lançamento · G
- Matriz completa (§11) em VM e em **no mínimo 1 máquina real**; release notes; publicação **só com autorização**.

---

## 10. Matriz de riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| F44 perto do fim de vida; F45 iminente [F] | Alta | Médio | Versão parametrizada; rebase para o 45 antes da alpha |
| Escopo maior que a capacidade (1 pessoa) | Alta | Alto | MVP = Fases 0–2 + 5–6; Fases 3, 4 e 7 incrementais |
| Host de 7,7 GiB trava builds | Alta | Médio | Builds no CI ([D] autorização) |
| Sem hardware de teste dedicado (só o notebook com Windows) | Alta | Alto | Live/instalação em SSD externo ou máquina descartável; **nunca** particionar o disco do host sem autorização |
| NVIDIA + SB + Wayland em notebook híbrido | Média | Alto | Variante separada; inscrição de MOK documentada; testar na RTX 3050 |
| Mudanças de ferramenta (bootc-image-builder → image-builder) [F] | Média | Médio | Fixar versão do container da ferramenta; teste de ISO em CI |
| Ativos com direito de terceiros (Apple, marcas, álbum) [F] | Alta se copiar | Alto (jurídico) | Só arte original ou com licença; checklist de licenças no CI |
| Marca Fedora [H] | Média | Médio | Remover logos e nome; ADR 0010 |
| Steam e codecs: redistribuição e patentes [D] | Média | Médio | ADR jurídica; alternativa Flatpak |
| Dependência do Universal Blue (akmods) | Média | Médio | Fixar por digest; plano de saída documentado |
| CI comprometido = imagem maliciosa | Baixa | Crítico | Proteções da §7 |
| Lume atrasar o sistema | Alta | Médio | Fora do caminho crítico |
| Regressão de firewall (zona Fedora mais permissiva) [H] | Média | Alto | Zona `luma` + teste nmap na Fase 1 |

---

## 11. Plano de testes e indicadores

**Camadas:** unit (CI) → imagem (CI) → VM com OVMF+SB e QMP (lab) → hardware real (manual, com roteiro).
**Indicadores** (todos **relativos ao Kinoite 44 puro**, mesmo ambiente, 3 medições, mediana; nenhuma meta absoluta inventada):
| Indicador | Medida | Meta inicial |
|---|---|---|
| Boot até o desktop | `systemd-analyze` + tempo até o plasmashell pronto | ≤ base +10% |
| RAM ociosa | `free` 60 s após o login | ≤ base +15% |
| Tamanho | imagem OCI, ISO, download de update | registrar; alerta se +20% entre versões |
| Estabilidade | `coredumpctl` vazio em 8 h de sessão e roteiro de uso | 0 crashes de plasmashell/kwin |
| SELinux | AVCs após os roteiros | 0 não explicados |
| Visual | contraste AA; diff de screenshot | 100% AA; diff ≤ limiar aprovado |
| Gaming | FPS médio e 1% low (MangoHud), hardware real | ≥ 95% do Kinoite+mesmos drivers [H] |
| Bateria | W em idle (`upower`) | ≤ base +5% [H] |

---

## 12. Decisões pendentes (bloqueiam a Fase 0/1)
1. **[D] CI/registro:** autoriza GitHub Actions + GHCR (publicação pública de imagem) para builds e updates?
2. **[D] Flathub pré-configurado?** (recomendado: sim)
3. **[D] NVIDIA:** akmods do ublue (recomendado) ou pipeline própria?
4. **[D] Steam e codecs:** na imagem (RPM Fusion) ou Flatpak/opt-in?
5. **[D] Hardware de teste:** há um SSD externo ou máquina descartável? Instalar no notebook principal continua proibido sem autorização específica.
6. **[D] Nome e marca:** "Luma-OS Midnight Edition" e logotipo próprio (o do mockup é da Apple).
7. **[D] Repositórios:** o `Luma` vira o repo principal e o `LUMA-OS` fica arquivado? Corrigir o "privado" no STATUS dele?

---

## 13. Primeiro conjunto de tarefas (Fase 0, após aprovação)
1. Criar a estrutura da §8 no branch `claude/eager-franklin-mb8qmf` com README, CLAUDE.md (regras do projeto antigo atualizadas), `docs/STATUS.md` e `docs/TESTS.md`.
2. Escrever as ADRs 0008 (Fedora 44 Kinoite/bootc, substitui a 0001/0005/0006), 0009 (build, CI e assinatura) e 0010 (marca e licenças de ativos).
3. Portar do LUMA-OS@44903f2: `theme/*` → `themes/`, `plasma/`, `wallpapers/`; `apps/ajustes` → `apps/settings`; `windows/` → `gaming/wine/`; com os testes `test_theme.py` e `test_core.py` passando.
4. Corrigir as referências específicas do Debian (`firefox-esr`, caminhos `/usr/lib/*/libexec`), marcando como [H] o que só a VM confirma.
5. `Containerfile` mínimo (`FROM fedora-kinoite:44` fixado por digest + os-release Luma + firewalld `luma`) e workflow de CI que **só constrói e testa**, sem push.
6. Lint no CI: shellcheck, ruff, qmllint, varredura de segredos e checklist de licenças.
7. Roteiro do laboratório para WSL2 Fedora (adaptar `scripts/lab/lab.sh`: ISO Kinoite oficial, OVMF+SB, QMP).
8. Commit e push no branch designado; **sem PR** até você pedir.

## Verificação do plano (fim da Fase 0)
- `scripts/ci/lint.sh` e os unit tests verdes no CI do repo `Luma`.
- `podman build` do Containerfile mínimo concluído no CI; `podman run luma cat /usr/lib/os-release` mostra Luma.
- VM do lab inicia a Kinoite 44 oficial com Secure Boot (screenshot QMP registrado em `docs/evidence/fase0/`).

Fontes externas consultadas: Help Net Security (F44 lançado em 28/04/2026, Plasma 6.6); Fedora Magazine e o blog de siosm (Atomic Desktops 44: Plasma Login Manager, Plasma Setup); Phoronix (F45: no-go em 20/10, contingência 27/10 ou 03/11); osbuild/bootc-image-builder e greenboot-rs#213 (arquivamento e migração para image-builder `bootc-generic-iso`); fórum Universal Blue (MOK/akmods).
