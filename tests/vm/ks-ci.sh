#!/usr/bin/env bash
# Gera a configuração do instalador SÓ PARA O TESTE DO CI (scripts/ci/vm-test.sh):
#   ks-ci.sh SAIDA.toml
# Parte do kickstart real (build/iso/config.toml: idioma, teclado, fuso, hostname) e acrescenta o que uma
# instalação sem ninguém na frente precisa: apagar o disco VIRTUAL da VM, criar o usuário de teste e
# desligar no fim. Os arquivos do roteiro entram depois, pelo host, com o disco desligado
# (tests/vm/prepare-disk.sh): gravar no %post falhou no run iso #15 sem mostrar o motivo.
# A ISO feita com este arquivo é destrutiva: o CI a usa numa VM e a apaga; ela nunca vai para o artefato.
set -euo pipefail
out="${1:?uso: ks-ci.sh SAIDA.toml}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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

# Só diagnóstico (por que o /etc do deployment não aceitou escrita no run iso #15)
%post --nochroot --log=/dev/ttyS0
for etc in /mnt/sysroot/ostree/deploy/*/deploy/*/etc; do
	echo "luma-ci-diag: \$etc"
	ls -ld "\$etc" 2>&1 | sed 's/^/luma-ci-diag: /'
	touch "\$etc/.luma-ci-escrita" 2>&1 | sed 's/^/luma-ci-diag: escrita: /' && rm -f "\$etc/.luma-ci-escrita"
done
findmnt -R /mnt/sysroot 2>&1 | sed 's/^/luma-ci-diag: /'
%end
'''
EOF
grep -q "'''" <<<"$base" && { echo "ks-ci.sh: três aspas simples no conteúdo" >&2; exit 1; }
echo "ks-ci.sh: $out ($(wc -c <"$out") bytes)"
