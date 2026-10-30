#!/usr/bin/env bash
# Dual boot em disco virtual (F6-04). Executar como root:
#   vm-dualboot.sh IMAGEM_CARGA IMAGEM_INSTALADOR DIR_EVIDENCIAS
# Simula um PC com Windows: disco GPT com ESP (\EFI\Microsoft\Boot\bootmgfw.efi), partição reservada da
# Microsoft e partição NTFS com um arquivo marcador; o resto do disco livre. Não há Windows de verdade (licença
# de terceiros): o teste prova que o instalador do Luma usa só o espaço livre, não toca no outro sistema e que
# o Luma inicia; o menu de boot com um Windows real fica para hardware ou VM do usuário.
# Mesmo caminho do teste do sistema instalado: ISO de teste (kickstart do CI com KS_DISCO=livre), instalação
# sem interação em QEMU + OVMF com Secure Boot, disco preparado pelo host (prepare-disk.sh, MODO=dualboot).
set -euo pipefail
payload="${1:?uso: vm-dualboot.sh IMAGEM_CARGA IMAGEM_INSTALADOR DIR_EVIDENCIAS}"; installer="${2:?}"
ev="$(realpath -m "${3:?}")"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LAB="$ROOT/scripts/lab/lab.sh"
[ "$(id -u)" = 0 ] || { echo "vm-dualboot.sh: execute como root" >&2; exit 77; }
[ -e /dev/kvm ] || { echo "vm-dualboot.sh: /dev/kvm ausente, teste NÃO EXECUTADO" >&2; exit 1; }
mkdir -p "$ev"
work="${WORK_DIR:-/var/tmp/luma-dualboot}"
rm -rf "$work"; mkdir -p "$work/iso"
export LAB_DIR="$work/lab" VM_NAME=dualboot VM_NET=1 VM_AUDIO=0 VM_RAM_MB=6144 VM_CPUS=4
disk="$LAB_DIR/vms/$VM_NAME/disk.qcow2"
serial="$LAB_DIR/vms/$VM_NAME/serial.log"
log() { printf '[vm-dualboot] %s\n' "$*" | tee -a "$ev/vm-dualboot.log" >&2; }
res() { printf '%s %s %s\n' "$1" "$2" "$3" | tee -a "$ev/resultado-dualboot.txt" >&2; }
loop=""; mnt="$work/mnt"
solta() { mountpoint -q "$mnt" 2>/dev/null && umount "$mnt"; [ -n "$loop" ] && losetup -d "$loop" 2>/dev/null; loop=""; }
trap 'solta; "$LAB" kill >/dev/null 2>&1 || true' EXIT
mkdir -p "$mnt" "$(dirname "$disk")"
: >"$ev/resultado-dualboot.txt"

# 1. Disco com o "Windows" simulado (mesmos tipos e nomes de partição que o instalador do Windows cria)
raw="$work/disco.raw"
truncate -s 64G "$raw"
sfdisk --quiet "$raw" <<'EOF'
label: gpt
size=260MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI system partition"
size=16MiB, type=E3C9E316-0B5C-4DB8-817D-F92DF00215AE, name="Microsoft reserved partition"
size=16GiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="Basic data partition"
EOF
loop="$(losetup -fP --show "$raw")"; udevadm settle 2>/dev/null || true
mkfs.vfat -F 32 -n SYSTEM "${loop}p1" >/dev/null
mkfs.ntfs -Q -L Windows "${loop}p3" >/dev/null
mount "${loop}p1" "$mnt"
mkdir -p "$mnt/EFI/Microsoft/Boot"
printf 'luma-ci: carregador do Windows SIMULADO (não é um binário EFI)\n' >"$mnt/EFI/Microsoft/Boot/bootmgfw.efi"
umount "$mnt"
printf 'luma-ci: arquivo do outro sistema, não pode mudar\n' >"$work/marcador.txt"
ntfscp "${loop}p3" "$work/marcador.txt" luma-ci-marcador.txt
hash_antes="$(sha256sum <"${loop}p3" | cut -c1-64)"
solta
qemu-img convert -O qcow2 "$raw" "$disk"; rm -f "$raw"
log "disco simulado: ESP 260 MiB, MSR 16 MiB, NTFS 16 GiB (sha256 ${hash_antes:0:16}…), resto livre"

# 2. Instalação sem interação no espaço livre
KS_DISCO=livre "$ROOT/tests/vm/ks-ci.sh" "$work/ks-ci.toml" >/dev/null
grep -q 'clearpart --none' "$work/ks-ci.toml" || { log "kickstart sem clearpart --none: abortado"; exit 1; }
CONFIG="$work/ks-ci.toml" "$ROOT/build/iso/build-iso.sh" "$payload" "$installer" "$work/iso" dualboot >"$ev/iso-dualboot.log" 2>&1 \
	|| { tail -n 40 "$ev/iso-dualboot.log" >&2; log "ISO de teste não foi gerada"; exit 1; }
"$LAB" check >/dev/null
"$LAB" create >/dev/null
BOOT_ISO="$work/iso/luma-dualboot-x86_64.iso" "$LAB" run & pid=$!
log "instalação iniciada"
t=0
while kill -0 "$pid" 2>/dev/null; do
	sleep 10; t=$((t + 10))
	if [ $((t % 600)) = 0 ]; then "$LAB" screenshot "$ev/tela-instalacao-${t}s.png" >/dev/null 2>&1 || true; fi
	[ "$t" -ge 3000 ] && { log "prazo de instalação esgotado"; "$LAB" screenshot "$ev/tela-prazo.png" >/dev/null 2>&1 || true; exit 1; }
done
rm -f "$work/iso/"*.iso

# 3. Conferência offline: o outro sistema ficou intacto?
raw="$work/depois.raw"; qemu-img convert -O raw "$disk" "$raw"
loop="$(losetup -fP --show "$raw")"; udevadm settle 2>/dev/null || true
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$loop" | tee -a "$ev/vm-dualboot.log" >&2
ntfs="$(blkid -t LABEL=Windows -o device "$loop"p* 2>/dev/null | head -n1)"
hash_depois=""
if [ -n "$ntfs" ]; then hash_depois="$(sha256sum <"$ntfs" | cut -c1-64)"; fi
ms=no; esp_luma=""
for p in "$loop"p*; do
	[ "$(blkid -o value -s TYPE "$p" 2>/dev/null)" = vfat ] || continue
	mount -o ro "$p" "$mnt"
	if grep -qs 'SIMULADO' "$mnt/EFI/Microsoft/Boot/bootmgfw.efi"; then
		ms=yes
		if [ -d "$mnt/EFI/fedora" ]; then esp_luma="mesmo ESP do Windows"; fi
	elif [ -d "$mnt/EFI/fedora" ]; then
		esp_luma="ESP próprio ($p)"
	fi
	log "ESP $p: $(find "$mnt/EFI" -maxdepth 2 2>/dev/null | sed "s|$mnt||" | tr '\n' ' ')"
	umount "$mnt"
done
solta; rm -f "$raw"
if [ -n "$hash_depois" ] && [ "$hash_depois" = "$hash_antes" ] && [ "$ms" = yes ]; then
	res F6-04-PRESERVA PASSOU "partição NTFS idêntica (sha256 ${hash_antes:0:16}…) e carregador do Windows no ESP"
else
	res F6-04-PRESERVA FALHOU "NTFS antes ${hash_antes:0:16} depois ${hash_depois:0:16}; carregador do Windows no ESP: $ms"
fi
res F6-04-ESP INFO "carregador do Luma: ${esp_luma:-não encontrado}"

# 4. O Luma inicia ao lado do outro sistema
MODO=dualboot "$ROOT/tests/vm/prepare-disk.sh" "$disk" 2>&1 | grep -E 'roteiro|ERRO' | tee -a "$ev/vm-dualboot.log"
: >"$serial"
"$LAB" run & pid=$!
t=0
while kill -0 "$pid" 2>/dev/null; do
	sleep 10; t=$((t + 10))
	[ "$t" -ge 900 ] && { log "prazo do boot esgotado"; "$LAB" screenshot "$ev/tela-boot-prazo.png" >/dev/null 2>&1 || true; break; }
done
tr -d '\r' <"$serial" | grep -a '^LUMACI ' | sed 's/^LUMACI //' >"$ev/serial-dualboot.txt" || true
grep '^DATA ' "$ev/serial-dualboot.txt" | sed 's/^DATA /[vm-dualboot] /' >&2 || true
sed -n 's/^RESULT //p' "$ev/serial-dualboot.txt" | tee -a "$ev/resultado-dualboot.txt" >&2
rm -rf "$work/lab"
echo "--- resultado (F6-04) ---"; cat "$ev/resultado-dualboot.txt"
grep -q '^F6-04-BOOT PASSOU' "$ev/resultado-dualboot.txt" || res F6-04-BOOT FALHOU "o Luma não chegou à sessão (ver serial)"
! grep -q ' FALHOU ' "$ev/resultado-dualboot.txt"
