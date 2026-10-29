# Recuperação do Luma-OS

O Luma é um sistema **atômico** (bootc/ostree): cada atualização vira uma versão completa nova, e a anterior fica guardada. Este guia diz como voltar atrás quando algo dá errado.

Estado: pré-alpha, só em VM. Os passos com [H] ainda não foram testados no Luma (docs/TESTS.md, F5-05 e Fase 6).

## 1. O sistema inicia, mas algo quebrou depois de uma atualização
```sh
sudo bootc status        # mostra a versão em uso ("booted") e a anterior ("rollback")
sudo bootc rollback      # escolhe a anterior para o próximo boot
sudo systemctl reboot
```
[H] Hoje não há canal de atualização (decisão 0009 pendente), então só existe uma versão e não há para onde voltar.

## 2. O sistema não chega ao desktop
1. Reinicie e, no menu do GRUB, escolha a **segunda entrada**: é a versão anterior.
2. Se o menu não aparecer, segure **Shift** (BIOS) ou aperte **Esc** (UEFI) logo depois do logo do fabricante.
3. Já dentro do sistema que funciona, deixe a versão anterior como padrão: `sudo bootc rollback`.

## 3. Login gráfico não funciona, mas o sistema inicia
- Aperte **Ctrl+Alt+F3**, entre com seu usuário e rode `sudo luma-diagnostico`. A saída fica em `/var/tmp/luma-diagnostico.txt`.
- Para voltar o visual Luma ao padrão no seu usuário: `luma-appearance escuro --reset-layout`.
- Para um PC lento ou uma VM sem 3D: `luma-appearance desempenho ligado`.

## 4. Reinstalar
- Use a ISO do Luma. **Desde o kickstart da Fase 6, o instalador deve perguntar** o disco e o usuário, mas confira sempre a tela de resumo antes de continuar. ISOs anteriores a essa mudança **apagam o disco sozinhas**.
- `/home` e os seus arquivos **não** são preservados se você escolher apagar o disco. Faça backup antes.

## 5. Dual boot (Windows + Luma)
[H] Ainda não testado. O critério da Fase 6 exige um teste em **disco virtual**, numa VM com Windows já instalado, antes de qualquer recomendação. Não instale ao lado de outro sistema num PC real.
