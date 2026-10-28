// SPDX-License-Identifier: GPL-2.0-or-later
// Bloco da Central de Controle: ícone circular (azul quando ativo), título e estado.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

QQC.AbstractButton {
    id: tile
    property string iconName
    property string title
    property string subtitle
    property bool active: false
    property bool available: true
    property bool showChevron: false
    signal detailsRequested()

    enabled: available
    Layout.fillWidth: true
    // Cartões claros sobre o painel translúcido, como no mockup
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false
    implicitHeight: Kirigami.Units.gridUnit * 3.6
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: subtitle
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        radius: Kirigami.Units.gridUnit
        color: Qt.alpha(Kirigami.Theme.backgroundColor, tile.hovered ? 1.0 : 0.85)
        border.width: tile.visualFocus ? 2 : 0
        border.color: Kirigami.Theme.focusColor
        opacity: tile.available ? 1 : 0.55
    }
    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 2
        Rectangle {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
            Layout.leftMargin: Kirigami.Units.smallSpacing
            radius: width / 2
            color: tile.active ? Kirigami.Theme.focusColor : Qt.alpha(Kirigami.Theme.textColor, 0.10)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.smallMedium
                height: width
                source: tile.iconName
                color: tile.active ? "white" : Kirigami.Theme.textColor
                isMask: true
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QQC.Label {
                text: tile.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            QQC.Label {
                text: tile.subtitle
                opacity: 0.75
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        QQC.ToolButton {
            visible: tile.showChevron
            icon.name: "go-next"
            Accessible.name: i18n("Mais opções de %1", tile.title)
            onClicked: tile.detailsRequested()
        }
    }
}
