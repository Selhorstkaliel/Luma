# Especificação do Lume 0.1

## Léxico
- **Comentários:** `#` até o fim da linha.
- **Instruções:** terminam na quebra de linha. Dentro de `( )` e `[ ]`, a quebra de linha é ignorada.
- **Números:** inteiros (`42`) e decimais (`3.5`).
- **Textos:** `"..."`, com os escapes `\n`, `\t`, `\"` e `\\`. Não podem ocupar mais de uma linha.
- **Palavras reservadas:** `let fn return if else while for in true false nil and or not`.

## Valores
Números, textos, `true`, `false`, `nil`, listas `[a, b, c]` e funções.

`print` mostra `true`, `false` e `nil` com esses nomes.

## Instruções
| Forma | Significado |
|---|---|
| `let nome = expr` | declara uma variável |
| `nome = expr`, `xs[i] = expr`, `obj.campo = expr` | atribuição; o nome precisa ter sido declarado |
| `fn nome(a, b) { ... }` | declara uma função (valor de primeira classe) |
| `return [expr]` | só dentro de função |
| `if c { } else if d { } else { }` | condicional |
| `while c { }` | laço |
| `for x in lista { }` | percorre a lista; declara `x` se ele não existir |

## Escopo (0.1)
- **Por função, como em Python.** Um `let` dentro de `if` ou `while` vale para a função inteira. Redeclarar o mesmo nome na mesma função é erro.
- **Funções aninhadas** enxergam e podem alterar variáveis das funções externas (closures).
- **Funções de nível superior** podem ser chamadas por outras funções antes da definição.

## Expressões e precedência (da menor para a maior)
`or` · `and` · `not` · `== != < <= > >=` (sem encadear) · `+ -` · `* / %` · `-` unário · chamada `f(x)`, índice `xs[i]`, atributo `obj.nome`.

`/` sempre divide com decimais (`7 / 2` = `3.5`).

## Embutidos
- `print(...)` imprime os valores separados por espaço.
- `str(v)` converte o valor em texto no formato do Lume.
- `len`, `int` e `float`.
- `range(a, b)` devolve uma lista.
- Métodos de listas e de textos vêm do Python, por exemplo `xs.append(v)` e `s.upper()` [limitação conhecida do 0.1].

## Módulo `ui`
| Chamada | Efeito |
|---|---|
| `ui.window(titulo)` | cria uma janela com os elementos em coluna |
| `w.label(texto)` | cria um rótulo; `l.set_text(v)` muda o texto |
| `w.button(texto, funcao)` | cria um botão que chama `funcao()` no clique |
| `w.input(dica)` | cria um campo; `campo.text()` lê o que foi digitado |
| `w.show()` | mostra a janela |
| `ui.run()` | entra no laço da interface até a última janela fechar |

## Erros
- **De compilação:** `arquivo:linha:coluna: erro: mensagem`.
- **De execução:** `arquivo:linha: erro de execução: Tipo: mensagem`. A linha é a do `.lume`.
