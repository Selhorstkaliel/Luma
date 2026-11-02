#!/usr/bin/env bash
# Medição de RAM e boot do Windows 11 (Enterprise Evaluation, gratuito por 90 dias, só para avaliação) na MESMA VM
# da medição do Luma (scripts/ci/vm-medicao.sh): 6 GiB, 4 CPUs, OVMF com Secure Boot e chaves da Microsoft, TPM 2.0
# virtual (swtpm), sem 3D. Executar como root:
#   vm-windows.sh DIR_EVIDENCIAS
# Instala sozinho (tests/windows/autounattend.xml), mede 3 boots (tests/windows/medir.ps1, mesmo método do Luma) e
# grava DIR_EVIDENCIAS/medicao-windows.txt no formato do medicao-compara.py. A ISO e o disco ficam só no runner.
# Diferenças declaradas: disco SATA (o Windows não tem driver virtio de fábrica) e sem rede (sem Windows Update
# durante a medição); memória por processo = privada (o Windows não tem PSS).
set -euo pipefail
ev="$(realpath -m "${1:?uso: vm-windows.sh DIR_EVIDENCIAS}")"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ISO_URL="${WINDOWS_ISO_URL:-https://go.microsoft.com/fwlink/?LinkId=2382600&clcid=0x409&culture=en-us&country=us}"
[ "$(id -u)" = 0 ] || { echo "vm-windows.sh: execute como root" >&2; exit 77; }
[ -e /dev/kvm ] || { echo "vm-windows.sh: /dev/kvm ausente, medição NÃO EXECUTADA" >&2; exit 1; }
work="${WORK_DIR:-/var/tmp/luma-windows}"
mkdir -p "$ev" "$work"
log() { printf '[vm-windows] %s\n' "$*" | tee -a "$ev/vm-windows.log" >&2; }
qmp_sock="$work/qmp.sock"; tpm_dir="$work/tpm"; serial="$work/serial.log"
qmp() { printf '{"execute":"qmp_capabilities"}\n%s\n' "$1" | socat -t 3 - "UNIX-CONNECT:$qmp_sock" >/dev/null 2>&1 || true; }
tela() {
	rm -f "$work/tela.png"
	qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$work/tela.png\",\"format\":\"png\"}}"
	sleep 2; [ -s "$work/tela.png" ] || return 0
	cp "$work/tela.png" "$ev/tela-windows-$1.png"
	command -v tesseract >/dev/null && log "tela $1 (OCR): $(tesseract "$work/tela.png" - -l eng 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
	return 0
}
limpa() { pkill -f "swtpm socket --tpmstate dir=$tpm_dir" 2>/dev/null || true; [ -n "${qpid:-}" ] && kill "$qpid" 2>/dev/null; true; }
trap limpa EXIT

# 1. ISO oficial da Microsoft (Evaluation Center); o sha256 vai para o log como registro
iso="$work/windows11-eval.iso"
if [ ! -s "$iso" ]; then
	log "baixando a ISO de avaliação do Windows 11 ($ISO_URL)"
	curl -fL --retry 3 -o "$iso" "$ISO_URL"
fi
log "ISO: $(stat -c %s "$iso") bytes, sha256 $(sha256sum "$iso" | cut -c1-64)"

# 2. CD de respostas (autounattend.xml na raiz é lido pelo instalador; medir.ps1 é copiado no 1º login)
mkdir -p "$work/respostas"
cp "$ROOT/tests/windows/autounattend.xml" "$ROOT/tests/windows/medir.ps1" "$work/respostas/"
xorriso -as mkisofs -quiet -J -r -V RESPOSTAS -o "$work/respostas.iso" "$work/respostas"

# 3. Disco, firmware e TPM
rm -f "$work/disco.qcow2"; qemu-img create -q -f qcow2 "$work/disco.qcow2" 64G
cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd "$work/vars.fd"
rm -rf "$tpm_dir"; mkdir -p "$tpm_dir"
swtpm socket --tpmstate "dir=$tpm_dir" --ctrl "type=unixio,path=$tpm_dir/sock" --tpm2 --daemon
for _ in 1 2 3 4 5; do [ -S "$tpm_dir/sock" ] && break; sleep 1; done
: >"$serial"

qemu-system-x86_64 -machine q35,accel=kvm,smm=on -cpu host -smp 4 -m 6144 \
	-global driver=cfi.pflash01,property=secure,value=on \
	-drive if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
	-drive if=pflash,format=raw,unit=1,file="$work/vars.fd" \
	-chardev socket,id=chrtpm,path="$tpm_dir/sock" -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-crb,tpmdev=tpm0 \
	-device ahci,id=ahci -drive id=disco,if=none,file="$work/disco.qcow2",format=qcow2 -device ide-hd,drive=disco,bus=ahci.0,bootindex=1 \
	-drive id=cd,if=none,media=cdrom,file="$iso" -device ide-cd,drive=cd,bus=ahci.1,bootindex=0 \
	-drive id=resp,if=none,media=cdrom,file="$work/respostas.iso" -device ide-cd,drive=resp,bus=ahci.2 \
	-nic none -vga std -display none -serial "file:$serial" \
	-qmp "unix:$qmp_sock,server=on,wait=off" &
qpid=$!
log "VM iniciada (instalação + 3 boots de medição)"
# "Press any key to boot from CD or DVD": só no 1º boot; depois o disco já tem o Windows
for _ in $(seq 1 30); do sleep 1; qmp '{"execute":"send-key","arguments":{"keys":[{"type":"qcode","data":"ret"}]}}'; done

# 4. Espera o fim (o medir.ps1 desliga a VM no 3º boot); tela a cada 10 min
t=0; limite=$((150 * 60))
while kill -0 "$qpid" 2>/dev/null; do
	sleep 10; t=$((t + 10))
	if [ $((t % 600)) = 0 ]; then tela "${t}s"; log "linhas no serial: $(grep -ac '^LUMACI' "$serial" || true)"; fi
	[ "$t" -ge "$limite" ] && { log "prazo de ${limite}s esgotado"; tela prazo; break; }
done
tr -d '\r' <"$serial" | grep -a '^LUMACI ' | sed 's/^LUMACI //' >"$ev/medicao-windows.txt" || true
log "linhas de medição: $(grep -c '^MED ' "$ev/medicao-windows.txt" || true)"
grep -E '^(BEGIN|MED |END)' "$ev/medicao-windows.txt" | tee -a "$ev/vm-windows.log" >&2 || true
rm -f "$work/disco.qcow2"
grep -q '^END medicao' "$ev/medicao-windows.txt" || { log "a medição do Windows não chegou ao fim"; exit 1; }
