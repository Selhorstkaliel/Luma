# Lume 0.1

Linguagem de programação do Projeto Luma (Fase 7, decisão 0013). O compilador `lumec` traduz Lume para Python. As janelas usam o PySide6 (Qt 6), que já vem no Luma.

```lume
let count = 0
let w = ui.window("Contador Lume")
let display = w.label("Cliques: 0")

fn on_click() {
    count = count + 1
    display.set_text("Cliques: " + str(count))
}

w.button("Clique aqui", on_click)
w.show()
ui.run()
```

## Usar
```sh
python3 lume/bin/lumec run lume/examples/ola.lume         # compila e executa
python3 lume/bin/lumec check programa.lume                # só verifica (erros com linha:coluna)
python3 lume/bin/lumec build programa.lume -o programa.py # gera o Python
```
Programas sem `ui` rodam em qualquer Python 3.11+. Com `ui`, é preciso o PySide6; no Luma e no Fedora, o pacote é `python3-pyside6`.

## Estado
- **Pré-alpha.** A linguagem pode mudar sem aviso. A especificação está em [docs/spec-0.1.md](docs/spec-0.1.md).
- Não entra na imagem do sistema (plano, Fase 7). Empacotamento (toolbox, Flatpak ou RPM opcional) fica para depois.
- Testes: `lume/tests/` (lexer, parser, verificador, semântica e interface sem tela), rodados por `scripts/ci/unit.sh`.

## Arquitetura
`lumec/lexer.py` → `parser.py` (AST em `nodes.py`) → `check.py` (escopos) → `codegen.py` (Python + mapa de linhas) → `cli.py`.

O runtime fica em `lume_runtime/`: `core.py` cuida do texto dos valores, do `print` e do `range`, e `ui.py` é a camada fina sobre PySide6.QtWidgets.
