# build/iso/

ISO de instalação do Luma (decisão [0011](../../docs/decisions/0011-iso-instalador.md)).

- `Containerfile.installer`: imagem Luma + Anaconda, usada como instalador pelo tipo `bootc-installer`.
- `build-iso.sh`: roda o `image-builder` do osbuild (tenta `bootc-installer`, depois `anaconda-iso`) e grava ISO, `.sha256`, manifesto e logs.
- `LEIA-ME-PRE-ALPHA.txt`: aviso que acompanha toda ISO (só VM, sem garantias).

No CI: `.github/workflows/iso.yml` (artefato apagado em 7 dias). Localmente, como root, num Linux com podman:
```sh
podman build -t localhost/luma:44 .
podman build -f build/iso/Containerfile.installer -t localhost/luma-installer:44 .
build/iso/build-iso.sh localhost/luma:44 localhost/luma-installer:44 ./saida 0.9.0-dev
```
