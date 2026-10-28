#!/usr/bin/env bash
# Roda todos os testes unitários (sem sessão gráfica, sem Qt): tests/unit/test_*.py
set -euo pipefail
cd "$(dirname "$0")/../.."
rc=0
for t in tests/unit/test_*.py; do
	echo "== $t"
	python3 -B "$t" || rc=1
done
exit $rc
