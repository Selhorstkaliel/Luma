# 0011: ISO de instalação e entrega por artefato do CI

Status: **aceita pelo usuário** em 2026-10-28 (Fase 1, incremento 1).

## Contexto
A Fase 0 terminou com a imagem bootc do Luma construída e testada no CI (12/12, run 40620197044), mas sem ISO. O usuário pediu a Fase 1 e uma ISO.

## Fatos (pesquisa de 2026-10-28)
- O `bootc-image-builder` foi arquivado e substituído pelo CLI unificado `image-builder` do osbuild (container `ghcr.io/osbuild/image-builder-cli`). A referência da imagem passou de argumento posicional para `--bootc-ref`.
- O tipo recomendado para ISO é `bootc-installer`. Ele recebe uma imagem de instalador com Anaconda (`--bootc-ref`) e a imagem a instalar (`--bootc-installer-payload-ref`). O tipo `anaconda-iso` está marcado para remoção.
- Existe um relato aberto (osbuild/image-builder-cli#421) de falha "unset vendor" nos tipos de instalador a partir de imagens Fedora. Não verifiquei se já foi corrigido.

## Fatos do primeiro build (run iso #1, 40625332809)
- A imagem de instalador foi construída: o `dnf` funciona na Kinoite 44 e instalou o Anaconda 44.30, com `anaconda-dracut` e `anaconda-install-env-deps`.
- O image-builder **não aceita mais** o tipo `anaconda-iso`. A própria mensagem de erro indica o bootc-image-builder.
- O armazenamento de containers precisa estar no **mesmo caminho** no host e dentro da ferramenta (`/var/lib/containers/storage`). Mover o `graphroot` quebra com "database configuration mismatch". O workflow passou a usar bind mount.

## Fatos do segundo build (run iso #2, 40626540431)
- O `bootc-installer` do image-builder falhou (log de 79 bytes, ainda não lido). A ISO saiu do fallback `anaconda-iso` do bootc-image-builder, cuja imagem ainda está disponível em `quay.io/centos-bootc/bootc-image-builder:latest`.
- ISO: 4.503.046.144 bytes. O runner `ubuntu-24.04` do GitHub tem `/dev/kvm`, e o smoke test de boot com Secure Boot rodou.
- **Consequência:** hoje a ISO depende de uma ferramenta arquivada. Migrar para o `bootc-installer` continua sendo necessário.

## Decisão
- `build/iso/Containerfile.installer` = imagem Luma + `anaconda`, `anaconda-install-env-deps` e `anaconda-dracut` (pacotes exatos ainda são hipótese [H]).
- `build/iso/build-iso.sh` tenta `bootc-installer` (image-builder) e, se falhar, `anaconda-iso` do bootc-image-builder antigo (`quay.io/centos-bootc/bootc-image-builder`, arquivado: a disponibilidade da imagem é hipótese [H]). Grava a ISO, o `.sha256`, um manifesto (tipo, ferramenta e digests) e o log de cada tentativa.
- `.github/workflows/iso.yml` roda o build, os testes da imagem, a ISO e um smoke test de boot em QEMU + OVMF com Secure Boot. Esse teste só roda se o runner tiver `/dev/kvm`; sem ele, fica registrado como não executado.
- **Entrega:** artefato do run com `retention-days: 7` e um `LEIA-ME-PRE-ALPHA.txt`. Autorizado pelo usuário sabendo que o repositório é público e que, por isso, qualquer conta do GitHub pode baixar o arquivo.
- Nada vai para registro de containers (GHCR continua pendente, decisão 0009).

## Consequências e riscos
- A ferramenta é usada pela tag `latest`. O digest de cada build fica no manifesto. Fixar a versão vem depois do primeiro build bem-sucedido.
- A ISO ainda tem identidade visual Fedora no boot e no instalador (logos não trocados) e nenhum tema Luma.
- O instalador apaga o disco escolhido. O aviso e a decisão limitam o uso a VM até haver teste em hardware.
