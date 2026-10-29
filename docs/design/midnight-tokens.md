# Tokens Midnight (medidos)

Medição de 2026-10-29 sobre o mockup Midnight enviado pelo usuário (1536×1024, colagem de 12 telas). O mockup é só referência de estilo (decisão 0010): nenhum pixel, ícone, logotipo ou foto dele entra no repositório. Só os valores de cor abaixo, que não são ativos.

Método: mediana de cada canal RGB numa caixa de pixels de cada região (script descartável, não versionado). Os valores são **aproximados**: o mockup é uma imagem comprimida (WebP), e texto e ícones dentro das caixas puxam a mediana.

| Região do mockup | Medido | Uso no esquema `LumaDark` (Luma Midnight) |
|---|---|---|
| Barra superior | `#080D19` (8,13,25) | Header, área complementar |
| Corpo da janela de arquivos | `#090F16` (9,15,22) | View (fundo de listas e campos) |
| Lateral da janela de arquivos | `#0E141B` (14,20,27) | Window, título ativo da decoração |
| Corpo do painel Desempenho | `#131821` (19,24,33) | Window alternado, título inativo |
| Item de lista em destaque | `#1F2A3E` (31,42,62) | Seleção alternada |
| Item selecionado (Desempenho) | `#324B7B` (50,75,123) | Seleção (texto branco 8,6:1) |
| Bloco desligado da Central de Controle | `#1E2533` (30,37,51) | Botão, dica, borda da decoração |
| Campo de busca do lançador | `#252A3C` (37,42,60) | Botão alternado |
| Bloco Wi-Fi ligado (acento) | `#2777FB` (39,119,251) | Já é o `AccentColor` dos pacotes (42,126,253) |
| Barra de memória | `#3F8EF7` (63,142,247) | Foco e hover |
| Barra de armazenamento (secundária) | `#D145A3` (209,69,163) | Clareada para `#F080C8` em links visitados (AA) |

Ajustes de contraste (WCAG AA, conferidos por `tests/unit/test_theme.py`):
- A seleção não usa o acento puro: branco sobre `#2777FB` dá 4,1:1, abaixo de 4,5:1.
- O magenta do mockup cai abaixo de 4,5:1 sobre os botões; nos links visitados, usamos a versão clara.

Pendente [H]: o Plasma pode pintar a seleção com o `AccentColor` (42,126,253) em vez do `Selection` do esquema. Nesse caso o texto selecionado fica com cerca de 4:1. Conferir na VM.
