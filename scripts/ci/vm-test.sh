#!/usr/bin/env bash
# Teste do sistema INSTALADO no CI (critérios que antes só a VM do usuário cobria). Executar como root:
#   vm-test.sh IMAGEM_LUMA IMAGEM_INSTALADOR DIR_EVIDENCIAS
# 1. Gera uma ISO de teste com o kickstart do CI (tests/vm/ks-ci.sh: apaga o disco virtual, cria o usuário
#    "teste", desliga no fim). Essa ISO é destrutiva, fica fora do artefato e é apagada depois da instalação.
# 2. Instala numa VM do laboratório (QEMU + OVMF com Secure Boot e chaves Microsoft), sem interação.
# 3. Liga o sistema instalado com duas placas: rede user (internet, Flathub) e uma tap só com o host,
#    para o nmap ver a VM de fora. O tests/vm/guest/luma-ci-checks.sh roda lá dentro e pede capturas.
# 4. Grava capturas, OCR, varredura e o log serial em DIR_EVIDENCIAS e resume em resultado.txt.
# Sai com erro se algum critério der FALHOU ou se a instalação não terminar.
set -euo pipefail
payload="${1:?uso: vm-test.sh IMAGEM_LUMA IMAGEM_INSTALADOR DIR_EVIDENCIAS}"; installer="${2:?}"
ev="$(realpath -m "${3:?}")"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LAB="$ROOT/scripts/lab/lab.sh"
[ "$(id -u)" = 0 ] || { echo "vm-test.sh: execute como root" >&2; exit 77; }
mkdir -p "$ev/capturas"
[ -e /dev/kvm ] || { echo "::warning::/dev/kvm ausente: teste do sistema instalado NÃO EXECUTADO" | tee "$ev/resultado.txt"; exit 0; }
work="${WORK_DIR:-/var/tmp/luma-vm-test}"
rm -rf "$work"; mkdir -p "$work/iso" "$work/srv/sync"
export LAB_DIR="$work/lab" VM_NAME=ci-instalado VM_NET=1 VM_AUDIO=0 VM_RAM_MB=6144 VM_CPUS=4
log() { printf '[vm-test] %s\n' "$*" | tee -a "$ev/vm-test.log" >&2; }
serial() { echo "$LAB_DIR/vms/$VM_NAME/serial.log"; }
# Só linhas terminadas: a serial chega byte a byte e a última linha pode estar pela metade
complete_lines() {
	local f; f="$(serial)"
	[ -s "$f" ] || return 0
	if [ "$(tail -c1 "$f" | od -An -tx1 | tr -d ' ')" = 0a ]; then tr -d '\r' <"$f"; else tr -d '\r' <"$f" | sed '$d'; fi
}
cleanup() {
	"$LAB" kill >/dev/null 2>&1 || true
	[ -n "${srv_pid:-}" ] && kill "$srv_pid" 2>/dev/null
	[ -n "${dns_pid:-}" ] && kill "$dns_pid" 2>/dev/null
	ip link del luma0 2>/dev/null || true
	cp -f "$(serial)" "$ev/serial-sistema.log" 2>/dev/null || true
}
trap cleanup EXIT
ocr() { tr '\n' ' ' <"$ev/capturas/$1.txt" 2>/dev/null || true; }
# Captura com OCR (texto ao lado da imagem)
capture() {
	# Acorda a tela (o Plasma apaga o monitor por ociosidade: run iso #16, "Display output is not active")
	if "$LAB" key shift >/dev/null 2>&1; then sleep 2; fi
	"$LAB" screenshot "$ev/capturas/$1.png" >/dev/null 2>&1 || { log "captura $1 falhou"; return 0; }
	tesseract "$ev/capturas/$1.png" "$ev/capturas/$1" -l eng >/dev/null 2>&1 || true
	# Texto pequeno em 1920x1080 escapa do OCR (run iso #20): também lê a captura ampliada 2x, se houver ImageMagick
	if command -v convert >/dev/null && convert "$ev/capturas/$1.png" -resize 200% "$work/ocr-2x.png" 2>/dev/null; then
		tesseract "$work/ocr-2x.png" "$work/ocr-2x" -l eng >/dev/null 2>&1 && cat "$work/ocr-2x.txt" >>"$ev/capturas/$1.txt"
	fi
}
# Espera o QEMU terminar (desligamento pelo próprio sistema) com prazo; captura a tela a cada 5 min
wait_qemu() {
	local pid="$1" limit="$2" tag="$3" t=0
	while kill -0 "$pid" 2>/dev/null; do
		sleep 10; t=$((t + 10))
		[ $((t % 300)) = 0 ] && capture "$tag-$((t / 60))min"
		[ "$t" -ge "$limit" ] && { log "$tag: prazo de ${limit}s esgotado"; return 1; }
	done
	wait "$pid" 2>/dev/null || true
}

# --- 1. ISO de teste ---------------------------------------------------------------------------------------
"$ROOT/tests/vm/ks-ci.sh" "$work/ks-ci.toml"
CONFIG="$work/ks-ci.toml" "$ROOT/build/iso/build-iso.sh" "$payload" "$installer" "$work/iso" ci-teste >"$ev/iso-teste.log" 2>&1 \
	|| { tail -n 40 "$ev/iso-teste.log" >&2; log "ISO de teste não foi gerada"; exit 1; }
iso="$work/iso/luma-ci-teste-x86_64.iso"
log "ISO de teste: $(stat -c %s "$iso") bytes (não vai para o artefato)"

# --- 2. Instalação sem interação ---------------------------------------------------------------------------
"$LAB" check >/dev/null
"$LAB" create
BOOT_ISO="$iso" "$LAB" run & qemu_pid=$!
log "instalação iniciada (prazo 50 min)"
sleep 90; capture instalacao-90s
if ! wait_qemu "$qemu_pid" 3000 instalacao; then
	capture instalacao-prazo
	cp -f "$(serial)" "$ev/serial-instalacao.log" 2>/dev/null || true
	exit 1
fi
cp -f "$(serial)" "$ev/serial-instalacao.log" 2>/dev/null || true
grep -a 'luma-ci-diag:' "$ev/serial-instalacao.log" | tee -a "$ev/vm-test.log" || true
rm -f "$iso"
log "instalação terminou; ISO de teste apagada"
# Roteiro e login automático entram com o disco desligado (no %post do instalador falhou no run iso #15)
"$ROOT/tests/vm/prepare-disk.sh" "$LAB_DIR/vms/$VM_NAME/disk.qcow2" 2>&1 | tee -a "$ev/vm-test.log"

# --- 3. Sistema instalado ----------------------------------------------------------------------------------
git -C "$ROOT" archive --format=tar.gz -o "$work/srv/lume.tar.gz" HEAD lume
(cd "$work/srv" && exec python3 -m http.server 8099 --bind 127.0.0.1 >/dev/null 2>&1) & srv_pid=$!
ip tuntap add luma0 mode tap; ip addr add 10.77.0.1/24 dev luma0; ip link set luma0 up
# DHCP só para a tap, sem rota padrão nem DNS: a internet da VM continua pela rede user
dnsmasq --no-daemon --interface=luma0 --bind-interfaces --port=0 --dhcp-range=10.77.0.10,10.77.0.50,1h \
	--dhcp-option=3 --dhcp-option=6 --dhcp-leasefile="$work/leases" >"$work/dnsmasq.log" 2>&1 & dns_pid=$!
: >"$(serial)"
VM_TAP=luma0 "$LAB" run & qemu_pid=$!
sleep 6; capture boot-06s
sleep 6; capture boot-12s
sleep 8; capture boot-20s
done_n=0; t=0; limit=4200; begun=no
while kill -0 "$qemu_pid" 2>/dev/null; do
	mapfile -t lines < <(complete_lines | grep -a '^LUMACI ' || true)
	while [ "$done_n" -lt "${#lines[@]}" ]; do
		l="${lines[$done_n]}"; done_n=$((done_n + 1))
		case "$l" in
			"LUMACI SHOT "*) n="${l#LUMACI SHOT }"; capture "$n"; touch "$work/srv/sync/shot-$n"; log "captura $n" ;;
			"LUMACI NMAP "*)
				ip_vm="${l#LUMACI NMAP }"
				log "nmap em $ip_vm"
				nmap -Pn -sS -p- -T4 --open "$ip_vm" >"$ev/nmap-tcp.txt" 2>&1 || true
				nmap -Pn -sS -p 8080 "$ip_vm" >"$ev/nmap-8080.txt" 2>&1 || true
				touch "$work/srv/sync/nmap-done" ;;
			"LUMACI BEGIN"*) begun=yes; log "${l#LUMACI }" ;;
			"LUMACI RESULT "*|"LUMACI END"*|"LUMACI AVISO"*) log "${l#LUMACI }" ;;
			# Detalhes que só iam para o serial (o artefato nem sempre dá para baixar)
			"LUMACI DATA AVC "*|"LUMACI DATA AJUSTES "*|"LUMACI DATA FAILED "*|"LUMACI DATA PLASMALOGIN "*|"LUMACI DATA SESSAOENV "*|"LUMACI DATA JANELA "*|"LUMACI DATA WELCOME "*) log "${l#LUMACI DATA }" ;;
		esac
	done
	sleep 2; t=$((t + 2))
	# Tecla a cada 2 min: sem ela o Plasma bloqueia a tela aos 5 min e a captura pega a senha (run iso #18)
	if [ $((t % 120)) = 0 ]; then "$LAB" key shift >/dev/null 2>&1 || true; fi
	if [ $((t % 300)) = 0 ]; then capture "sistema-$((t / 60))min"; log "tela aos $((t / 60)) min (OCR): $(ocr "sistema-$((t / 60))min" | cut -c1-300)"; fi
	# Sem o roteiro em 15 min não adianta esperar o prazo inteiro (run iso #15 esperou 70 min à toa)
	if [ "$begun" = no ] && [ "$t" -ge 900 ]; then
		log "o roteiro não começou em 15 min; fim do serial:"; complete_lines | tail -n 30 | tee -a "$ev/vm-test.log" >&2 || true
		capture sem-roteiro; log "tela (OCR): $(ocr sem-roteiro | cut -c1-300)"; break
	fi
	[ "$t" -ge "$limit" ] && { log "sistema instalado: prazo de ${limit}s esgotado"; capture prazo; break; }
done
cleanup
trap - EXIT

# --- 4. Veredito -------------------------------------------------------------------------------------------
s="$ev/serial-sistema.log"
results="$(tr -d '\r' <"$s" | grep -a '^LUMACI RESULT ' | sed 's/^LUMACI RESULT //' || true)"
# F5-01 de fora: nenhuma porta aberta e a 8080 (com serviço escutando lá dentro) não aberta
if grep -q 'Nmap done' "$ev/nmap-tcp.txt" 2>/dev/null && ! grep -Eq '^[0-9]+/tcp +open' "$ev/nmap-tcp.txt" \
	&& ! grep -Eq '^8080/tcp +open' "$ev/nmap-8080.txt"; then
	results+=$'\n'"F5-01 PASSOU nmap -p- de fora: nenhuma porta aberta; 8080 $(grep -Eo '^8080/tcp +[a-z|]+' "$ev/nmap-8080.txt" | tr -s ' ' || true) com serviço escutando"
else
	results+=$'\n'"F5-01 FALHOU $(grep -E '^[0-9]+/tcp|Nmap done|Failed|0 hosts' "$ev/nmap-tcp.txt" 2>/dev/null | tr '\n' ' ' || echo 'nmap não executado')"
fi
# Evidência visual só; a prova da janela é o F7-01-JANELA (o KWin lista a janela pelo título)
grep -Eqi 'Ol[aá], Luma|Ol[aá] do Lume' <<<"$(ocr lume-ola) $(ocr lume-ola-2)" && results+=$'\n'"F7-01-OCR INFO texto do ola.lume lido na captura" \
	|| results+=$'\n'"F7-01-OCR INFO texto não lido na captura (ver lume-ola.png): $(ocr lume-ola | cut -c1-120)"
grep -Eqi 'Ajustes|Apar[eê]ncia|Settings' <<<"$(ocr ajustes-aberto)" && results+=$'\n'"F3-01-OCR PASSOU janela do Ajustes" \
	|| results+=$'\n'"F3-01-OCR FALHOU OCR: $(ocr ajustes-aberto | cut -c1-200)"
results+=$'\n'"F2-03 INFO capturas boot-06s/12s/20s anexadas (logotipo sem texto: conferência visual)"
# Steam: a janela de login ou de atualização, e não o aviso de sessão sem DISPLAY (run iso #19 deu falso
# PASSOU porque o aviso também tem a palavra "Steam")
if grep -Eqi 'requires a correctly|DISPLAY environment' <<<"$(ocr steam)"; then
	results+=$'\n'"F4-01 FALHOU o Steam mostrou o aviso de sessão sem DISPLAY: $(ocr steam | cut -c1-200)"
elif grep -Eqi 'sign in|iniciar sess|entrar|updating|atualizando|steam' <<<"$(ocr steam)"; then
	results+=$'\n'"F4-01 PASSOU janela do Steam (OCR) depois de luma-jogos instalar steam"
else
	results+=$'\n'"F4-01 FALHOU janela do Steam não reconhecida: $(ocr steam | cut -c1-200)"
fi
# Marca: nenhuma tela do usuário novo apresenta o sistema como Fedora (decisão 0010)
# Citar a base ("baseado na Fedora Kinoite", na boas-vindas do Luma) é atribuição, não marca: sai antes do grep
# (run iso #27: o F2-06 reprovou o próprio texto do Luma)
if sed -E 's/basead[oa] n[oa] Fedora( Kinoite)?//Ig' <<<"$(ocr desktop-usuario-novo) $(ocr boas-vindas)" | grep -Eqi 'fedora'; then
	results+=$'\n'"F2-06 FALHOU tela do usuário novo diz Fedora: $(ocr boas-vindas | cut -c1-200)"
else
	results+=$'\n'"F2-06 PASSOU nenhuma menção a Fedora na área de trabalho e nas boas-vindas (OCR)"
fi
grep -aq '^LUMACI END' <(tr -d '\r' <"$s") || results+=$'\n'"ROTEIRO FALHOU o roteiro de dentro da VM não chegou ao fim"
{
	echo "teste do sistema instalado (ISO de teste com kickstart do CI, QEMU + OVMF Secure Boot) $(date -u +%FT%TZ)"
	sed '/^$/d' <<<"$results"
} | tee "$ev/resultado.txt"
# PARCIAL não reprova o job (ex.: AVCs só da base Fedora), mas aparece como aviso no resumo do run
{ grep ' PARCIAL ' "$ev/resultado.txt" || true; } | while IFS= read -r l; do echo "::warning::$l"; done
! grep -q ' FALHOU ' <(sed 's/^/ /' "$ev/resultado.txt")
