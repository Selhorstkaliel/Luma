// SPDX-License-Identifier: GPL-2.0-or-later
// Linha com ícone pequeno, slider e ícone grande (brilho, volume).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

Rectangle {
    id: row
    property string iconLow
    property string iconHigh
    property string label
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property bool available: true
    property string unavailableText
    signal moved(real value)

    Layout.fillWidth: true
    // Cartões claros sobre o painel translúcido, como no mockup
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false
    implicitHeight: Kirigami.Units.gridUnit * 2.8
    radius: Kirigami.Units.gridUnit
    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.85)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing * 2
        Kirigami.Icon {
            source: row.iconLow
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }
        QQC.Slider {
            id: slider
            Layout.fillWidth: true
            visible: row.available
            Accessible.name: row.label
            onMoved: row.moved(value)
        }
        QQC.Label {
            Layout.fillWidth: true
            visible: !row.available
            text: row.unavailableText
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
        }
        Kirigami.Icon {
            source: row.iconHigh
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }
    }
}
