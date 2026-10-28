# 0008: Base Fedora Kinoite com imagem bootc

Status: **aceita pelo usuário** (plano mestre aprovado em 2026-10-28). Substitui no LUMA-OS a 0001 (base Debian), a 0005 (ISO live-build) e a 0006 (Calamares).

## Contexto
O LUMA-OS 0.8.0 (Debian 13 + Plasma 6.3, `Selhorstkaliel/LUMA-OS@44903f2`) foi validado em VM até a etapa 9. O usuário definiu o Fedora 44 como base única e escolheu o modelo Atomic.

## Fatos verificados (2026-10-28)
- O Fedora 44 foi lançado em 28/04/2026, com KDE Plasma 6.6. Os sabores KDE passaram a usar o **Plasma Login Manager** (no lugar do SDDM) e o **Plasma Setup** no primeiro boot.
- O Fedora 45 está em fase final: o lançamento previsto para 20/10/2026 foi adiado, com contingências em 27/10 e 03/11.
- O `bootc-image-builder` foi arquivado e incorporado ao `image-builder`. O tipo `anaconda-iso` deu lugar a `bootc-installer`/`bootc-generic-iso`.

## Decisão
- A imagem é OCI/bootc, derivada de `quay.io/fedora/fedora-kinoite:${FEDORA_VERSION}`, com `FEDORA_VERSION=44` parametrizado no `Containerfile`.
- Não há fork de KWin nem de Plasma. Os componentes próprios usam APIs existentes do KDE.
- O instalador é o Anaconda, gerado pelo image-builder (Fase 1). O Calamares não instala sistemas bootc/ostree.
- O firewall usa firewalld com a zona `luma` como padrão (entrada fechada, saída liberada). Isso equivale ao `luma-firewall`/ufw do LUMA-OS (controle E7-01).
- O SELinux fica em enforcing, a política padrão do Fedora.
- `os-release` usa `ID=luma` e `ID_LIKE="fedora"`, preservando os campos de versão da base.

## Consequências
- `debian/`, `live/`, Calamares, `luma-live` e preseed não foram portados. Continuam no LUMA-OS como histórico.
- Ativos agnósticos de distribuição foram portados do commit 44903f2. Os testes unitários deles passam aqui (16 de tema e 11 do app de ajustes).
- Atualização e rollback passam a ser atômicos (`bootc upgrade`/`rollback`), em vez de `apt` mais recuperação por chroot.
- O F44 deve sair de suporte cerca de 4 semanas após o lançamento do F46 [H]. O rebase para o 45 é a troca da tag com nova rodada de validação, e deve ser feito antes da alpha.

## Hipóteses a validar (não tratar como fato)
- Se `ID=luma` quebra alguma ferramenta que exige `ID=fedora` (toolbox, Discover, bootc). Validar na VM na Fase 1.
- Os nomes exatos e as opções do image-builder para gerar a ISO (Fase 1).
- A precedência de `/etc/xdg` sobre os padrões do pacote `kde-settings` (Fase 2).
- Se a zona padrão do Fedora KDE abre portas altas de entrada. A zona `luma` torna isso irrelevante, mas o teste com `nmap` (Fase 1) é o que comprova.
