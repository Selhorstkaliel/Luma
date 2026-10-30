#!/usr/bin/env bash
# Dual boot (F6-04), DENTRO da VM do CI (scripts/ci/vm-dualboot.sh): o Luma foi instalado no espaço livre de
# um disco que já tinha um "Windows" simulado (ESP com \EFI\Microsoft\Boot\bootmgfw.efi e partição NTFS).
# Confere a sessão, lê a partição NTFS só para leitura e registra o que o carregador oferece; depois desliga.
set -uo pipefail
U=teste
TTY=/dev/ttyS0
say() { printf 'LUMACI %s\n' "$*" | tr -d '\r' >"$TTY"; }
res() { say "RESULT $1 $2 $3"; }
say "BEGIN dualboot $(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"')"
for _ in $(seq 1 150); do pgrep -u "$U" -x plasmashell >/dev/null && break; sleep 2; done
if pgrep -u "$U" -x plasmashell >/dev/null; then
	res F6-04-BOOT PASSOU "Luma iniciou até a sessão do usuário novo (Secure Boot: $(mokutil --sb-state 2>/dev/null | head -n1))"
else
	res F6-04-BOOT FALHOU "sem plasmashell em 300 s"
fi
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS 2>&1 | while IFS= read -r l; do say "DATA DISCO $l"; done
efibootmgr 2>&1 | while IFS= read -r l; do say "DATA EFI $l"; done
# A partição do outro sistema continua legível pelo Luma (ntfs3 do kernel, só leitura)
ntfs="$(blkid -t LABEL=Windows -o device 2>/dev/null | head -n1)"
txt=""
if [ -n "$ntfs" ] && mkdir -p /run/luma-ci-ntfs && mount -t ntfs3 -o ro "$ntfs" /run/luma-ci-ntfs 2>/dev/null; then
	txt="$(head -c 80 /run/luma-ci-ntfs/luma-ci-marcador.txt 2>/dev/null)"
	umount /run/luma-ci-ntfs
fi
res F6-04-NTFS INFO "partição ${ntfs:-não encontrada}; marcador lido pelo Luma: ${txt:-nada}"
# [H] Num sistema bootc o grub.cfg é estático (sem os-prober): o Windows aparece no menu do firmware, não no GRUB
menu="$(grep -rlis 'windows\|bootmgfw' /boot/grub2 /boot/loader/entries /boot/efi/EFI/fedora 2>/dev/null | tr '\n' ' ')"
res F6-04-MENU INFO "Windows citado na configuração do carregador: ${menu:-não}"
say "END dualboot"
systemctl poweroff
