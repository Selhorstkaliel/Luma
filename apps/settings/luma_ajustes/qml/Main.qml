// SPDX-License-Identifier: GPL-2.0-or-later
// Ajustes do Luma (mockup luma-escuro.png): barra lateral + página Aparência.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: win
    title: "Ajustes"
    width: Kirigami.Units.gridUnit * 50
    height: Kirigami.Units.gridUnit * 36
    minimumWidth: Kirigami.Units.gridUnit * 36
    minimumHeight: Kirigami.Units.gridUnit * 28
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    Connections {
        target: backend
        function onError(message) { banner.text = message; banner.visible = true; }
    }

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Barra lateral
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                Kirigami.Theme.colorSet: Kirigami.Theme.Window
                Kirigami.Theme.inherit: false
                color: Kirigami.Theme.backgroundColor
                ListView {
                    id: sidebar
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing
                    model: backend.sections
                    currentIndex: paginaInicial === "drivers" ? 2 : 1
                    keyNavigationEnabled: true
                    delegate: QQC.ItemDelegate {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: Kirigami.Units.gridUnit * 2.6
                        highlighted: ListView.isCurrentItem
                        icon.name: modelData.icon
                        text: modelData.label
                        background: Rectangle {
                            radius: Kirigami.Units.cornerRadius * 2
                            color: parent.highlighted ? Kirigami.Theme.highlightColor
                                   : parent.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.06) : "transparent"
                        }
                        onClicked: {
                            if (modelData.id === "aparencia" || modelData.id === "drivers") {
                                sidebar.currentIndex = index;
                                if (modelData.id === "drivers" && backend.drivers.length === 0) backend.refreshDrivers();
                            } else {
                                backend.openSection(modelData.id);
                            }
                        }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: backend.sections[sidebar.currentIndex] && backend.sections[sidebar.currentIndex].id === "drivers" ? 1 : 0
                Component.onCompleted: if (paginaInicial === "drivers") backend.refreshDrivers()

            // Página Aparência
            QQC.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing * 2
                    Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

                    Kirigami.InlineMessage {
                        id: banner
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        Layout.rightMargin: Kirigami.Units.gridUnit * 2
                        type: Kirigami.MessageType.Error
                        visible: false
                    }

                    ColumnLayout {
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Heading { level: 1; text: "Aparência" }
                        QQC.Label { text: "Personalize a aparência do Luma e torne o seu espaço único."; opacity: 0.75 }
                    }

                    // Cartões Claro / Escuro
                    RowLayout {
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        Layout.rightMargin: Kirigami.Units.gridUnit * 2
                        spacing: Kirigami.Units.gridUnit
                        ModeCard {
                            mode: "claro"; label: "Claro"
                            wallpaper: "file:///usr/share/wallpapers/Luma/contents/images/1366x768.png"
                            windowColor: "#F6F8FD"; dockColor: "#ECF1FA"
                            selected: backend.mode === "claro"
                            onChosen: backend.setMode("claro")
                        }
                        ModeCard {
                            mode: "escuro"; label: "Escuro"
                            wallpaper: "file:///usr/share/wallpapers/Luma/contents/images_dark/1366x768.png"
                            windowColor: "#131A36"; dockColor: "#0F2245"
                            selected: backend.mode === "escuro"
                            onChosen: backend.setMode("escuro")
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        Layout.rightMargin: Kirigami.Units.gridUnit * 2
                    }

                    // Cor de destaque
                    ColumnLayout {
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        spacing: Kirigami.Units.largeSpacing
                        QQC.Label { text: "Cor de destaque"; font.weight: Font.DemiBold }
                        Row {
                            spacing: Kirigami.Units.gridUnit
                            Repeater {
                                model: backend.accents
                                delegate: QQC.AbstractButton {
                                    required property var modelData
                                    width: Kirigami.Units.gridUnit * 2.2
                                    height: width
                                    Accessible.name: "Cor " + modelData.name
                                    checked: backend.accent === modelData.name
                                    onClicked: backend.setAccent(modelData.name)
                                    background: Rectangle {
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: parent.checked || parent.visualFocus ? 3 : 0
                                        border.color: Kirigami.Theme.focusColor
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            radius: width / 2
                                            color: modelData.color
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Transparência, animações, tamanho do texto
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        Layout.rightMargin: Kirigami.Units.gridUnit * 2
                        Layout.bottomMargin: Kirigami.Units.gridUnit * 2
                        implicitHeight: options.implicitHeight + Kirigami.Units.largeSpacing * 2
                        radius: Kirigami.Units.cornerRadius * 3
                        Kirigami.Theme.colorSet: Kirigami.Theme.View
                        Kirigami.Theme.inherit: false
                        color: Kirigami.Theme.backgroundColor
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

                        ColumnLayout {
                            id: options
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.largeSpacing

                            OptionRow {
                                icon: "transform-scale"
                                title: "Transparência"
                                subtitle: "Controla o nível de transparência das janelas e elementos."
                                RowLayout {
                                    QQC.Slider {
                                        id: transparency
                                        from: 0; to: 100; stepSize: 10
                                        value: backend.transparency
                                        Accessible.name: "Transparência"
                                        onPressedChanged: if (!pressed) backend.setTransparency(value)
                                    }
                                    QQC.Label { text: Math.round(transparency.value) + "%"; Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5 }
                                }
                            }
                            Kirigami.Separator { Layout.fillWidth: true }
                            OptionRow {
                                icon: "games-config-theme"
                                title: "Animações"
                                subtitle: "Deixa a interface mais fluida e dinâmica."
                                QQC.Switch {
                                    checked: backend.animations
                                    Accessible.name: "Animações"
                                    onToggled: backend.setAnimations(checked)
                                }
                            }
                            Kirigami.Separator { Layout.fillWidth: true }
                            OptionRow {
                                icon: "format-font-size-more"
                                title: "Tamanho do texto"
                                subtitle: "Ajusta o tamanho do texto em todo o sistema."
                                QQC.ComboBox {
                                    model: backend.textSizes
                                    currentIndex: backend.textSizes.indexOf(backend.textSize)
                                    Accessible.name: "Tamanho do texto"
                                    onActivated: index => backend.setTextSize(backend.textSizes[index])
                                }
                            }
                        }
                    }
                }
            }

            // Página Hardware e drivers (F3-06, decisão 0014): detecta e pergunta; nada roda sem o diálogo
            QQC.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing
                    Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }
                    RowLayout {
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        Layout.rightMargin: Kirigami.Units.gridUnit * 2
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Heading { level: 1; text: "Hardware e drivers" }
                            QQC.Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                opacity: 0.75
                                text: "O que o Luma encontrou no seu computador. Nada é instalado sem você confirmar. "
                                      + "O driver proprietário da NVIDIA não faz parte do Luma."
                            }
                        }
                        QQC.Button {
                            text: backend.driversBusy ? "Procurando…" : "Procurar de novo"
                            icon.name: "view-refresh"
                            enabled: !backend.driversBusy
                            onClicked: backend.refreshDrivers()
                        }
                    }
                    QQC.BusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        running: backend.driversBusy
                        visible: running
                    }
                    Repeater {
                        model: backend.drivers
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.gridUnit * 2
                            Layout.rightMargin: Kirigami.Units.gridUnit * 2
                            implicitHeight: linha.implicitHeight + Kirigami.Units.largeSpacing * 2
                            radius: Kirigami.Units.cornerRadius * 3
                            Kirigami.Theme.colorSet: Kirigami.Theme.View
                            Kirigami.Theme.inherit: false
                            color: Kirigami.Theme.backgroundColor
                            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                            RowLayout {
                                id: linha
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.largeSpacing
                                spacing: Kirigami.Units.largeSpacing
                                Kirigami.Chip {
                                    checkable: false
                                    closable: false
                                    text: ({ "ok": "OK", "info": "INFO", "pendente": "FALTA", "sem_suporte": "SEM SUPORTE" })[modelData.estado] || modelData.estado
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    QQC.Label { text: modelData.dispositivo; font.weight: Font.DemiBold; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                    QQC.Label { text: modelData.detalhe; opacity: 0.7; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                }
                                QQC.Button {
                                    visible: !!modelData.acao
                                    text: modelData.acao ? modelData.acao.rotulo : ""
                                    onClicked: {
                                        confirmar.itemId = modelData.id;
                                        confirmar.subtitle = modelData.acao.comandos.map(c => c.join(" ")).join("\n");
                                        confirmar.title = modelData.acao.rotulo;
                                        confirmar.open();
                                    }
                                }
                            }
                        }
                    }
                    QQC.Label {
                        Layout.leftMargin: Kirigami.Units.gridUnit * 2
                        visible: !backend.driversBusy && backend.drivers.length === 0
                        text: "Clique em \"Procurar de novo\" para detectar o hardware."
                        opacity: 0.7
                    }
                    Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
                }
            }
            }
        }
    }

    Kirigami.PromptDialog {
        id: confirmar
        property string itemId
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: "Executar"
                icon.name: "dialog-ok-apply"
                onTriggered: { backend.applyDriver(confirmar.itemId); confirmar.close(); }
            },
            Kirigami.Action {
                text: "Cancelar"
                icon.name: "dialog-cancel"
                onTriggered: confirmar.close()
            }
        ]
    }

    component ModeCard: QQC.AbstractButton {
        id: card
        property string mode
        property string label
        property url wallpaper
        property color windowColor
        property color dockColor
        property bool selected: false
        signal chosen()
        Layout.fillWidth: true
        implicitHeight: Kirigami.Units.gridUnit * 12
        checked: selected
        Accessible.name: "Tema " + label
        onClicked: chosen()
        background: Rectangle {
            radius: Kirigami.Units.cornerRadius * 3
            color: Qt.alpha(Kirigami.Theme.textColor, 0.04)
            border.width: card.selected || card.visualFocus ? 3 : 1
            border.color: card.selected || card.visualFocus ? Kirigami.Theme.focusColor : Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.smallSpacing
                clip: true
                Image {
                    anchors.fill: parent
                    source: card.wallpaper
                    fillMode: Image.PreserveAspectCrop
                }
                // Miniatura de janela e dock
                Rectangle {
                    x: parent.width * 0.2; y: parent.height * 0.18
                    width: parent.width * 0.6; height: parent.height * 0.55
                    radius: 6; color: card.windowColor
                    Row {
                        x: 6; y: 5; spacing: 3
                        Repeater {
                            model: ["#FD4D56", "#FECB18", "#2CD656"]
                            Rectangle { required property var modelData; width: 6; height: 6; radius: 3; color: modelData }
                        }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    width: parent.width * 0.42; height: parent.height * 0.1
                    radius: height / 2.5; color: card.dockColor; opacity: 0.9
                }
            }
            QQC.RadioButton {
                text: card.label
                checked: card.selected
                onClicked: card.chosen()
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }
        }
    }

    component OptionRow: RowLayout {
        property string icon
        property string title
        property string subtitle
        default property alias control: holder.data
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon { source: parent.icon; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QQC.Label { text: title; font.weight: Font.DemiBold }
            QQC.Label { text: subtitle; opacity: 0.7; font: Kirigami.Theme.smallFont; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
        Item {
            id: holder
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
