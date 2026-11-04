# 0009: Build, CI e assinatura de imagens

Status: **parcial**. O build e o teste no CI estão aceitos. **Publicar em registro e assinar continuam pendentes de autorização do usuário.**

## Contexto
O host de desenvolvimento tem 7,7 GiB de RAM, e o WSL já travou durante um build no LUMA-OS (etapa 8, falha1). Uma imagem derivada da Kinoite ocupa vários GB. O ambiente de nuvem desta sessão não acessa `quay.io` nem `fedoraproject.org`, então o build não foi executado nela.

## Decisão (aceita)
- O CI do GitHub Actions (`.github/workflows/ci.yml`) roda lint e testes unitários, depois `podman build` da imagem, `tests/image/test-image.sh` dentro do container e o manifesto de pacotes como artefato.
- O CI tem `permissions: contents: read`, **sem login em registro, sem push e sem assinatura**.
- Base por digest (F6-08), revisto em 2026-11-04: o quay.io apagou os digests fixados da Kinoite e da fedora:44 em menos de um dia (ci #89 e #91, "manifest unknown"), então o repositório guarda só o último padrão conhecido. Todo workflow de build resolve o digest atual com `scripts/ci/atualizar-base.sh --gravar` antes do `podman build` e o build usa esse digest exato em todo o run; ele fica no log e nas labels `org.luma.base.digest`/`org.luma.tools.digest` da imagem publicada. Reprodutibilidade estrita exigiria espelhar a base no GHCR (publicação nova, pendente de autorização).

## Pendente de autorização (não implementar antes)
- Publicar a imagem no GHCR (`ghcr.io/selhorstkaliel/luma`). Publicar torna a imagem pública e cria um canal de atualização usado pelas máquinas instaladas.
- Assinar com cosign (chave em GitHub Secrets, nunca no repositório) e ter uma política `containers/policy.json` na imagem que recuse imagem não assinada.
- Criar um ambiente de release com aprovação manual e branch protegida, porque o CI passa a ser o ponto único de confiança.

## Consequências
- Sem publicação, a atualização de uma máquina de teste é feita a partir de uma imagem local (`bootc switch --transport containers-storage`) [H].
- A reprodutibilidade é comparada pelo manifesto (`rpm -qa`) entre builds, como na 0005 do LUMA-OS. Não se promete reprodução bit a bit.

## Atualização em 2026-10-29
Perguntado de novo, com as consequências explicadas (imagem pública e permanente no GHCR, chave cosign gerada pelo usuário e guardada como segredo do repositório). Resposta do usuário: **"ainda não"**. Continua sem registro e sem assinatura. Atualização assinada e reversão (TESTS F5-05) seguem BLOQUEADAS por esta decisão.

## Atualização em 2026-10-31: publicação autorizada
O usuário escolheu **"Publicar agora"**. Status: **aceita**, com a execução dependendo de um passo dele (abaixo).

### Como fica
- **Onde:** o `iso.yml` publica `ghcr.io/selhorstkaliel/luma`, com as tags `44` e `44-<commit>`.
- **Quando:** só no push do branch de desenvolvimento e só depois de passarem os testes da imagem, a ISO, o boot com Secure Boot e o sistema instalado. É exatamente a imagem testada.
- **Assinatura:** cosign com **par de chaves do projeto**, assinando pelo digest. A chave privada fica em `COSIGN_PRIVATE_KEY`/`COSIGN_PASSWORD` (segredos do repositório) e a pública em `configs/etc/pki/containers/luma-cosign.pub`. Sem esses itens o CI **não publica** e avisa no run. Nunca publica imagem sem assinatura.
- **Política na imagem** (`build/image/build.sh`, conferida pelo F6-I02): `ghcr.io/selhorstkaliel/luma` só é aceita com `sigstoreSigned` pela chave do projeto. As outras origens (Flatpak, toolbox) seguem a política da base.
- **Por que par de chaves, e não assinatura sem chave do GitHub [F]:** o `containers-policy.json` (containers/image) só aceita `subjectEmail` no bloco `fulcio`. A identidade de workflow do GitHub não pode ser exigida pelo `bootc`/podman no sistema instalado. É o mesmo motivo de o Universal Blue usar par de chaves.

### Passo do usuário (necessário uma vez)
1. No computador: `sudo dnf install cosign` e `cosign generate-key-pair` (pede uma senha; gera `cosign.key` e `cosign.pub`). Guarde `cosign.key` e a senha fora do repositório.
2. No GitHub, em Settings > Secrets and variables > Actions, crie os segredos:
   - `COSIGN_PRIVATE_KEY`, com o conteúdo de `cosign.key`;
   - `COSIGN_PASSWORD`, com a senha.
3. Envie o conteúdo de `cosign.pub`, que é público, para entrar em `configs/etc/pki/containers/luma-cosign.pub`.
4. Depois da primeira publicação: GitHub > Packages > luma > Package settings > visibilidade **Public**. [H] O pacote novo nasce privado, e o CI avisa se ele continuar privado.

### Riscos aceitos
- O CI vira o ponto único de confiança: quem tiver escrita no repositório publica.
- A chave privada vazada permite assinar imagem maliciosa; a mitigação é trocar o par e publicar a nova chave pública numa imagem.
- A imagem é pública e permanece em cache mesmo se apagada.
