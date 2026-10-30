#!/usr/bin/env bash
# Prepara o disco do Luma recém-instalado para o teste do CI, com a VM DESLIGADA (scripts/ci/vm-test.sh):
#   [MODO=medicao] prepare-disk.sh DISCO.qcow2|DISCO.raw
# Grava no /etc do deployment ostree o roteiro tests/vm/guest (unit + script), o login automático do
# usuário "teste" e os rótulos SELinux (xattr security.selinux; o host não precisa ter SELinux ativo).
# Confere cada arquivo e imprime, como evidência, hostname, idioma e teclado gravados pelo instalador.
# Só para a instalação de teste: a ISO entregue ao usuário não passa por aqui. Executar como root.
set -euo pipefail
disk="$(realpath "${1:?uso: prepare-disk.sh DISCO.qcow2|DISCO.raw}")"
GUEST="$(cd "$(dirname "$0")/guest" && pwd)"
[ "$(id -u)" = 0 ] || { echo "prepare-disk.sh: execute como root" >&2; exit 77; }
say() { printf '[prepare-disk] %s\n' "$*"; }
tmp="$(mktemp -d "$(dirname "$disk")/prepare.XXXXXX")"
raw="$disk"; loop=""; mnt="$tmp/mnt"
cleanup() {
	mountpoint -q "$mnt" 2>/dev/null && umount "$mnt"
	[ -n "$loop" ] && losetup -d "$loop" 2>/dev/null
	rm -rf "$tmp"
}
trap cleanup EXIT
case "$disk" in
	*.qcow2) raw="$tmp/disk.raw"; qemu-img convert -O raw "$disk" "$raw" ;;
esac
loop="$(losetup -fP --show "$raw")"
udevadm settle 2>/dev/null || true
part=""
for p in "$loop"p* "$loop"; do
	[ -b "$p" ] || continue
	if [ "$(blkid -o value -s TYPE "$p" 2>/dev/null)" = btrfs ]; then part="$p"; break; fi
done
[ -n "$part" ] || { say "nenhuma partição btrfs em $disk"; lsblk "$loop" || true; exit 1; }
mkdir -p "$mnt"
mount -o subvolid=5 "$part" "$mnt"
mapfile -t etcs < <(compgen -G "$mnt/*/ostree/deploy/*/deploy/*.0/etc"; compgen -G "$mnt/ostree/deploy/*/deploy/*.0/etc")
[ "${#etcs[@]}" -gt 0 ] || { say "deployment ostree não encontrado"; find "$mnt" -maxdepth 3 -type d | head -n 40; exit 1; }
for etc in "${etcs[@]}"; do
	say "deployment: ${etc#"$mnt"}"
	lsattr -d "$etc" 2>/dev/null | sed 's/^/[prepare-disk] atributos: /' || true
	install -d -m 0755 "$etc/luma-ci" "$etc/systemd/system/graphical.target.wants" "$etc/plasmalogin.conf.d"
	# MODO=medicao (scripts/ci/vm-medicao.sh): no lugar do roteiro funcional, só a medição de RAM e boot (F5-03)
	roteiro=luma-ci-checks.sh; [ "${MODO:-}" = medicao ] && roteiro=luma-ci-medicao.sh
	install -m 0755 "$GUEST/$roteiro" "$etc/luma-ci/luma-ci-checks.sh"
	say "roteiro: $roteiro"
	install -m 0644 "$GUEST/luma-ci-checks.service" "$etc/systemd/system/luma-ci-checks.service"
	ln -sfn ../luma-ci-checks.service "$etc/systemd/system/graphical.target.wants/luma-ci-checks.service"
	# Login automático: arquivo principal e drop-in (relatos de que só um deles é lido, KDE bug 522006)
	printf '[Autologin]\nUser=teste\nSession=plasma.desktop\n' >"$etc/plasmalogin.conf"
	cp "$etc/plasmalogin.conf" "$etc/plasmalogin.conf.d/zz-luma-ci.conf"
	python3 - "$etc" <<'PY'
import os, sys
etc = sys.argv[1]
labels = [("luma-ci", "etc_t"), ("luma-ci/luma-ci-checks.sh", "etc_t"),
          ("systemd/system/luma-ci-checks.service", "systemd_unit_file_t"),
          ("systemd/system/graphical.target.wants/luma-ci-checks.service", "systemd_unit_file_t"),
          ("plasmalogin.conf", "etc_t"), ("plasmalogin.conf.d", "etc_t"),
          ("plasmalogin.conf.d/zz-luma-ci.conf", "etc_t")]
bad = 0
for path, kind in labels:
    full = os.path.join(etc, path)
    try:
        os.setxattr(full, "security.selinux", f"system_u:object_r:{kind}:s0".encode() + bytes(1), follow_symlinks=False)
        got = os.getxattr(full, "security.selinux", follow_symlinks=False).rstrip(b"\0").decode()
        print(f"[prepare-disk] rótulo {path}: {got}")
    except OSError as e:
        print(f"[prepare-disk] ERRO rótulo {path}: {e}")
        bad = 1
sys.exit(bad)
PY
	for f in luma-ci/luma-ci-checks.sh systemd/system/luma-ci-checks.service plasmalogin.conf \
		systemd/system/graphical.target.wants/luma-ci-checks.service; do
		[ -e "$etc/$f" ] || { say "ERRO: $f não ficou gravado"; exit 1; }
	done
	# Evidência do que o instalador gravou (F1-08, F6-02), antes do primeiro boot
	say "hostname: $(cat "$etc/hostname" 2>/dev/null || echo '(ausente)')"
	say "locale.conf: $(tr '\n' ' ' <"$etc/locale.conf" 2>/dev/null || echo '(ausente)')"
	say "vconsole.conf: $(tr '\n' ' ' <"$etc/vconsole.conf" 2>/dev/null || echo '(ausente)')"
	say "teclado X11: $(grep -h XkbLayout "$etc"/X11/xorg.conf.d/*.conf 2>/dev/null | tr -s ' ' | tr '\n' ' ' || true)"
	say "usuário: $(grep '^teste:' "$etc/passwd" | cut -d: -f1,3,6 || echo '(ausente)')"
done
umount "$mnt"
losetup -d "$loop"; loop=""
case "$disk" in
	*.qcow2) qemu-img convert -O qcow2 "$raw" "$disk.novo" && mv -f "$disk.novo" "$disk" ;;
esac
say "disco preparado: $disk"
