# 0009: Build, CI e assinatura de imagens

Status: **parcial**. O build e o teste no CI estão aceitos. **Publicar em registro e assinar continuam pendentes de autorização do usuário.**

## Contexto
O host de desenvolvimento tem 7,7 GiB de RAM, e o WSL já travou durante um build no LUMA-OS (etapa 8, falha1). Uma imagem derivada da Kinoite ocupa vários GB. O ambiente de nuvem desta sessão não acessa `quay.io` nem `fedoraproject.org`, então o build não foi executado nela.

## Decisão (aceita)
- O CI do GitHub Actions (`.github/workflows/ci.yml`) roda lint e testes unitários, depois `podman build` da imagem, `tests/image/test-image.sh` dentro do container e o manifesto de pacotes como artefato.
- O CI tem `permissions: contents: read`, **sem login em registro, sem push e sem assinatura**.
- A base fica referenciada por tag na Fase 0. Na Fase 1 passa a ser fixada por digest, com atualização por PR revisado.

## Pendente de autorização (não implementar antes)
- Publicar a imagem no GHCR (`ghcr.io/selhorstkaliel/luma`). Publicar torna a imagem pública e cria um canal de atualização usado pelas máquinas instaladas.
- Assinar com cosign (chave em GitHub Secrets, nunca no repositório) e ter uma política `containers/policy.json` na imagem que recuse imagem não assinada.
- Criar um ambiente de release com aprovação manual e branch protegida, porque o CI passa a ser o ponto único de confiança.

## Consequências
- Sem publicação, a atualização de uma máquina de teste é feita a partir de uma imagem local (`bootc switch --transport containers-storage`) [H].
- A reprodutibilidade é comparada pelo manifesto (`rpm -qa`) entre builds, como na 0005 do LUMA-OS. Não se promete reprodução bit a bit.

## Atualização em 2026-10-29
Perguntado de novo, com as consequências explicadas (imagem pública e permanente no GHCR, chave cosign gerada pelo usuário e guardada como segredo do repositório). Resposta do usuário: **"ainda não"**. Continua sem registro e sem assinatura. Atualização assinada e reversão (TESTS F5-05) seguem BLOQUEADAS por esta decisão.
