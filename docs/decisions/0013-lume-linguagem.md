# 0013: linguagem Lume e compilador lumec 0.1

Status: **aceita pelo usuário** em 2026-10-29 (Fase 7).

## Contexto
A Fase 7 dependia de um compilador `lumec` que não existia. O usuário pediu para começar a linguagem.

## Decisão (escolhas do usuário)
- **Alvo:** o `lumec` traduz Lume para Python. As interfaces usam PySide6 (Qt 6), que o Luma já traz desde a Fase 3. O próprio `lumec` é escrito em Python, sem dependências.
- **Palavras-chave em inglês** (`let`, `fn`, `if`, `while`...). As mensagens de erro e a documentação ficam em português.
- **Local:** pasta `lume/` neste repositório, por enquanto. Migra para um repositório próprio quando estabilizar.
- **Fora da imagem base:** regra do plano para a Fase 7. O Lume roda a partir do repositório até ser empacotado.

## Consequências
- Desempenho igual ao do Python. Recursos que o Python não tem (tipos estáticos, binário nativo) ficam fora do 0.1.
- O escopo de variável segue o do Python (por função), para o código gerado ser direto e legível.
- A camada `ui` é deliberadamente pequena. Componentes mais ricos (listas, layouts, estilos Luma) vêm em versões seguintes, com testes sem tela no CI da imagem.
