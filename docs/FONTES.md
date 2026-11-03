# Código-fonte do Luma-OS

O Luma-OS é feito de software livre. Muitas dessas licenças (como a GPL) garantem a quem recebe o sistema o direito ao código-fonte correspondente. Este documento diz onde ele está.

## 1. O código do próprio Luma
Todo o código, a arte e a configuração do Luma estão neste repositório: <https://github.com/Selhorstkaliel/Luma>. As licenças de cada arquivo estão em `LICENSES.toml`. O commit de cada imagem publicada aparece na tag (`44-<commit>`) e no rótulo `org.opencontainers.image.source`.

## 2. Os pacotes do Fedora dentro da imagem
A imagem do Luma é construída sobre a Fedora Kinoite, com o digest fixado no `Containerfile` (`ARG BASE_DIGEST`), mais pacotes do Fedora instalados pelo `build/image/build.sh`.
- **Manifesto por imagem:** para cada imagem publicada em `ghcr.io/selhorstkaliel/luma`, o CI gera a lista de todos os pacotes RPM, com versão, licença, pacote-fonte (SRPM) e o endereço do fonte no arquivo de builds do Fedora (`kojipkgs.fedoraproject.org`). A lista vai anexada à imagem como **atestado assinado** com a chave do projeto:
  ```sh
  cosign verify-attestation --key https://raw.githubusercontent.com/Selhorstkaliel/Luma/claude/eager-franklin-mb8qmf/configs/etc/pki/containers/luma-cosign.pub \
    --type https://github.com/Selhorstkaliel/Luma/fontes/v1 ghcr.io/selhorstkaliel/luma:44
  ```
- Num sistema Luma instalado, `rpm -qa --qf '%{NAME} %{SOURCERPM}\n'` mostra o mesmo.

## 3. Oferta escrita
Para cada imagem do Luma distribuída, o projeto entrega, **sob pedido e por pelo menos 3 anos depois da última distribuição daquela imagem**, uma cópia do código-fonte correspondente completo dos pacotes de licença GPL ou similar, por custo não maior que o de fazer a cópia. Peça abrindo uma Issue em <https://github.com/Selhorstkaliel/Luma/issues> com a tag da imagem (por exemplo, `44-1a2b3c4`).

> Aviso: este documento foi escrito para cumprir as obrigações de fonte das licenças livres, mas **não passou por revisão jurídica** [H]. Antes de distribuir o Luma ao público em geral, ele deve ser revisado por alguém de propriedade intelectual.
