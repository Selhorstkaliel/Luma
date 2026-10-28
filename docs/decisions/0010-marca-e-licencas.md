# 0010: Marca, identidade visual e licenças de ativos

Status: aceita para o que está abaixo. **O nome definitivo e o logotipo dependem do usuário.**

## Contexto
A referência visual Midnight (mockup enviado em 2026-10-28) mostra o **logotipo da Apple** na barra superior, o tema "WhiteSur" no fastfetch, os logotipos de YouTube, Netflix, Spotify, Amazon, Discord, GitHub e Gmail, e a capa e o nome de um álbum ("After Dark", Mr.Kitty). Os wallpapers são de origem e licença desconhecidas. O LUMA-OS já tinha decidido reproduzir o estilo dos mockups sem copiar ativos de terceiros (`docs/design/luma-visual-spec-debian-0.6.md`).

## Decisão
- O mockup é **referência de estilo**, não fonte de ativos. Nada dele entra no repositório: logotipos, ícones de marcas, capas de álbum ou wallpapers.
- A distribuição não usa o nome nem o logotipo do Fedora como marca própria. `os-release` diz "base Fedora". A troca de `fedora-logos` por logos próprios ou genéricos fica para a Fase 1, depois de conferir as diretrizes de marca do Fedora [H].
- Ícones vêm de conjuntos licenciados (Papirus, GPL-3.0) ou são próprios. Wallpapers são arte original (CC-BY-SA-4.0) ou têm licença comprovada e registrada.
- `LICENSES.toml` mapeia todo arquivo versionado para uma licença e uma origem. `tests/unit/test_licenses.py` falha se um arquivo ficar sem regra ou se um ativo visual tiver nome ou texto de marca de terceiros da lista.

## Pendências do usuário
- Nome final ("Luma-OS Midnight Edition"?) e um logotipo próprio (o atual, `icons/luma-logo.svg`, veio do LUMA-OS).
- Se usará arte gerada por IA nos wallpapers: registrar a ferramenta e os termos de uso dela antes de incluir.
