# Luma-OS: instruções do repositório

- Plano e fases: [docs/PLANO-MESTRE.md](docs/PLANO-MESTRE.md). Estado e próximo passo: [docs/STATUS.md](docs/STATUS.md). Testes: [docs/TESTS.md](docs/TESTS.md). Decisões: [docs/decisions/](docs/decisions/).
- Base única: Fedora Kinoite via bootc (decisão 0008). Não misturar pacotes, gerenciadores ou componentes de Debian, Ubuntu ou Arch.
- Uma tarefa por vez. Nada é APROVADO sem evidência registrada em docs/TESTS.md. Separar fato verificado [F], hipótese [H] e decisão pendente [D].
- Nunca particionar discos físicos, alterar o bootloader ou o Secure Boot do host, publicar imagens ou ISOs, fazer push em registro ou commitar segredos sem autorização específica.
- Nenhum ativo de terceiros: o mockup é referência de estilo (decisão 0010). Todo arquivo novo precisa casar com uma regra de `LICENSES.toml`.
- Host do usuário: Windows 11 com 7,7 GiB de RAM. Boot, desktop e instalação só são validados em VM UEFI com Secure Boot (`scripts/lab/lab.sh`) ou em hardware autorizado.
- Antes de commitar: `scripts/ci/lint.sh && scripts/ci/unit.sh`.
