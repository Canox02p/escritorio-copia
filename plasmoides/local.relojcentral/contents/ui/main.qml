import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property date ahora: new Date()

    Plasmoid.icon: "clock"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.ahora = new Date()
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 9
        Layout.minimumWidth: Kirigami.Units.gridUnit * 4
        Layout.minimumHeight: Kirigami.Units.gridUnit * 2

        // El tamaño de la hora se ajusta al tamaño del widget
        Text {
            anchors.fill: parent
            text: Qt.formatTime(root.ahora, "HH:mm")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.Fit
            minimumPixelSize: 12
            font.pixelSize: 1000
            font.family: Kirigami.Theme.defaultFont.family
            font.weight: Font.Light
            color: "white"

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.55
                shadowBlur: 0.6
                shadowVerticalOffset: 3
                shadowHorizontalOffset: 0
            }
        }
    }
}
