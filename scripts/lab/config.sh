# shellcheck shell=bash disable=SC2034  # variáveis usadas por quem faz source
# Configuração do laboratório Luma (edição Fedora). Todas as variáveis podem ser sobrescritas pelo ambiente.
# Herdado de LUMA-OS@44903f2 (scripts/lab/config.sh), trocando a netinst Debian pela ISO da Fedora Kinoite.

# Diretório de dados (ISOs, discos). Fica no sistema de arquivos Linux do WSL, fora do repositório.
: "${LAB_DIR:=/srv/luma-lab}"

# ISO de referência: Fedora Kinoite oficial (decisão 0008). O nome exato do arquivo (ex.: ...-44-1.N.iso)
# é descoberto na listagem do espelho quando FEDORA_ISO fica vazio.
: "${FEDORA_VERSION:=44}"
: "${FEDORA_ISO:=}"
: "${FEDORA_ISO_URL:=https://dl.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Kinoite/x86_64/iso}"
: "${FEDORA_KEYS_URL:=https://fedoraproject.org/fedora.gpg}"
# Impressão digital da chave de assinatura de cada versão, conferida pelo usuário em
# https://fedoraproject.org/security/ em 2026-10-28 (o ID curto de cada chave bate com os 16 últimos dígitos).
# Versão sem chave conferida: fetch-iso se recusa a continuar até FEDORA_KEY_FPR ser informada.
if [ -z "${FEDORA_KEY_FPR:-}" ]; then
	case "$FEDORA_VERSION" in
		44) FEDORA_KEY_FPR=36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6 ;;   # rsa4096/DBFCF71C6D9F90A6, 2025-01-14
		45) FEDORA_KEY_FPR=4F50A6114CD5C6976A7F1179655A4B02F577861E ;;   # rsa4096/655A4B02F577861E, 2025-07-29
		*) FEDORA_KEY_FPR= ;;
	esac
fi

# Perfil lab-desktop (herdado do LUMA-OS: host com 7,7 GiB de RAM, uma VM por vez)
: "${VM_NAME:=lab-desktop}"
: "${VM_CPUS:=4}"
: "${VM_RAM_MB:=3072}"
: "${VM_DISK_SIZE:=64G}"
: "${VM_SSH_PORT:=2222}"
: "${VM_HTTP_PORT:=2280}"          # 127.0.0.1:2280 → porta 8080 da VM (teste de firewall)
: "${VM_VNC_DISPLAY:=0}"          # VNC em 127.0.0.1:5900+N
: "${VM_XRES:=1920}"
: "${VM_YRES:=1080}"
: "${VM_AUDIO:=1}"               # 0 = VM sem placa de som
: "${VM_NET:=1}"                 # 0 = VM sem placa de rede
: "${VM_SECUREBOOT:=1}"           # 1 = OVMF com Secure Boot e chaves Microsoft (como um PC comum)

# Binários (sobrescrevíveis para testar erro de dependência)
: "${QEMU:=qemu-system-x86_64}"
: "${QEMU_IMG:=qemu-img}"

# Firmware UEFI. Vazio = detectar entre os caminhos conhecidos (ovmf_pair em lab.sh).
# Os nomes do pacote edk2-ovmf do Fedora 44 ainda não foram conferidos [H]; informe aqui se a detecção falhar.
: "${OVMF_CODE:=}"
: "${OVMF_VARS_TEMPLATE:=}"

VM_DIR="$LAB_DIR/vms/$VM_NAME"
