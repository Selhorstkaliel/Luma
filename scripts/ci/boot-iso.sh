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
# Marca Luma no Anaconda (F6-05): cor da barra lateral à esquerda, em duas alturas (Midnight = quase preto
# azulado; a da base é azul ou cinza). Só registro: a aprovação visual é da captura.
cor_lateral="$("$LAB" pixel 12 420 2>/dev/null || echo '?') / $("$LAB" pixel 12 700 2>/dev/null || echo '?')"

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
	echo "F6-05 INFO cor da barra lateral (x=12, y=420 / y=700; Midnight ~ 8 13 25): $cor_lateral"
	# Critério da etapa C: instalador em português (instalador-ib #11: gráfico e Midnight, mas em inglês)
	if grep -Eqi 'RESUMO DA INSTALA|DESTINO DA INSTALA|Cria..o de usu' <<<"$final"; then idioma=pt
	elif grep -Eqi 'INSTALLATION SUMMARY|Installation Destination' <<<"$final"; then idioma=en; else idioma='?'; fi
	echo "F6-05 INFO idioma do instalador (OCR): $idioma"
} | tee "$out/boot-resultado.txt"
# BOOT_DIAG=1 (workflow instalador-ib): com a interface gráfica do Anaconda sem aparecer, o shell do TTY2 mostra
# por quê. As teclas vão pelo QMP (teclado us do instalador); a tela vai para o log por OCR.
digitar() {
	local t="$1" i c k
	for ((i = 0; i < ${#t}; i++)); do
		c="${t:i:1}"
		case "$c" in
			[a-z0-9]) k="$c" ;;
			[A-Z]) k="shift-${c,,}" ;;
			' ') k=spc ;; '-') k=minus ;; '/') k=slash ;; '.') k='dot' ;; '|') k=shift-backslash ;;
			"'") k=apostrophe ;; '*') k=shift-8 ;; '>') k=shift-dot ;; ',') k=comma ;; '_') k=shift-minus ;;
			\\) k=backslash ;; ';') k=semicolon ;; '=') k=equal ;; '^') k=shift-6 ;; '$') k=shift-4 ;; '#') k=shift-3 ;;
			'(') k=shift-9 ;; ')') k=shift-0 ;; ':') k=shift-semicolon ;; '"') k=shift-apostrophe ;; '&') k=shift-7 ;;
			*) continue ;;
		esac
		"$LAB" key "$k" >/dev/null 2>&1 || true
	done
	"$LAB" key ret >/dev/null 2>&1 || true
}
# Uma tela por comando: limpa (printf \ec, porque o instalador não tem clear; instalador-ib #10), digita, captura e
# grava o OCR no boot-resultado.txt (instalador-ib #6: sem limpar, as
# saídas se acumulavam na mesma tela e o OCR as misturava)
diag() {
	local nome="$1"
	digitar "printf '\\ec'; $2"
	sleep 5
	"$LAB" screenshot "$out/boot-diag-$nome.png" >/dev/null 2>&1 || true
	tesseract "$out/boot-diag-$nome.png" "$out/boot-diag-$nome" -l eng >/dev/null 2>&1 || true
	echo "F6-05 DIAG $nome (OCR): $(tr '\n' ' ' <"$out/boot-diag-$nome.txt" 2>/dev/null | cut -c1-1800)" | tee -a "$out/boot-resultado.txt"
}
# Desde o instalador-ib #11 roda também com veredito INSTALADOR (para ver o idioma); o terminal fica no TTY2.
if [ "${BOOT_DIAG:-0}" = 1 ] && [ "${verdict%% *}" != FALHA ] && kill -0 "$qemu_pid" 2>/dev/null; then
	"$LAB" key ctrl-alt-f2 >/dev/null 2>&1 || true
	sleep 3
	diag modo "cat /proc/cmdline; grep -ihE 'display mode|wayland|gui' /tmp/anaconda.log | tail -n 8"
	# instalador-ib #13: com inst.lang=pt_BR.UTF-8 no boot, o Anaconda ainda fez "setting locale to: en_US.UTF-8".
	# [H] o locale pt_BR não existe no ambiente do instalador (limpeza do lorax/osbuild) e o Anaconda volta ao inglês.
	diag locales "cat /etc/locale.conf; locale -a | grep -ci pt_br; ls /usr/lib/locale; ls /usr/share/locale/pt_BR/LC_MESSAGES | grep -c anaconda"
	diag anacondalog "grep -inE 'lang|locale' /tmp/anaconda.log | head -n 20 | cut -c1-150"
	diag suporte "python3 -c 'from pyanaconda import localization as l; print(l.is_supported_locale(\"pt_BR.UTF-8\"), l.locale_has_translation(\"pt_BR.UTF-8\"))' 2>&1 | tail -n 3"
fi
[ "${verdict%% *}" != FALHA ]
