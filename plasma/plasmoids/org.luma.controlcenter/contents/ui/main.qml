// SPDX-License-Identifier: GPL-2.0-or-later
// Central de Controle do Luma (decisão 0003, mockup luma-claro.png). Usa só os serviços existentes,
// pelas mesmas APIs QML dos applets do Plasma 6.3: NetworkManager (plasma-nm), BlueZ (bluezqt),
// notificações (notificationmanager), PowerDevil (brightnesscontrolplugin) e PipeWire (plasma-pa).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.private.volume

PlasmoidItem {
    id: root

    Plasmoid.icon: "luma-controlcenter"
    toolTipMainText: i18n("Central de Controle")
    preferredRepresentation: compactRepresentation

    // --- Serviços (mesmos tipos usados pelos applets do Plasma) ---
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.Handler { id: nmHandler }
    PlasmaNM.AvailableDevices { id: availableDevices }
    NotificationManager.Settings { id: notificationSettings }
    ScreenBrightnessControl {
        id: brightnessControl
        isSilent: root.expanded
    }

    // Sem placa Wi-Fi o NetworkManager ainda informa o rádio como habilitado: exige um dispositivo
    readonly property bool wifiAvailable: availableDevices.wirelessDeviceAvailable && enabledConnections.wirelessHwEnabled
    readonly property bool wifiOn: wifiAvailable && enabledConnections.wirelessEnabled
    readonly property bool btAvailable: BluezQt.Manager.adapters.length > 0
    readonly property bool btOn: btAvailable && !BluezQt.Manager.bluetoothBlocked
    readonly property bool dndOn: notificationSettings.notificationsInhibitedUntil > new Date()
    readonly property var sink: PreferredDevice.sink

    function setDnd(on) {
        const until = new Date();
        if (on) {
            until.setFullYear(until.getFullYear() + 1);   // até ser desligado
        } else {
            until.setTime(0);                              // data no passado: não inibe
        }
        notificationSettings.notificationsInhibitedUntil = until;
        notificationSettings.save();
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 3
            text: i18n("Central de Controle")
            Layout.leftMargin: Kirigami.Units.smallSpacing
        }

        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true

            Tile {
                objectName: "tileWifi"
                iconName: "network-wireless-symbolic"
                title: i18n("Wi-Fi")
                available: root.wifiAvailable
                active: root.wifiOn
                showChevron: true
                subtitle: !root.wifiAvailable ? i18n("Indisponível")
                        : !root.wifiOn ? i18n("Desligado")
                        : i18n("Ligado")
                onClicked: nmHandler.enableWireless(!root.wifiOn)
                onDetailsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
            }
            Tile {
                objectName: "tileBluetooth"
                iconName: "network-bluetooth-symbolic"
                title: i18n("Bluetooth")
                available: root.btAvailable
                active: root.btOn
                showChevron: true
                subtitle: !root.btAvailable ? i18n("Indisponível") : (root.btOn ? i18n("Ativado") : i18n("Desativado"))
                onClicked: BluezQt.Manager.bluetoothBlocked = root.btOn
                onDetailsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_bluetooth")
            }
            Tile {
                objectName: "tileDnd"
                iconName: "notifications-disabled-symbolic"
                title: i18n("Não Perturbe")
                active: root.dndOn
                subtitle: root.dndOn ? i18n("Ativado") : i18n("Desativado")
                onClicked: root.setDnd(!root.dndOn)
            }
            Tile {
                objectName: "tileMirror"
                iconName: "video-display-symbolic"
                title: i18n("Espelhamento de Tela")
                subtitle: i18n("Monitores")
                onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_kscreen")
            }
        }

        // Brilho do primeiro monitor com controle (em VM costuma ser o brilho por software do KWin)
        Repeater {
            id: displays
            model: brightnessControl.displays
            delegate: SliderRow {
                required property int index
                required property string displayName
                required property int brightness
                required property int maxBrightness
                visible: index === 0
                label: i18n("Brilho")
                iconLow: "brightness-low-symbolic"
                iconHigh: "brightness-high-symbolic"
                from: 0
                to: maxBrightness
                stepSize: 0
                value: brightness
                onMoved: v => brightnessControl.setBrightness(displayName, Math.round(v))
            }
        }
        SliderRow {
            visible: displays.count === 0
            label: i18n("Brilho")
            iconLow: "brightness-low-symbolic"
            iconHigh: "brightness-high-symbolic"
            available: false
            unavailableText: i18n("Brilho indisponível")
        }

        SliderRow {
            label: i18n("Volume")
            iconLow: "audio-volume-low-symbolic"
            iconHigh: "audio-volume-high-symbolic"
            available: !!root.sink
            unavailableText: i18n("Nenhuma saída de áudio")
            from: 0
            to: PulseAudio.NormalVolume
            stepSize: 0
            value: root.sink ? root.sink.volume : 0
            onMoved: v => {
                if (root.sink) {
                    root.sink.volume = Math.round(v);
                }
            }
        }
    }
}
