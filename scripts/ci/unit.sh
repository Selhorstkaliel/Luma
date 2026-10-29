#!/usr/bin/env bash
# Roda todos os testes unitários (sem sessão gráfica): tests/unit/test_*.py e lume/tests/test_*.py
# (os testes de interface do Lume são pulados quando o PySide6 não está instalado)
set -euo pipefail
cd "$(dirname "$0")/../.."
rc=0
for t in tests/unit/test_*.py lume/tests/test_*.py; do
	echo "== $t"
	python3 -B "$t" || rc=1
done
exit $rc
