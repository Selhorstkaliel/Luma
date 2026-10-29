# 0012: jogos por Flatpak opt-in; NVIDIA adiada

Status: **aceita pelo usuário** em 2026-10-29 (Fase 4). Responde às decisões pendentes 2, 3 e 4 do plano (§12).

## Contexto
A Fase 4 pede Steam, Lutris, Heroic, Wine e codecs. O plano listava duas formas de entregar isso. A primeira era incluir na imagem pelo RPM Fusion (modelo do Bazzite). A segunda era deixar opcional, por Flatpak. Também faltava decidir o driver NVIDIA, que a VM do laboratório não tem como testar.

## Decisão
- **Nada do RPM Fusion na imagem.** Ela continua só com pacotes do Fedora. Entram as ferramentas do próprio Fedora: GameMode, MangoHud, gamescope e `steam-devices` (regras de controles), este quando existir no repositório.
- **Steam, Lutris, Heroic e Bottles via Flathub, sob demanda e sem root:** `luma-jogos instalar` ou o atalho "Jogos". O remoto Flathub é adicionado só no escopo do usuário (`--user`). Os codecs chegam pelos runtimes Flatpak desses apps.
- **Flathub pré-configurado (decisão pendente 2): sim, mas no primeiro uso do `luma-jogos`, por usuário.** Não fica habilitado para o sistema todo.
- **NVIDIA (decisão pendente 3): adiada.** A Fase 4 cobre só Mesa (Intel/AMD/VM). A variante NVIDIA vira um incremento próprio quando houver hardware de teste autorizado (decisão pendente 5), porque exige MOK e Secure Boot e só pode ser validada na máquina real.

## Consequências
- Menor risco jurídico: a ISO pública não redistribui código com patente nem o cliente Steam.
- Quem quer jogar precisa de um passo e de internet depois da instalação. O Steam em Flatpak tem limitações conhecidas de sandbox, como pastas fora de `~` e alguns controles. [H] Avaliar na Fase 4 com hardware real.
- Notebooks com NVIDIA, como o do usuário, ficam no driver livre (nouveau) até a variante existir. Desempenho de jogo nesses equipamentos não é critério da Fase 4 por enquanto.
- O `luma-windows-run` (Wine do sistema) não entra neste incremento. Para programas do Windows, a recomendação passa a ser o Bottles (Flatpak).
