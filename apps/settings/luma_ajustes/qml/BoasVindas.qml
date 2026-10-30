// SPDX-License-Identifier: GPL-2.0-or-later
// Boas-vindas do Luma (F3-03): aparece no primeiro login; 4 passos curtos; "Concluir" não mostra de novo.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: win
    title: "Boas-vindas ao Luma"
    width: Kirigami.Units.gridUnit * 40
    height: Kirigami.Units.gridUnit * 28
    minimumWidth: Kirigami.Units.gridUnit * 30
    minimumHeight: Kirigami.Units.gridUnit * 24
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    Connections {
        target: backend
        function onError(message) { banner.text = message; banner.visible = true; }
    }

    // Cada passo: título, texto e até dois botões (rótulo + ação de backend)
    readonly property var steps: [
        { title: "Bem-vindo ao Luma",
          text: "Um sistema baseado na Fedora Kinoite: imutável, com SELinux e firewall de entrada fechado. " +
                "As atualizações chegam como uma imagem inteira, e a versão anterior continua disponível no menu de boot.",
          actions: [] },
        { title: "Claro ou escuro",
          text: "Escolha a aparência agora. Cor de destaque, transparência e tamanho do texto ficam no app Ajustes.",
          actions: [{ label: "Escuro", mode: "escuro" }, { label: "Claro", mode: "claro" }, { label: "Abrir Ajustes", action: "ajustes" }] },
        { title: "Jogos",
          text: "O Steam, o Lutris, o Heroic e o Bottles são instalados do Flathub para o seu usuário, sem senha de administrador. " +
                "O GameMode e o MangoHud já vêm no sistema.",
          actions: [{ label: "Instalar uma loja de jogos", action: "jogos" }, { label: "Monitor do Sistema", action: "monitor" }] },
        { title: "Tudo pronto",
          text: "Atualizações e aplicativos ficam na Central de Programas. Para ver esta tela de novo: \"Boas-vindas\" no menu.",
          actions: [{ label: "Ver atualizações", action: "atualizacoes" }] }
    ]
    property int step: 0

    pageStack.initialPage: Kirigami.Page {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit * 2
            spacing: Kirigami.Units.largeSpacing

            Kirigami.InlineMessage {
                id: banner
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                showCloseButton: true
                visible: false
            }

            Kirigami.Icon {
                source: "luma-logo"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                level: 1
                text: win.steps[win.step].title
            }
            QQC.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: win.steps[win.step].text
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: win.steps[win.step].actions
                    delegate: QQC.Button {
                        required property var modelData
                        text: modelData.label
                        onClicked: modelData.mode ? backend.setMode(modelData.mode) : backend.welcomeAction(modelData.action)
                    }
                }
            }
            Item { Layout.fillHeight: true }

            // Navegação: indicador de passos, Voltar e Próximo/Concluir
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: win.steps.length
                    delegate: Rectangle {
                        required property int index
                        width: Kirigami.Units.smallSpacing * 2
                        height: width
                        radius: width / 2
                        color: index === win.step ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.25)
                    }
                }
                Item { Layout.fillWidth: true }
                QQC.Button {
                    text: "Voltar"
                    enabled: win.step > 0
                    onClicked: win.step -= 1
                }
                QQC.Button {
                    text: win.step < win.steps.length - 1 ? "Próximo" : "Concluir"
                    highlighted: true
                    onClicked: win.step < win.steps.length - 1 ? win.step += 1 : backend.finishWelcome()
                }
            }
        }
    }
}
