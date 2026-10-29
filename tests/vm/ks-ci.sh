#!/usr/bin/env bash
# Gera a configuração do instalador SÓ PARA O TESTE DO CI (scripts/ci/vm-test.sh):
#   ks-ci.sh SAIDA.toml
# Parte do kickstart real (build/iso/config.toml: idioma, teclado, fuso, hostname) e acrescenta o que uma
# instalação sem ninguém na frente precisa: apagar o disco VIRTUAL da VM, criar o usuário de teste e
# desligar no fim. O %post copia tests/vm/guest para a instalação e liga o login automático do usuário teste.
# A ISO feita com este arquivo é destrutiva: o CI a usa numa VM e a apaga; ela nunca vai para o artefato.
set -euo pipefail
out="${1:?uso: ks-ci.sh SAIDA.toml}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
guest_b64="$(tar -C "$ROOT/tests/vm/guest" -cz . | base64 -w 76)"
base="$(python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))["customizations"]["installer"]["kickstart"]["contents"].strip())' "$ROOT/build/iso/config.toml")"
# Literal TOML ('''): o conteúdo vai sem escapes; nada aqui pode conter três aspas simples seguidas
cat >"$out" <<EOF
# GERADO por tests/vm/ks-ci.sh para o teste de instalação do CI. DESTRUTIVO. Não usar em ISO entregue.
[customizations.installer.kickstart]
contents = '''
$base
zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --type=btrfs
rootpw --lock
user --name=teste --groups=wheel --password=luma-ci-teste --plaintext
poweroff

%post --nochroot --log=/dev/ttyS0
set -x
mkdir -p /tmp/luma-ci-guest
base64 -d >/tmp/luma-ci-guest.tgz <<'B64'
$guest_b64
B64
tar -xzf /tmp/luma-ci-guest.tgz -C /tmp/luma-ci-guest
found=0
for etc in /mnt/sysroot/ostree/deploy/*/deploy/*/etc; do
	[ -d "\$etc" ] || continue
	found=1
	install -d -m 0755 "\$etc/luma-ci" "\$etc/systemd/system/graphical.target.wants" "\$etc/plasmalogin.conf.d"
	install -m 0755 /tmp/luma-ci-guest/luma-ci-checks.sh "\$etc/luma-ci/luma-ci-checks.sh"
	install -m 0644 /tmp/luma-ci-guest/luma-ci-checks.service "\$etc/systemd/system/luma-ci-checks.service"
	ln -sf ../luma-ci-checks.service "\$etc/systemd/system/graphical.target.wants/luma-ci-checks.service"
	# Login automático: o arquivo principal e o drop-in (relatos de que só um deles é lido, KDE bug 522006)
	printf '[Autologin]\nUser=teste\nSession=plasma.desktop\n' >"\$etc/plasmalogin.conf"
	cp "\$etc/plasmalogin.conf" "\$etc/plasmalogin.conf.d/zz-luma-ci.conf"
	# Rótulos SELinux explícitos: o ambiente do instalador pode gravar sem rótulo, e o sistema instalado
	# (enforcing) recusaria a unit. Os AVCs que sobrarem aparecem no F5-02.
	python3 - "\$etc" <<'PY'
import os, sys
etc = sys.argv[1]
for path, kind in [("luma-ci", "etc_t"), ("luma-ci/luma-ci-checks.sh", "etc_t"),
                   ("systemd/system/luma-ci-checks.service", "systemd_unit_file_t"),
                   ("systemd/system/graphical.target.wants", "systemd_unit_file_t"),
                   ("systemd/system/graphical.target.wants/luma-ci-checks.service", "systemd_unit_file_t"),
                   ("plasmalogin.conf", "etc_t"), ("plasmalogin.conf.d", "etc_t"),
                   ("plasmalogin.conf.d/zz-luma-ci.conf", "etc_t")]:
    try:
        os.setxattr(os.path.join(etc, path), "security.selinux", f"system_u:object_r:{kind}:s0".encode() + bytes(1),
                    follow_symlinks=False)
    except OSError as e:
        print("luma-ci: rótulo", path, e)
PY
	echo "luma-ci: instalado em \$etc"; grep '^teste:' "\$etc/passwd" || echo "luma-ci: usuário teste ausente em \$etc/passwd"
	cat "\$etc/hostname" 2>/dev/null || echo "luma-ci: sem /etc/hostname"
done
[ "\$found" = 1 ] || { echo "luma-ci: deployment não encontrado em /mnt/sysroot"; ls -la /mnt/sysroot /mnt/sysroot/ostree/deploy 2>&1; }
%end
'''
EOF
grep -q "'''" <<<"$base$guest_b64" && { echo "ks-ci.sh: três aspas simples no conteúdo" >&2; exit 1; }
echo "ks-ci.sh: $out ($(wc -c <"$out") bytes)"
