#!/usr/bin/env bash
# Smoke test de boot da ISO no CI (F1-03): inicia a ISO em QEMU + OVMF com Secure Boot pelo laboratório
# (scripts/lab/lab.sh), captura a tela em dois momentos e lê o texto (OCR, tesseract). Executar como root.
# Veredito: INSTALADOR (texto do Anaconda) = passa; FALHA (Boot Manager do firmware, GRUB parado, kernel
# panic, Secure Boot recusando) = falha; nada reconhecível = INCONCLUSIVO, registrado e sem falhar o job.
# Antes só se conferia "tela não vazia", e o Boot Manager do OVMF passava como sucesso (F1-03).
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
early=90
sleep "$early"
kill -0 "$qemu_pid" 2>/dev/null || { echo "QEMU encerrou antes da captura" | tee "$out/boot-resultado.txt"; exit 1; }
"$LAB" screenshot "$out/boot-${early}s.png"
sleep "$((wait_s - early))"
kill -0 "$qemu_pid" 2>/dev/null || { echo "QEMU encerrou antes da captura" | tee "$out/boot-resultado.txt"; exit 1; }
"$LAB" screenshot "$out/boot-${wait_s}s.png"

command -v tesseract >/dev/null || { echo "tesseract ausente: veredito INCONCLUSIVO" | tee "$out/boot-resultado.txt"; exit 0; }
for png in "$out/boot-${early}s.png" "$out/boot-${wait_s}s.png"; do
	tesseract "$png" "${png%.png}" -l eng >/dev/null 2>&1 || true
done
final="$(tr '\n' ' ' < "$out/boot-${wait_s}s.txt" 2>/dev/null || true)"
all="$(cat "$out/boot-${early}s.txt" "$out/boot-${wait_s}s.txt" 2>/dev/null | tr '\n' ' ')"
# Firmware, Secure Boot ou kernel em qualquer captura; menu do GRUB só conta se ainda estiver na final.
# Instalação em andamento sem ninguém interagir = o instalador apaga o disco sozinho (run iso #8): FALHA.
# Desde a Fase 6 o kickstart do Luma (build/iso/config.toml) deixa o Anaconda esperando na tela de resumo.
bad='Boot Manager|Boot Options|Shell>|Access Denied|Security Violation|Verification failed|Kernel panic|emergency mode'
stuck='Test this media'
unattended='INSTALLATION PROGRESS|Installation Progress'
good='WELCOME|Welcome to|language would you like|INSTALLATION SUMMARY|Installation Summary|Bem-vindo|RESUMO DA INSTALA|Resumo da instala'
if grep -Eqi "$bad" <<<"$all" || grep -Eqi "$stuck" <<<"$final"; then verdict=FALHA
elif grep -Eqi "$unattended" <<<"$final"; then verdict="FALHA (instalação começou sem interação)"
elif grep -Eqi "$good" <<<"$final"; then verdict=INSTALADOR
else verdict=INCONCLUSIVO; fi
{
	echo "veredito: $verdict (capturas aos ${early}s e ${wait_s}s, OCR tesseract)"
	echo "texto final (OCR): $(cut -c1-400 <<<"$final")"
} | tee "$out/boot-resultado.txt"
[ "${verdict%% *}" != FALHA ]
