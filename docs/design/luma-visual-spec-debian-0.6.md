> Histórico do LUMA-OS (Debian, versão 0.6.1), copiado de LUMA-OS@44903f2. As imagens de referência citadas continuam lá e não foram copiadas. A especificação Midnight da edição Fedora será escrita na Fase 2.

# Luma — especificação visual

Referências aprovadas pelo usuário (direitos do usuário): `references/luma-claro.png`, `references/luma-escuro.png` (2026-09-30). Esta especificação traduz os mockups para componentes do Plasma 6.3. Cores medidas nas imagens (média 5×5 px em pontos de interface).

## Limite de reprodução
Layout, cores, transparência, cantos, barra superior, dock, central de controle, lançador e tela de Ajustes seguem os mockups. **Ícones de terceiros vistos no mockup claro (estilo Finder, Safari, Fotos, Mail, Notas, Calendário) não são copiados**: são substituídos por ícones licenciados (Papirus, GPL-3.0) com o mesmo caráter (arredondados, coloridos). Wallpapers são arte original no mesmo estilo.

## Tokens
| Token | Claro | Escuro | Origem |
|---|---|---|---|
| Acento | `#2A7EFD` | `#2A7EFD` | slider/toggle/seleção dos mockups |
| Barra superior | translúcida clara (`#C6DBFD` sobre wallpaper) | `#041A39` translúcida | medido |
| Título de janela | `#E1E9F7` | `#131A36` | medido |
| Barra lateral | `#D8E1F5` | `#202840` | medido |
| Seleção na lateral | `#CBDDFD` | `#1E3E80` | medido |
| Cartões/campos | `#EEF1F8` | `#141A28` / `#222938` | medido |
| Dock | `#ECF1FA` translúcido | `#0F2245` translúcido | medido |
| Botões de janela | `#FD4D56` `#FECB18` `#2CD656` | iguais | medido |

Contraste de texto ≥ 4,5:1 continua obrigatório (`theme/tests/test_theme.py`); quando uma cor medida não atinge, ajusta-se o mínimo necessário e registra-se aqui.

## Componentes
1. **Janelas** — decoração Aurorae "Luma" (motor incluído em `kwin-common`): três botões circulares à esquerda (fechar, minimizar, maximizar), título à esquerda em negrito, cantos superiores arredondados.
2. **Barra superior** (≈ 32 px, largura total, translúcida): logotipo Luma (abre o lançador), menu global do app ativo, bandeja e relógio à direita.
3. **Dock** flutuante centralizado, cantos grandes, ícones ≈ 56 px, separador e lixeira à direita.
4. **Lançador**: grade de apps com campo "Buscar aplicativos".
5. **Central de Controle** (plasmoide próprio): blocos Wi‑Fi, Bluetooth, Não Perturbe, Espelhamento de Tela; sliders de brilho e volume. Só usa NetworkManager, BlueZ, notificações, PowerDevil e PipeWire existentes.
6. **Ajustes → Aparência**: cartões Claro/Escuro, cor de destaque, transparência, animações, tamanho do texto.
7. **Fonte** Inter (OFL-1.1). **Ícones** Papirus (claro) / Papirus-Dark (escuro).
8. **Wallpaper** "Luma Ondas": ondas fluidas lilás/azul (claro) e azul profundo/violeta (escuro).

## Fora do MVP visual
Cantos inferiores arredondados de janelas (KWin 6.3 não arredonda a janela inteira sem efeito de terceiros) e blur sob o conteúdo das janelas.
