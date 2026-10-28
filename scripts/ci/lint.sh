#!/usr/bin/env bash
# Verificações rápidas (as mesmas no CI e na máquina do desenvolvedor):
# sintaxe e ShellCheck dos scripts shell, ruff nos Python, varredura de segredos e qmllint quando disponível.
set -euo pipefail
cd "$(dirname "$0")/../.."
rc=0

# Scripts shell: *.sh e executáveis sem extensão listados explicitamente
mapfile -t sh_files < <(git ls-files -co --exclude-standard -- '*.sh' 'themes/bin/*' 'apps/settings/data/luma-ajustes' 'gaming/wine/luma-windows-run')
for f in "${sh_files[@]}"; do bash -n "$f" || { echo "sintaxe: $f"; rc=1; }; done
if command -v shellcheck >/dev/null; then
	shellcheck -x "${sh_files[@]}" || rc=1
else
	echo "AVISO: shellcheck ausente; ShellCheck não executado"; [ -z "${CI:-}" ] || rc=1
fi

# Python: ruff (regras em pyproject.toml); sem ruff, ao menos a sintaxe
mapfile -t py_files < <(git ls-files -co --exclude-standard -- '*.py')
if command -v ruff >/dev/null; then
	ruff check "${py_files[@]}" || rc=1
else
	echo "AVISO: ruff ausente; só sintaxe Python"; [ -z "${CI:-}" ] || rc=1
	python3 -B -c "import ast,sys; [ast.parse(open(f,encoding='utf-8').read(), f) for f in sys.argv[1:]]" "${py_files[@]}" || rc=1
fi

# QML: qmllint só existe com Qt 6 instalado; no CI de imagem roda dentro do container Fedora (Fase 2)
mapfile -t qml_files < <(git ls-files -co --exclude-standard -- '*.qml')
qmllint_bin="$(command -v qmllint6 || command -v qmllint || true)"
if [ -n "$qmllint_bin" ]; then
	"$qmllint_bin" "${qml_files[@]}" || rc=1
else
	echo "AVISO: qmllint ausente; ${#qml_files[@]} arquivos QML não verificados"
fi

# Segredos: chaves privadas e hashes de senha crypt nunca entram no repositório
# shellcheck disable=SC2016  # \$ literal no padrão de hash crypt
if git ls-files -co --exclude-standard -z | xargs -0 grep -IlE 'BEGIN (OPENSSH|RSA|EC|PGP) PRIVATE KEY|\$6\$[./A-Za-z0-9]{8,}|\$y\$j9T\$[./A-Za-z0-9]{8,}' 2>/dev/null; then
	echo "possível segredo no repositório"; rc=1
fi

[ $rc -eq 0 ] && echo "lint OK (${#sh_files[@]} scripts shell, ${#py_files[@]} Python)"
exit $rc
