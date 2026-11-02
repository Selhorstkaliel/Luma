# 0014: drivers e periféricos: detectar e perguntar

Status: **aceita pelo usuário** em 2026-11-02 ("vamos trabalhar sobre a questão dos drivers para a busca automática, tanto da placa de vídeo quanto dos periféricos").

## Contexto
O Luma é imutável (bootc/ostree). Não dá para instalar drivers como num sistema comum: o que entra no sistema vem na imagem, e o usuário só acrescenta apps (Flatpak) e ajustes. A decisão 0012 proíbe pacotes do RPM Fusion e deixou o driver proprietário da NVIDIA para quando houver hardware de teste, que o usuário não tem.

## Decisão
- **Detectar e perguntar.** O `luma-drivers` lê o hardware (sysfs e ferramentas da imagem), mostra o que está funcionando, o que falta e o que não tem suporte. Ele **nunca** muda nada sozinho: cada ação é uma lista fixa de comandos e só roda com a confirmação do usuário.
- **Vídeo:**
  - Intel, AMD e VMs: driver livre do kernel e Mesa (nada a buscar);
  - **NVIDIA: só detectar e explicar.** O driver livre (nouveau com NVK) está em uso, e o proprietário não faz parte do Luma (0012 continua valendo);
  - notebooks híbridos: orientação para usar a placa dedicada (switcheroo-control).
- **Periféricos (primeira versão):**
  - **impressoras e scanners**: sem driver, por IPP Everywhere, IPP-over-USB e eSCL (CUPS, ipp-usb, sane-airscan);
  - **controles de jogo**: reconhecidos pelo kernel, com as regras do steam-devices e a Steam via `luma-jogos`;
  - **Wi-Fi, Bluetooth e firmware**: avisa quando falta driver ou firmware, e oferece atualizar firmware pelo fwupd/LVFS;
  - **leitor de digital**: fprintd, com cadastro nas Configurações;
  - **mouse e teclado gamer**: Solaar para a Logitech, Piper (Flathub, escopo do usuário) para o libratbag.
- **Fontes permitidas:** pacotes do Fedora na imagem, o Flathub no escopo do usuário (como na 0012) e o fwupd/LVFS. Nada de `rpm-ostree install`, `dnf`, `sudo` ou repositórios de terceiros nas ações (teste unitário `Seguranca`).
- **Driver ou firmware que falta na imagem** só chega com uma atualização do Luma (`bootc upgrade`). O assistente diz isso em vez de prometer instalar.

## Consequências
- Hardware que precisa de driver proprietário (NVIDIA proprietário, Wi-Fi Broadcom `wl`, alguns leitores de digital e scanners) continua sem suporte. O assistente diz isso claramente.
- **Sem hardware de teste**, a detecção é validada com um sysfs simulado (testes unitários), na imagem (F3-I07, F3-I08) e na VM do CI (F3-05). Placas reais, impressoras, controles e leitores **não** foram testados [H]. As regras de detecção (vendedores USB, classes PCI) podem errar em modelos específicos.
- Próximo incremento: uma página no app Ajustes e um aviso no primeiro login (só quando houver item "falta"), usando o mesmo `luma-drivers --json`.
