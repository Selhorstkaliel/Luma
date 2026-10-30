#!/usr/bin/env bash
# Medição de RAM e boot do sistema instalado (F5-03), DENTRO da VM do CI (scripts/ci/vm-medicao.sh).
# Roda igual no Luma e na Kinoite pura: o prepare-disk.sh (MODO=medicao) o instala no lugar do roteiro
# funcional. Em cada boot: espera a sessão do usuário novo, fecha as boas-vindas, fica 120 s parado e mede;
# reinicia até o 3º boot e então desliga. Nada além de medir: sem apps, sem rede de teste, sem capturas.
set -uo pipefail
U=teste
TTY=/dev/ttyS0
BOOTS=3
mkdir -p /var/luma-ci
say() { printf 'LUMACI %s\n' "$*" | tr -d '\r' >"$TTY"; }
n=$(( $(cat /var/luma-ci/boot-n 2>/dev/null || echo 0) + 1 ))
echo "$n" >/var/luma-ci/boot-n
say "BEGIN medicao boot=$n $(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"')"
for _ in $(seq 1 150); do pgrep -u "$U" -x plasmashell >/dev/null && break; sleep 2; done
if ! pgrep -u "$U" -x plasmashell >/dev/null; then
	say "MED boot=$n erro=sem-sessao"
	systemctl poweroff; exit 0
fi
pkill -u "$U" -f plasma-welcome || true
sleep 120
# Fim do boot do userspace (µs desde o início do kernel), sem depender do texto do systemd-analyze
fin="$(busctl get-property org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager FinishTimestampMonotonic | awk '{print $2}')"
mem() { awk -v k="$1:" '$1 == k {print int($2 / 1024)}' /proc/meminfo; }
total="$(mem MemTotal)"; avail="$(mem MemAvailable)"; shmem="$(mem Shmem)"
say "MED boot=$n usada_mib=$((total - avail)) disponivel_mib=$avail shmem_mib=$shmem boot_s=$(awk -v u="$fin" 'BEGIN {printf "%.1f", u / 1000000}')"
# PSS por processo (divide a memória compartilhada entre quem a usa): os 15 maiores
for d in /proc/[0-9]*; do
	p="$(awk '$1 == "Pss:" {print $2}' "$d/smaps_rollup" 2>/dev/null)"
	[ -n "$p" ] && printf '%s %s\n' "$p" "$(cat "$d/comm" 2>/dev/null)"
done | sort -rn | head -n 15 | while read -r kib comm; do say "MEDPROC boot=$n pss_kib=$kib comm=$comm"; done
if [ "$n" -lt "$BOOTS" ]; then
	say "REBOOT boot=$n"
	systemctl reboot
else
	say "END medicao"
	systemctl poweroff
fi
