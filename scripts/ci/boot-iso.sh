#!/usr/bin/env bash
# Smoke test de boot da ISO no CI (F1-03): inicia a ISO em QEMU + OVMF com Secure Boot pelo laboratório
# (scripts/lab/lab.sh), espera, captura a tela e confere que ela não está vazia. Executar como root.
#   boot-iso.sh ARQUIVO.iso DIR_SAIDA [ESPERA_SEG]
# Sem /dev/kvm o teste é declarado NÃO EXECUTADO (código 0, com aviso), nunca aprovado.
set -euo pipefail
iso="$(realpath "${1:?uso: boot-iso.sh ARQUIVO.iso DIR_SAIDA [ESPERA_SEG]}")"
out="$(realpath -m "${2:?}")"; wait_s="${3:-240}"
LAB="$(cd "$(dirname "$0")/../lab" && pwd)/lab.sh"
mkdir -p "$out"
if [ ! -e /dev/kvm ]; then
	echo "::warning::/dev/kvm ausente no runner: boot da ISO NÃO EXECUTADO" | tee "$out/boot-resultado.txt"
	exit 0
fi
export LAB_DIR="${LAB_DIR:-/mnt/luma-lab}" VM_NAME=ci-boot VM_NET=0 VM_AUDIO=0 VM_RAM_MB=4096 VM_CPUS=2 BOOT_ISO="$iso"
"$LAB" check
"$LAB" create
"$LAB" run & qemu_pid=$!
trap '"$LAB" kill >/dev/null 2>&1 || true' EXIT
sleep "$wait_s"
kill -0 "$qemu_pid" 2>/dev/null || { echo "QEMU encerrou antes da captura" | tee "$out/boot-resultado.txt"; exit 1; }
"$LAB" screenshot "$out/boot-${wait_s}s.png"
# Tela "viva": mais de 1% dos pixels diferentes da cor dominante (uma tela preta ou de erro chapada falha)
python3 - "$out/boot-${wait_s}s.png" > "$out/boot-resultado.txt" <<'PY'
import struct, sys, zlib, collections
data = open(sys.argv[1], "rb").read()
w, h, depth, ctype = struct.unpack(">IIBB", data[16:26])
idat, pos = b"", 8
while pos < len(data):
    n = struct.unpack(">I", data[pos:pos + 4])[0]; kind = data[pos + 4:pos + 8]
    if kind == b"IDAT":
        idat += data[pos + 8:pos + 8 + n]
    pos += 12 + n
raw = zlib.decompress(idat)
bpp = {2: 3, 6: 4}[ctype]
stride = w * bpp
# Amostra a coluna de bytes sem desfazer o filtro PNG: suficiente para distinguir tela chapada de tela com conteúdo
counts = collections.Counter(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)][::bpp * 7] for y in range(0, h, 16))
top = counts.most_common(1)[0][1] / sum(counts.values())
verdict = "VIVA" if top < 0.99 else "CHAPADA"
print(f"captura {w}x{h}; linhas amostradas iguais à mais comum: {top:.1%}; tela {verdict}")
sys.exit(0 if verdict == "VIVA" else 1)
PY
cat "$out/boot-resultado.txt"
