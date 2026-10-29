#!/usr/bin/env bash
# Roda DENTRO do Luma instalado na VM do CI (scripts/ci/vm-test.sh), como root, depois do login automático
# do usuário de teste. Só existe na instalação de teste: o kickstart do CI (tests/vm/ks-ci.sh) o copia no
# %post; a ISO entregue ao usuário não tem nada disto.
# Fala com o host pela porta serial (linhas "LUMACI ...") e espera respostas no servidor HTTP do host
# (10.0.2.2:8099, rede user do QEMU): "SHOT nome" pede captura de tela; "NMAP ip" pede a varredura de fora.
# Cada critério vira "LUMACI RESULT ID PASSOU|FALHOU|INFO detalhe"; quem decide o veredito é o host.
set -uo pipefail
U=teste
HOSTSRV=http://10.0.2.2:8099
TTY=/dev/ttyS0
mkdir -p /var/luma-ci
say() { printf 'LUMACI %s\n' "$*" | tr -d '\r' >"$TTY"; printf '%s\n' "$*" >>/var/luma-ci/log; }
res() { local id="$1" st="$2"; shift 2; say "RESULT $id $st $*"; }
# Texto longo (evidência) vai para a serial com prefixo, uma linha por vez
dump() { local tag="$1"; shift; "$@" 2>&1 | head -n 400 | while IFS= read -r l; do say "DATA $tag $l"; done; }
wait_host() {
	local _
	for _ in $(seq 1 150); do
		curl -sf -o /dev/null "$HOSTSRV/sync/$1" && return 0
		sleep 2
	done
	say "AVISO o host não respondeu a $1"
	return 1
}
shot() { say "SHOT $1"; wait_host "shot-$1"; }

say "BEGIN $(date -u +%FT%TZ)"
uid="$(id -u "$U" 2>/dev/null || true)"
home="$(getent passwd "$U" | cut -d: -f6)"
asuser() {
	runuser -u "$U" -- env HOME="$home" USER="$U" XDG_RUNTIME_DIR="/run/user/$uid" \
		DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" WAYLAND_DISPLAY=wayland-0 \
		QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE "$@"
}
kread() { asuser kreadconfig6 --file "$1" --group "$2" --key "$3"; }
plasma_js() { asuser qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }

# --- Sistema (F1, F6) -------------------------------------------------------------------------------------
res F1-08 "$([ "$(hostnamectl hostname)" = luma ] && echo PASSOU || echo FALHOU)" "hostname=$(hostnamectl hostname) /etc/hostname=$(cat /etc/hostname 2>/dev/null)"
res SELINUX "$([ "$(getenforce)" = Enforcing ] && echo PASSOU || echo FALHOU)" "getenforce=$(getenforce)"
sbvar="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' 2>/dev/null | head -n1)"
sb="$( [ -n "$sbvar" ] && od -An -t u1 -j4 -N1 "$sbvar" | tr -d ' ' )"
res F1-05 "$([ "$sb" = 1 ] && echo PASSOU || echo FALHOU)" "SecureBoot=${sb:-sem-variavel} ($(mokutil --sb-state 2>&1 | head -n1))"
zone="$(firewall-cmd --get-default-zone 2>&1)"
res FIREWALL "$([ "$zone" = luma ] && echo PASSOU || echo FALHOU)" "zona-padrao=$zone ativas=$(firewall-cmd --get-active-zones 2>&1 | tr '\n' ' ')"
lang="$(sed -n 's/^LANG=//p' /etc/locale.conf | tr -d '"')"
keymap="$(localectl status | sed -n 's/.*X11 Layout: *//p;s/.*VC Keymap: *//p' | tr '\n' ' ')"
tz="$(timedatectl show -p Timezone --value)"
ok=FALHOU; [ "$lang" = pt_BR.UTF-8 ] && grep -qw br <<<"$keymap" && [ "$tz" = America/Sao_Paulo ] && ok=PASSOU
res F6-02 "$ok" "LANG=$lang teclado=[$keymap] fuso=$tz"
dump OSRELEASE cat /etc/os-release
dump BOOTC bootc status
dump FAILED systemctl --failed --no-legend
res BOOT INFO "$(systemd-analyze 2>&1 | head -n1)"

# --- Sessão do usuário novo (F2-01) ------------------------------------------------------------------------
for _ in $(seq 1 150); do pgrep -u "$U" -x plasmashell >/dev/null && break; sleep 2; done
if ! pgrep -u "$U" -x plasmashell >/dev/null; then
	res SESSAO FALHOU "plasmashell do usuário $U não apareceu em 300 s (login automático)"
	dump PLASMALOGIN journalctl -b -u plasmalogin --no-pager
	shot sem-sessao
	say "END"; systemctl poweroff; exit 0
fi
res SESSAO PASSOU "plasmashell do usuário novo $U em execução"
sleep 45   # deixa o Plasma terminar de montar painéis e papel de parede (llvmpipe, sem 3D)
res RAM INFO "$(free -m | awk '/^Mem:/{print "usada="$3"MiB total="$2"MiB"}') (60 s após o login, sem apps abertos)"
shot desktop-usuario-novo
lnf="$(kread kdeglobals KDE LookAndFeelPackage)"
scheme="$(kread kdeglobals General ColorScheme)"
deco="$(kread kwinrc org.kde.kdecoration2 theme)"
panels="$(plasma_js 'print(panels().map(function(p){return p.location+":"+p.widgets().map(function(w){return w.type}).join(",")}).join(" | "))' 2>&1)"
wall="$(plasma_js 'var d=desktops()[0]; d.currentConfigGroup=["Wallpaper","org.kde.image","General"]; print(d.readConfig("Image"))' 2>&1)"
ok=FALHOU
[ "$lnf" = org.luma.dark.desktop ] && grep -q org.luma.controlcenter <<<"$panels" && grep -q icontasks <<<"$panels" && ok=PASSOU
res F2-01 "$ok" "LookAndFeel=$lnf esquema=${scheme:-padrao-do-LnF} decoracao=${deco:-padrao} papel=${wall}"
res PAINEIS INFO "$panels"
res F3-02 "$(grep -q org.luma.controlcenter <<<"$panels" && echo PASSOU || echo FALHOU)" "Central de Controle no painel: $panels"

# --- Ajustes (F3-01) -------------------------------------------------------------------------------------
asuser luma-ajustes >/var/luma-ci/ajustes.log 2>&1 &
sleep 25
shot ajustes-aberto
ajustes_vivo=no; pgrep -u "$U" -f luma-ajustes >/dev/null && ajustes_vivo=yes
pkill -u "$U" -f luma-ajustes || true
# As mesmas listas de comandos que os botões do app executam (luma_ajustes.core), como o usuário, sem senha
apply_out="$(asuser env PYTHONPATH=/usr/share/luma-ajustes python3 - <<'EOF' 2>&1
import subprocess
from luma_ajustes import core
cmds = (core.mode_commands("claro") + core.accent_commands("rosa", "claro") + core.animations_commands(False)
        + core.text_size_commands("Grande") + core.transparency_commands(50))
priv = [c.argv for c in cmds if c.argv[0] in ("sudo", "pkexec", "su", "doas")]
fails = []
for c in cmds:
    r = subprocess.run(c.argv, capture_output=True, text=True, timeout=120)
    if r.returncode != 0 and c.argv[0] not in ("qdbus6", "dbus-send"):
        fails.append(f"{c.description}: rc={r.returncode} {r.stderr.strip()[:120]}")
print(f"comandos={len(cmds)} privilegiados={len(priv)} falhas={len(fails)}")
for f in fails:
    print("falha:", f)
EOF
)"
sleep 10
shot ajustes-claro-rosa
lnf2="$(kread kdeglobals KDE LookAndFeelPackage)"; acc="$(kread kdeglobals Luma AccentColor)"
anim="$(kread kdeglobals KDE AnimationDurationFactor)"; font="$(kread kdeglobals General font)"
transl="$(kread kwinrc Plugins translucencyEnabled)"
ok=FALHOU
[ "$ajustes_vivo" = yes ] && grep -q 'privilegiados=0 falhas=0' <<<"$apply_out" && [ "$lnf2" = org.luma.desktop ] \
	&& [ "$acc" = '#EC4899' ] && [ "$anim" = 0 ] && grep -q '^Inter,12' <<<"$font" && [ "$transl" = true ] && ok=PASSOU
res F3-01 "$ok" "janela=$ajustes_vivo $(head -n1 <<<"$apply_out") LnF=$lnf2 destaque=$acc animacao=$anim fonte=$font translucidez=$transl"
dump AJUSTES echo "$apply_out"
asuser luma-appearance escuro >/dev/null 2>&1 || true

# --- Modo desempenho (F2-04) ------------------------------------------------------------------------------
asuser luma-appearance desempenho ligado >/dev/null 2>&1; rc1=$?
b="$(kread kwinrc Plugins blurEnabled)"; c="$(kread kwinrc Plugins contrastEnabled)"; a="$(kread kdeglobals KDE AnimationDurationFactor)"
asuser luma-appearance desempenho desligado >/dev/null 2>&1; rc2=$?
b2="$(kread kwinrc Plugins blurEnabled)"
ok=FALHOU; [ "$rc1$rc2" = 00 ] && [ "$b$c$a" = falsefalse0 ] && [ -z "$b2" ] && ok=PASSOU
res F2-04 "$ok" "ligado: blur=$b contraste=$c animacao=$a; desligado: blur=${b2:-removido} (rc $rc1/$rc2)"

# --- Lume (F7-01) -----------------------------------------------------------------------------------------
lumedir="$home/lume-ci"
asuser mkdir -p "$lumedir"
if curl -sf "$HOSTSRV/lume.tar.gz" | asuser tar -xz -C "$lumedir"; then
	asuser python3 "$lumedir/lume/bin/lumec" run "$lumedir/lume/examples/ola.lume" >/var/luma-ci/lume.log 2>&1 &
	sleep 15
	vivo=no; pgrep -u "$U" -f 'lumec run' >/dev/null && vivo=yes
	shot lume-ola
	pkill -u "$U" -f 'lumec run' || true
	res F7-01 "$([ "$vivo" = yes ] && echo PASSOU || echo FALHOU)" "lumec run ola.lume em execução=$vivo (o host confere o texto da janela por OCR) log=$(head -c 200 /var/luma-ci/lume.log | tr '\n' ' ')"
else
	res F7-01 FALHOU "não baixou lume.tar.gz do host"
fi

# --- Firewall visto de fora (F5-01) -----------------------------------------------------------------------
# Um serviço escutando na 8080 prova que a zona luma recusa a entrada mesmo com algo ouvindo
python3 -m http.server 8080 --bind 0.0.0.0 >/dev/null 2>&1 & listener=$!
sleep 2
tapip=""
for _ in $(seq 1 30); do
	tapip="$(ip -4 -o addr show | awk '$4 ~ /^10\.77\.0\./ {sub("/.*","",$4); print $4; exit}')"
	[ -n "$tapip" ] && break; sleep 2
done
dump SS ss -tulpn
say "NMAP ${tapip:-sem-ip}"
wait_host nmap-done
kill "$listener" 2>/dev/null || true

# --- Jogos (F4-01) ----------------------------------------------------------------------------------------
t0=$(date +%s)
if asuser timeout 1500 luma-jogos instalar steam >/var/luma-ci/jogos.log 2>&1; then
	inst=yes
else
	inst="no(rc=$?)"
fi
has="$(asuser flatpak --user list --app --columns=application 2>/dev/null | grep -x com.valvesoftware.Steam || true)"
res JOGOS-INSTALAR INFO "instalado=$inst app=${has:-ausente} em $(( $(date +%s) - t0 )) s; fim do log: $(tail -n 3 /var/luma-ci/jogos.log | tr '\n' ' ' | cut -c1-200)"
steam_vivo=no
if [ -n "$has" ]; then
	asuser flatpak run com.valvesoftware.Steam >/var/luma-ci/steam.log 2>&1 &
	for _ in $(seq 1 24); do sleep 10; done   # o Steam baixa o próprio cliente na primeira execução
	pgrep -u "$U" -f 'steam' >/dev/null && steam_vivo=yes
	shot steam
fi
res F4-01 "$([ -n "$has" ] && [ "$steam_vivo" = yes ] && echo PASSOU || echo FALHOU)" "instalado=$inst em-execucao=$steam_vivo (o host confere a janela por OCR)"

# --- AVCs e diagnóstico completo (F5-02, F1-09) -----------------------------------------------------------
avc="$(ausearch -m avc,user_avc -ts boot 2>/dev/null | grep -c 'type=.*AVC' || true)"
res F5-02 "$([ "${avc:-0}" = 0 ] && echo PASSOU || echo FALHOU)" "AVCs desde o boot (sessão, Ajustes, Lume, luma-jogos, Steam): ${avc:-0}"
[ "${avc:-0}" = 0 ] || dump AVC ausearch -m avc,user_avc -ts boot -i
luma-diagnostico >/dev/null 2>&1; rc=$?
res F1-09 "$([ "$rc" = 0 ] && [ -s /var/tmp/luma-diagnostico.txt ] && echo PASSOU || echo FALHOU)" "sudo luma-diagnostico rc=$rc"
dump DIAG cat /var/tmp/luma-diagnostico.txt
say "END $(date -u +%FT%TZ)"
sleep 2
systemctl poweroff
