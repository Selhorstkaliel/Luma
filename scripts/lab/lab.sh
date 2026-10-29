#!/usr/bin/env bash
# Laboratório Luma (edição Fedora): VM UEFI (QEMU/KVM + OVMF com Secure Boot) para testar a Fedora Kinoite
# oficial (referência) e, a partir da Fase 1, a ISO do Luma.
# Executar num Linux com /dev/kvm (WSL2 Fedora ou Debian do host Windows), como root:
#   scripts/lab/lab.sh <comando>
# Herdado de LUMA-OS@44903f2. Mudanças: ISO Kinoite assinada pelo Fedora no lugar da netinst Debian;
# instalação interativa (sem preseed; a desassistida por kickstart entra com a ISO do Luma na Fase 1);
# firmware OVMF detectado nos caminhos do Fedora e do Debian.
# Todos os comandos são idempotentes: repetir não duplica discos nem snapshots.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lab/config.sh
. "$SCRIPT_DIR/config.sh"

ISO_DIR="$LAB_DIR/iso"
SECRETS_DIR="$LAB_DIR/secrets"
SSH_KEY="$SECRETS_DIR/id_ed25519"
KNOWN_HOSTS="$SECRETS_DIR/known_hosts"
DISK="$VM_DIR/disk.qcow2"
PIDFILE="$VM_DIR/qemu.pid"
QMP_SOCK="$VM_DIR/qmp.sock"
QGA_SOCK="$VM_DIR/qga.sock"
SNAP_DIR="$VM_DIR/snapshots"

log() { printf '[lab] %s\n' "$*" >&2; }
die() { printf '[lab] ERRO: %s\n' "$1" >&2; exit "${2:-1}"; }

# Firmware: par CODE|VARS. Fedora (edk2-ovmf) e Debian (ovmf) usam nomes e formatos diferentes.
ovmf_pair() {
	local -a cands
	if [ -n "$OVMF_CODE" ] || [ -n "$OVMF_VARS_TEMPLATE" ]; then
		echo "$OVMF_CODE|$OVMF_VARS_TEMPLATE"; return
	fi
	if [ "$VM_SECUREBOOT" = 1 ]; then
		cands=("/usr/share/edk2/ovmf/OVMF_CODE_4M.secboot.qcow2|/usr/share/edk2/ovmf/OVMF_VARS_4M.secboot.qcow2"
			"/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd|/usr/share/edk2/ovmf/OVMF_VARS.secboot.fd"
			"/usr/share/OVMF/OVMF_CODE_4M.secboot.fd|/usr/share/OVMF/OVMF_VARS_4M.ms.fd")
	else
		cands=("/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2|/usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2"
			"/usr/share/edk2/ovmf/OVMF_CODE.fd|/usr/share/edk2/ovmf/OVMF_VARS.fd"
			"/usr/share/OVMF/OVMF_CODE_4M.fd|/usr/share/OVMF/OVMF_VARS_4M.fd")
	fi
	local c
	for c in "${cands[@]}"; do
		if [ -r "${c%|*}" ] && [ -r "${c#*|}" ]; then echo "$c"; return; fi
	done
	echo "|"
}
fw_format() { case "$1" in *.qcow2) echo qcow2 ;; *) echo raw ;; esac; }
ovmf_code() { local p; p="$(ovmf_pair)"; echo "${p%|*}"; }
ovmf_vars_template() { local p; p="$(ovmf_pair)"; echo "${p#*|}"; }
vars_file() { echo "$VM_DIR/OVMF_VARS.$(fw_format "$(ovmf_vars_template)")"; }

cmd_check() {
	local missing=() b
	for b in "$QEMU" "$QEMU_IMG" gpg curl sha256sum ssh socat python3; do
		command -v "$b" >/dev/null 2>&1 || missing+=("$b")
	done
	[ ${#missing[@]} -eq 0 ] || die "dependências ausentes: ${missing[*]}. Fedora: dnf install qemu-kvm qemu-img edk2-ovmf gnupg2 curl openssh-clients socat python3; Debian: apt-get install qemu-system-x86 qemu-utils ovmf gnupg curl openssh-client socat python3" 2
	local code vars
	code="$(ovmf_code)"; vars="$(ovmf_vars_template)"
	if [ -z "$code" ] || [ ! -r "$code" ] || [ ! -r "$vars" ]; then
		die "firmware OVMF (Secure Boot=$VM_SECUREBOOT) não encontrado; instale edk2-ovmf/ovmf ou defina OVMF_CODE e OVMF_VARS_TEMPLATE" 2
	fi
	[ -w /dev/kvm ] || die "/dev/kvm indisponível ou sem permissão; sem aceleração a VM é inviável" 2
	log "dependências OK ($("$QEMU" --version | head -n1)); firmware: $code"
}

# Baixa a ISO da Fedora Kinoite e confere: CHECKSUM assinado pela chave fixada + SHA-256 da ISO.
cmd_fetch_iso() {
	cmd_check
	[ -n "$FEDORA_KEY_FPR" ] || die "FEDORA_KEY_FPR vazio: confira a impressão digital da chave do Fedora $FEDORA_VERSION em https://fedoraproject.org/security/ e defina-a (config.sh ou ambiente)" 2
	mkdir -p "$ISO_DIR"
	local listing iso sums gnupg
	listing="$(curl -fsSL "$FEDORA_ISO_URL/")" || die "listagem indisponível: $FEDORA_ISO_URL/"
	iso="${FEDORA_ISO:-$(grep -oE 'Fedora-Kinoite-[A-Za-z0-9._-]+\.iso' <<<"$listing" | sort -uV | tail -n1)}"
	sums="$(grep -oE 'Fedora-Kinoite-[A-Za-z0-9._-]+-CHECKSUM' <<<"$listing" | sort -uV | tail -n1)"
	if [ -z "$iso" ] || [ -z "$sums" ]; then die "ISO ou CHECKSUM da Kinoite não encontrados em $FEDORA_ISO_URL/"; fi

	curl -fsSL "$FEDORA_ISO_URL/$sums" -o "$WORK/CHECKSUM.signed"
	gnupg="$WORK/gnupg"; mkdir -m 0700 "$gnupg"
	curl -fsSL "$FEDORA_KEYS_URL" | gpg --homedir "$gnupg" --quiet --import
	gpg --homedir "$gnupg" --with-colons --fingerprint | grep -q "^fpr:::::::::$FEDORA_KEY_FPR:" \
		|| die "a chave fixada $FEDORA_KEY_FPR não está entre as chaves baixadas de $FEDORA_KEYS_URL"
	# --decrypt grava só o conteúdo coberto pela assinatura (texto fora dela é descartado)
	gpg --homedir "$gnupg" --status-fd 3 --output "$WORK/CHECKSUM" --decrypt "$WORK/CHECKSUM.signed" 3>"$WORK/gpg.status" 2>/dev/null || true
	grep -q "^\[GNUPG:\] VALIDSIG $FEDORA_KEY_FPR " "$WORK/gpg.status" || die "assinatura de $sums inválida ou de outra chave"
	grep -q "($iso)" "$WORK/CHECKSUM" || die "$iso não consta no CHECKSUM assinado"
	cp "$WORK/CHECKSUM" "$ISO_DIR/$sums"
	log "$sums assinado por $FEDORA_KEY_FPR"

	if [ -f "$ISO_DIR/$iso" ] && (cd "$ISO_DIR" && grep "($iso)" "$sums" | sha256sum -c --quiet -); then
		log "$iso já presente e íntegra; download ignorado"
	else
		log "baixando $FEDORA_ISO_URL/$iso"
		curl -fsSL --retry 3 -C - "$FEDORA_ISO_URL/$iso" -o "$ISO_DIR/$iso.part"
		mv "$ISO_DIR/$iso.part" "$ISO_DIR/$iso"
		(cd "$ISO_DIR" && grep "($iso)" "$sums" | sha256sum -c -) || { rm -f "$ISO_DIR/$iso"; die "checksum da ISO não confere; arquivo removido"; }
	fi
	ln -sfn "$iso" "$ISO_DIR/kinoite-$FEDORA_VERSION.iso"
	log "ISO de referência: $ISO_DIR/kinoite-$FEDORA_VERSION.iso"
}

cmd_create() {
	cmd_check
	mkdir -p "$VM_DIR" "$SNAP_DIR"
	if [ -f "$DISK" ]; then
		log "disco $DISK já existe; nada criado"
	else
		"$QEMU_IMG" create -q -f qcow2 "$DISK" "$VM_DISK_SIZE"
		log "disco criado: $DISK ($VM_DISK_SIZE, alocação dinâmica)"
	fi
	if [ ! -f "$(vars_file)" ]; then
		cp "$(ovmf_vars_template)" "$(vars_file)"
		log "variáveis UEFI criadas a partir de $(ovmf_vars_template)"
	fi
}

is_running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

qemu_args() {
	local machine="q35,accel=kvm" code vars
	local -a a
	code="$(ovmf_code)"; vars="$(vars_file)"
	[ "$VM_SECUREBOOT" = 1 ] && machine="$machine,smm=on"
	# A ordem dos dispositivos define os endereços PCI (e o nome da interface de rede) que o sistema
	# instalado em base-limpa conhece. Dispositivos novos entram sempre no FIM da lista.
	a=(-name "$VM_NAME" -machine "$machine" -cpu host -smp "$VM_CPUS" -m "$VM_RAM_MB"
		-drive "if=pflash,format=$(fw_format "$code"),unit=0,readonly=on,file=$code"
		-drive "if=pflash,format=$(fw_format "$vars"),unit=1,file=$vars"
		-drive "if=virtio,file=$DISK,format=qcow2,discard=unmap")
	# -nic none: sem isso o QEMU cria uma placa padrão (e1000e no q35) quando não há -netdev
	if [ "$VM_NET" = 1 ]; then
		a+=(-netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$VM_SSH_PORT-:22,hostfwd=tcp:127.0.0.1:$VM_HTTP_PORT-:8080" -device "virtio-net-pci,netdev=n0")
	else
		a+=(-nic none)
	fi
	a+=(-device "virtio-vga,xres=$VM_XRES,yres=$VM_YRES"
		-device qemu-xhci -device usb-tablet -device usb-kbd)
	[ "$VM_AUDIO" = 1 ] && a+=(-audiodev "none,id=snd0" -device intel-hda -device "hda-duplex,audiodev=snd0")
	# VM_GUI=1: janela do QEMU na área de trabalho (no Windows, via WSLg) para uso manual; os testes usam "none"
	local display=none
	[ "${VM_GUI:-0}" = 1 ] && display="gtk,zoom-to-fit=on"
	a+=(-device virtio-rng-pci
		-display "$display" -vnc "127.0.0.1:$VM_VNC_DISPLAY"
		-qmp "unix:$QMP_SOCK,server=on,wait=off"
		-pidfile "$PIDFILE"
		-device virtio-serial -chardev "socket,path=$QGA_SOCK,server=on,wait=off,id=qga0"
		-device "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0")
	[ "$VM_SECUREBOOT" = 1 ] && a+=(-global "driver=cfi.pflash01,property=secure,value=on")
	# VM_TAP=ifname: segunda placa numa tap já criada no host, para varrer a VM "de fora" (nmap) sem passar
	# pela NAT da rede user (teste do CI, scripts/ci/vm-test.sh). Fica no fim para não mudar os endereços PCI.
	[ -n "${VM_TAP:-}" ] && a+=(-netdev "tap,id=n1,ifname=$VM_TAP,script=no,downscript=no"
		-device "virtio-net-pci,netdev=n1,mac=52:54:00:4c:55:4d")
	# BOOT_ISO: mídia óptica no controlador AHCI embutido (não altera endereços PCI)
	# cache=none: lê a ISO sem encher o cache de páginas do WSL (LUMA-OS, etapa 8 falha1: host sem memória)
	# bootindex=0: a mídia inicia antes do disco mesmo com sistema já instalado (equivale ao menu de boot do PC)
	[ -n "${BOOT_ISO:-}" ] && a+=(-drive "file=$BOOT_ISO,if=none,id=cd0,media=cdrom,readonly=on,cache=none"
		-device "ide-cd,drive=cd0,bootindex=0")
	printf '%s\0' "${a[@]}"
}

run_qemu() {
	is_running && die "VM $VM_NAME já está em execução (pid $(cat "$PIDFILE"))"
	local -a args
	mapfile -d '' args < <(qemu_args)
	"$QEMU" "${args[@]}" "$@"
}

# Instalação interativa da ISO (padrão: Kinoite de referência). Ao terminar, desligue a VM e salve o
# snapshot base-limpa. A instalação desassistida (kickstart) entra com a ISO do Luma na Fase 1.
cmd_install() {
	if [ -f "$DISK" ] && "$QEMU_IMG" snapshot -l -U "$DISK" | grep -qw base-limpa; then
		log "snapshot base-limpa já existe; instalação ignorada (apague $VM_DIR para refazer)"
		return
	fi
	local iso="${BOOT_ISO:-$ISO_DIR/kinoite-$FEDORA_VERSION.iso}"
	[ -r "$iso" ] || die "ISO não encontrada: $iso (rode fetch-iso ou defina BOOT_ISO)"
	cmd_create
	rm -f "$KNOWN_HOSTS"
	log "instalação interativa: use VM_GUI=1 ou VNC 127.0.0.1:$((5900 + VM_VNC_DISPLAY)). Depois: lab.sh snapshot-save base-limpa"
	BOOT_ISO="$iso" run_qemu -serial "file:$VM_DIR/install-serial.log"
}

cmd_run() {
	[ -f "$DISK" ] || die "disco inexistente; execute 'create' ou 'install' primeiro"
	log "VM iniciando; SSH 127.0.0.1:$VM_SSH_PORT; VNC 127.0.0.1:$((5900 + VM_VNC_DISPLAY)). Processo em primeiro plano."
	run_qemu -serial "file:$VM_DIR/serial.log"
}

# SSH só com a chave do laboratório ($SECRETS_DIR/id_ed25519), cadastrada pelo usuário na VM
ssh_vm() {
	[ -f "$SSH_KEY" ] || die "sem chave do laboratório em $SSH_KEY (crie com ssh-keygen e cadastre na VM)"
	ssh -i "$SSH_KEY" -p "$VM_SSH_PORT" -o BatchMode=yes -o ConnectTimeout=5 \
		-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$KNOWN_HOSTS" \
		-o LogLevel=ERROR "${VM_USER:-luma}@127.0.0.1" "$@"
}

cmd_wait_ssh() {
	local deadline=$((SECONDS + ${1:-600})) grace=$((SECONDS + 30))
	until ssh_vm true 2>/dev/null; do
		# QEMU pode ainda não ter gravado o pidfile logo após 'run &'
		is_running || [ $SECONDS -lt $grace ] || die "VM não está em execução"
		[ $SECONDS -lt $deadline ] || die "SSH não respondeu no prazo"
		sleep 5
	done
	log "SSH disponível"
}

qmp() {
	is_running || die "VM não está em execução"
	printf '{"execute":"qmp_capabilities"}\n%s\n' "$1" | socat -t 3 - "UNIX-CONNECT:$QMP_SOCK"
}

cmd_screenshot() {
	local out="${1:?uso: screenshot ARQUIVO.png}" tmp="$VM_DIR/screendump.png"
	rm -f "$tmp"
	qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$tmp\",\"format\":\"png\"}}" >/dev/null
	for _ in 1 2 3 4 5; do [ -s "$tmp" ] && break; sleep 1; done
	[ -s "$tmp" ] || die "screendump não gerou arquivo"
	cp "$tmp" "$out"
	log "captura salva em $out"
}

# Cor "R G B" de um pixel da tela (coordenadas da captura). Permite ao teste ler um indicador visual
# sem depender do que foi digitado às cegas.
cmd_pixel() {
	local x="${1:?uso: pixel X Y}" y="${2:?uso: pixel X Y}" tmp="$VM_DIR/screendump.ppm"
	rm -f "$tmp"
	qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$tmp\"}}" >/dev/null
	for _ in 1 2 3 4 5; do [ -s "$tmp" ] && break; sleep 1; done
	[ -s "$tmp" ] || die "screendump não gerou arquivo"
	python3 - "$tmp" "$x" "$y" <<'PY'
import sys
f = open(sys.argv[1], "rb"); x, y = int(sys.argv[2]), int(sys.argv[3])
# PPM binário (P6): "P6", largura, altura e valor máximo separados por espaço em branco, depois RGB
tok = []
while len(tok) < 4:
    line = f.readline()
    if not line.startswith(b"#"):
        tok += line.split()
w, h = int(tok[1]), int(tok[2])
if tok[0] != b"P6" or not (0 <= x < w and 0 <= y < h):
    sys.exit("pixel fora da tela %dx%d" % (w, h))
f.seek(f.tell() + 3 * (y * w + x))
print(*f.read(3))
PY
}

# Teclado via QMP: cada argumento é uma combinação de qcodes unidos por '-' (ex.: meta_l, alt-tab, ctrl-alt-t)
cmd_key() {
	local combo keys k
	[ $# -gt 0 ] || die "uso: key COMBO [COMBO...] (qcodes QEMU, ex.: meta_l alt-tab ret)"
	for combo in "$@"; do
		keys=""
		IFS='-' read -r -a parts <<<"$combo"
		for k in "${parts[@]}"; do keys="$keys{\"type\":\"qcode\",\"data\":\"$k\"},"; done
		qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[${keys%,}],\"hold-time\":50}}" | grep -q '"error"' && die "send-key falhou para $combo"
		sleep 0.3
	done
}

# Ponteiro absoluto (usb-tablet) via QMP. Coordenadas em unidades abs 0..32767 sobre a tela inteira.
#   mouse move X Y | mouse down|up [left|right] | mouse click [left|right] | mouse dblclick
cmd_mouse() {
	local op="${1:-}" b
	case "$op" in
		move)
			[ $# -eq 3 ] || die "uso: mouse move X Y (0..32767)"
			qmp "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"abs\",\"data\":{\"axis\":\"x\",\"value\":$2}},{\"type\":\"abs\",\"data\":{\"axis\":\"y\",\"value\":$3}}]}}" >/dev/null ;;
		down|up)
			b="${2:-left}"
			qmp "{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"btn\",\"data\":{\"down\":$([ "$op" = down ] && echo true || echo false),\"button\":\"$b\"}}]}}" >/dev/null ;;
		click) cmd_mouse down "${2:-left}"; sleep 0.1; cmd_mouse up "${2:-left}" ;;
		dblclick) cmd_mouse click; sleep 0.12; cmd_mouse click ;;
		wheel) b="wheel-${2:-up}"; cmd_mouse down "$b"; cmd_mouse up "$b" ;;
		*) die "uso: mouse move X Y | down|up|click [left|right] | dblclick | wheel up|down" ;;
	esac
}

# Executa um comando como root na VM pelo agente QEMU (funciona sem rede). Exige qemu-guest-agent no convidado.
cmd_ga() {
	is_running || die "VM não está em execução"
	[ $# -gt 0 ] || die "uso: ga COMANDO"
	python3 "$SCRIPT_DIR/qga.py" "$QGA_SOCK" "$*"
}

# Encerra o QEMU imediatamente (último recurso quando o convidado não desliga)
cmd_kill() {
	is_running || { log "VM já está desligada"; return; }
	qmp '{"execute":"quit"}' >/dev/null || true
	for _ in $(seq 1 20); do is_running || { log "VM encerrada à força"; return; }; sleep 1; done
	die "QEMU não encerrou"
}

# Liga/desliga o cabo da placa de rede virtual (simula falha de rede)
cmd_link() {
	case "${1:-}" in
		on) qmp '{"execute":"set_link","arguments":{"name":"n0","up":true}}' >/dev/null ;;
		off) qmp '{"execute":"set_link","arguments":{"name":"n0","up":false}}' >/dev/null ;;
		*) die "uso: link on|off" ;;
	esac
	log "link de rede: $1"
}

cmd_powerdown() {
	is_running || { log "VM já está desligada"; return; }
	# Com sessão Plasma aberta, o botão ACPI abre o diálogo de logout em vez de desligar; por isso o agente
	# QEMU (se instalado no convidado) vem primeiro e o ACPI fica como alternativa.
	if python3 "$SCRIPT_DIR/qga.py" "$QGA_SOCK" "systemctl poweroff" >/dev/null 2>&1; then
		log "desligamento solicitado pelo agente QEMU"
	else
		qmp '{"execute":"system_powerdown"}' >/dev/null
		log "desligamento solicitado via ACPI"
	fi
	local deadline=$((SECONDS + ${1:-180}))
	while is_running; do
		[ $SECONDS -lt $deadline ] || die "VM não desligou no prazo"
		sleep 2
	done
	log "VM desligada"
}

require_off() { ! is_running || die "desligue a VM antes (lab.sh powerdown)"; }

cmd_snapshot_save() {
	local name="${1:?uso: snapshot-save NOME}"
	require_off
	if "$QEMU_IMG" snapshot -l -U "$DISK" | awk 'NR>2 {print $2}' | grep -qx "$name"; then
		log "snapshot $name já existe; nada feito"
		return
	fi
	"$QEMU_IMG" snapshot -c "$name" "$DISK"
	cp "$(vars_file)" "$SNAP_DIR/$name.vars"
	log "snapshot $name criado"
}

cmd_snapshot_restore() {
	local name="${1:?uso: snapshot-restore NOME}"
	require_off
	"$QEMU_IMG" snapshot -a "$name" "$DISK"
	[ -f "$SNAP_DIR/$name.vars" ] && cp "$SNAP_DIR/$name.vars" "$(vars_file)"
	log "snapshot $name restaurado"
}

# -U: leitura compartilhada, funciona com a VM ligada
cmd_snapshot_list() { "$QEMU_IMG" snapshot -l -U "$DISK"; }

cmd_status() {
	if is_running; then echo "em execução (pid $(cat "$PIDFILE"))"; else echo "desligada"; fi
	[ -f "$DISK" ] && "$QEMU_IMG" info -U "$DISK" | grep -E 'virtual size|disk size'
	[ -f "$DISK" ] && cmd_snapshot_list
	return 0
}

usage() {
	cat >&2 <<'EOF'
uso: lab.sh COMANDO
  check                 verifica dependências, firmware OVMF e /dev/kvm
  fetch-iso             baixa e verifica (GPG + SHA-256) a ISO da Fedora Kinoite (exige FEDORA_KEY_FPR)
  create                cria disco qcow2 e variáveis UEFI
  install               instalação interativa da ISO (BOOT_ISO=arquivo.iso; padrão: Kinoite de referência)
  run                   inicia a VM em primeiro plano (BOOT_ISO=arquivo.iso para dar boot pela mídia)
  wait-ssh [SEG]        aguarda SSH (chave do laboratório)
  ssh [CMD...]          executa comando na VM
  screenshot ARQ.png    captura a tela da VM
  pixel X Y             cor "R G B" de um pixel da tela
  key COMBO...          envia teclas (qcodes QEMU; ex.: meta_l alt-tab ret)
  mouse ...             ponteiro: move X Y (0..32767) | down|up|click [botão] | dblclick | wheel up|down
  link on|off           conecta/desconecta o cabo de rede virtual
  ga COMANDO            executa como root na VM pelo agente QEMU (sem rede)
  kill                  encerra o QEMU à força (último recurso)
  powerdown [SEG]       desligamento ordenado
  snapshot-save NOME | snapshot-restore NOME | snapshot-list
  status
EOF
	exit 64
}

main() {
	local c="${1:-}"; shift || true
	WORK="$(mktemp -d)"
	trap 'rm -rf "$WORK"' EXIT
	case "$c" in
		check) cmd_check ;;
		fetch-iso) cmd_fetch_iso ;;
		create) cmd_create ;;
		install) cmd_install ;;
		run) cmd_run ;;
		wait-ssh) cmd_wait_ssh "$@" ;;
		ssh) ssh_vm "$@" ;;
		screenshot) cmd_screenshot "$@" ;;
		pixel) cmd_pixel "$@" ;;
		key) cmd_key "$@" ;;
		mouse) cmd_mouse "$@" ;;
		link) cmd_link "$@" ;;
		ga) cmd_ga "$@" ;;
		kill) cmd_kill ;;
		powerdown) cmd_powerdown "$@" ;;
		snapshot-save) cmd_snapshot_save "$@" ;;
		snapshot-restore) cmd_snapshot_restore "$@" ;;
		snapshot-list) cmd_snapshot_list ;;
		status) cmd_status ;;
		*) usage ;;
	esac
}

main "$@"
