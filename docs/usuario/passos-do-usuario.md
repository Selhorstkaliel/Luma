# O que só você pode fazer (passo a passo)

O resto eu faço e acompanho pelo CI. Estes passos dependem de você porque envolvem:

- segredos da sua conta;
- a sua aprovação visual;
- hardware físico.

Todos os comandos são para o seu **Fedora** (o computador onde você já testou a VM).

Ordem recomendada: **A → B → C → D**. Depois de cada passo, me mande o que está em "O que me mandar".

---

## A. Chave de assinatura (cosign): libera a publicação e as atualizações assinadas

**Por quê:** o CI só publica a imagem do Luma no GitHub (`ghcr.io/selhorstkaliel/luma`) se ela estiver assinada com a chave do projeto. Sem a chave, nada é publicado, e não há atualização (`bootc upgrade`) nem volta de versão para testar.

1. Instale o cosign e crie a chave **numa pasta fora do repositório**:
   ```bash
   sudo dnf install -y cosign
   mkdir -p ~/luma-chave && cd ~/luma-chave
   cosign generate-key-pair
   ```
   - Ele pede uma **senha**: escolha uma forte e anote.
   - Saem 2 arquivos: `cosign.key` (**secreto**) e `cosign.pub` (público).
2. Faça backup do `cosign.key` e da senha, por exemplo num pendrive ou num gerenciador de senhas. Se perder, é preciso gerar outro par e publicar a chave nova.
3. No GitHub, crie os dois segredos:
   1. Abra **github.com/Selhorstkaliel/Luma** > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.
   2. Crie `COSIGN_PRIVATE_KEY`. No valor, cole o arquivo inteiro: `cat ~/luma-chave/cosign.key`, copiando da linha `-----BEGIN` até a linha `-----END`.
   3. Crie `COSIGN_PASSWORD`, com a senha do passo 1.
4. **Nunca** mande o `cosign.key` nem a senha no chat, por e-mail ou em commit.

**O que me mandar:** o conteúdo de `cat ~/luma-chave/cosign.pub` (é público) e a frase "segredos criados".

**Depois que eu comitar a chave pública e o CI publicar pela 1ª vez:**

1. Abra github.com/Selhorstkaliel?tab=packages > **luma** > **Package settings** > **Change visibility** > **Public**.
2. Sem isso, os computadores com Luma não conseguem baixar atualizações. O CI avisa se o pacote continuar privado.

---

## B. Revisão visual (aprovar o visual da Fase 2)

**Por quê:** o CI confere configurações (tema, painéis, cores), mas só você pode dizer se a aparência está boa.

1. Instale e autentique o cliente do GitHub (uma vez):
   ```bash
   sudo dnf install -y gh
   gh auth login        # GitHub.com > HTTPS > login pelo navegador
   ```
2. Baixe as evidências do último run `iso` verde:
   ```bash
   gh run list -R Selhorstkaliel/Luma -w iso -s success -L 1
   # anote o número do run (coluna ID) e o commit
   gh run download <ID> -R Selhorstkaliel/Luma -p '*evidencias-vm' -D ~/luma-evidencias
   ```
3. Abra as imagens em `~/luma-evidencias/*/capturas/` e confira cada uma:

   | Captura | O que conferir |
   |---|---|
   | `desktop-usuario-novo.png` | área de trabalho escura (Midnight), barra superior, dock embaixo, papel de parede Luma |
   | `boas-vindas.png` | janela "Boas-vindas ao Luma", legível e sem "Fedora" |
   | `ajustes-aberto.png`, `ajustes-claro-rosa.png` | app Ajustes; tema claro com destaque rosa aplicado |
   | `lume-ola.png` | janela "Olá do Lume" |
   | `steam.png` | tela de login do Steam |
   | `boot-*.png` (pasta `boot/`) | tela de boot com o logotipo Luma |

**O que me mandar:** "aprovo" ou, para cada item que não gostou, o nome da captura e o que mudar (cor, tamanho, posição etc.).

---

## C. (Opcional) Testar a ISO numa VM

**Atenção:** a ISO é pré-alpha. **Só em VM, com disco virtual vazio.** Nunca dê boot com ela no seu notebook real.

1. Baixe a ISO do último run `iso` verde:
   ```bash
   gh run download <ID> -R Selhorstkaliel/Luma -p '*iso-pre-alpha' -D ~/luma-iso
   cd ~/luma-iso/*iso-pre-alpha && sha256sum -c *.sha256    # tem de dizer "OK"
   ```
2. Crie a VM com Secure Boot pelo laboratório do repositório:
   ```bash
   git clone https://github.com/Selhorstkaliel/Luma && cd Luma
   git checkout claude/eager-franklin-mb8qmf
   BOOT_ISO="$(ls ~/luma-iso/*iso-pre-alpha/luma-*.iso)" VM_GUI=1 scripts/lab/lab.sh install
   ```
3. No instalador:
   1. escolha o disco **virtual**;
   2. crie seu usuário;
   3. clique em "Começar a instalação";
   4. reinicie quando terminar.

**O que me mandar:** se instalou e entrou na área de trabalho; prints de qualquer erro.

---

## D. Hardware de teste (jogos, bateria, Windows real, Fase 8)

**Por quê:** a VM do CI não tem placa de vídeo 3D nem bateria. Jogos com FPS, consumo de energia e dual boot com um Windows de verdade só podem ser testados numa máquina física.

**Serve:**
- um **SSD externo USB** de 64 GB ou mais, que possa ser apagado; o notebook dá boot por ele e o disco interno não é tocado;
- **ou** um computador sem dados importantes.

**Nunca:** instalar no disco interno do seu notebook principal. Isso apaga ou mexe no Windows e nos seus arquivos. Eu não faço nem peço isso sem a sua autorização por escrito, para aquele disco específico.

**O que me mandar:** qual opção você tem (SSD externo, com o tamanho, ou máquina descartável, com o modelo). Eu preparo o roteiro de teste para ela.

---

## O que eu continuo fazendo sem você
- **Marca Luma no instalador (F6-05):** a ISO com a marca já instala um sistema que passa em todos os testes. Falta a janela do instalador abrir no modo manual; estou diagnosticando pelo CI.
- Acompanhar cada run do CI, corrigir o que quebrar e registrar tudo em `docs/TESTS.md`.
