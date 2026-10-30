#!/usr/bin/env bash
# Medição de RAM e boot de um sistema instalado (F5-03), para comparar o Luma com a Kinoite pura.
# Executar como root:
#   vm-medicao.sh NOME IMAGEM_CARGA IMAGEM_INSTALADOR DIR_EVIDENCIAS
# Mesmo caminho do teste do sistema instalado (scripts/ci/vm-test.sh): ISO de teste com o kickstart do CI,
# instalação sem interação em QEMU + OVMF com Secure Boot, disco preparado pelo host (prepare-disk.sh, agora
# com MODO=medicao). O roteiro tests/vm/guest/luma-ci-medicao.sh mede em 3 boots e desliga; aqui só se lê
# a serial e se grava DIR_EVIDENCIAS/medicao-NOME.txt (linhas MED e MEDPROC). A comparação é do
# scripts/ci/medicao-compara.py. A ISO de teste é destrutiva e é apagada após a instalação.
set -euo pipefail
nome="${1:?uso: vm-medicao.sh NOME IMAGEM_CARGA IMAGEM_INSTALADOR DIR_EVIDENCIAS}"
payload="${2:?}"; installer="${3:?}"; ev="$(realpath -m "${4:?}")"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LAB="$ROOT/scripts/lab/lab.sh"
[ "$(id -u)" = 0 ] || { echo "vm-medicao.sh: execute como root" >&2; exit 77; }
[ -e /dev/kvm ] || { echo "vm-medicao.sh: /dev/kvm ausente, medição NÃO EXECUTADA" >&2; exit 1; }
mkdir -p "$ev"
work="${WORK_DIR:-/var/tmp/luma-medicao}/$nome"
rm -rf "$work"; mkdir -p "$work/iso"
# Mesma VM para as duas imagens: 6 GiB, 4 CPUs, Secure Boot, rede user (sem tap, sem nmap)
export LAB_DIR="$work/lab" VM_NAME="med-$nome" VM_NET=1 VM_AUDIO=0 VM_RAM_MB=6144 VM_CPUS=4
log() { printf '[vm-medicao %s] %s\n' "$nome" "$*" | tee -a "$ev/vm-medicao.log" >&2; }
serial="$LAB_DIR/vms/$VM_NAME/serial.log"
trap '"$LAB" kill >/dev/null 2>&1 || true' EXIT
espaco() { log "disco: $(df -h --output=avail,target "$work" | tail -n1 | tr -s ' ')"; }
# Tela com OCR no log (sem tesseract, só a captura): diagnóstico quando a instalação ou a medição travam
tela() {
	"$LAB" screenshot "$ev/tela-$nome-$1.png" >/dev/null 2>&1 || return 0
	command -v tesseract >/dev/null || return 0
	tesseract "$ev/tela-$nome-$1.png" - -l eng 2>/dev/null | tr '\n' ' ' | cut -c1-300 | sed "s/^/[vm-medicao $nome] tela $1 (OCR): /" | tee -a "$ev/vm-medicao.log" >&2 || true
}
# Espera o QEMU terminar (o sistema desliga sozinho) com prazo; tela a cada 10 min
wait_qemu() {
	local pid="$1" limit="$2" t=0
	while kill -0 "$pid" 2>/dev/null; do
		sleep 10; t=$((t + 10))
		[ $((t % 600)) = 0 ] && { tela "${t}s"; espaco; }
		[ "$t" -ge "$limit" ] && { log "prazo de ${limit}s esgotado"; tela prazo; espaco; return 1; }
	done
	wait "$pid" 2>/dev/null || true
}

espaco
"$ROOT/tests/vm/ks-ci.sh" "$work/ks-ci.toml" >/dev/null
CONFIG="$work/ks-ci.toml" "$ROOT/build/iso/build-iso.sh" "$payload" "$installer" "$work/iso" "med-$nome" >"$ev/iso-$nome.log" 2>&1 \
	|| { tail -n 40 "$ev/iso-$nome.log" >&2; log "ISO de teste não foi gerada"; exit 1; }
"$LAB" check >/dev/null
"$LAB" create >/dev/null
BOOT_ISO="$work/iso/luma-med-$nome-x86_64.iso" "$LAB" run & pid=$!
log "instalação iniciada"
wait_qemu "$pid" 3000 || exit 1
rm -f "$work/iso/"*.iso
espaco
MODO=medicao "$ROOT/tests/vm/prepare-disk.sh" "$LAB_DIR/vms/$VM_NAME/disk.qcow2" 2>&1 | grep -E 'roteiro|hostname|ERRO' | tee -a "$ev/vm-medicao.log"
: >"$serial"
"$LAB" run & pid=$!
log "medição iniciada (3 boots)"
wait_qemu "$pid" 2400 || true
tr -d '\r' <"$serial" | grep -a '^LUMACI ' | sed 's/^LUMACI //' >"$ev/medicao-$nome.txt" || true
log "linhas de medição: $(grep -c '^MED ' "$ev/medicao-$nome.txt" || true)"
grep -E '^(BEGIN|MED |END)' "$ev/medicao-$nome.txt" | tee -a "$ev/vm-medicao.log" >&2 || true
rm -rf "$work/lab"
grep -q '^END medicao' "$ev/medicao-$nome.txt" || { log "a medição não chegou ao fim"; exit 1; }
