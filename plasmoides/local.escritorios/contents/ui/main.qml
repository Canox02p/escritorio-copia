import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int tam: Math.round(Kirigami.Units.gridUnit * 1.5)
    property real acumulado: 0

    preferredRepresentation: fullRepresentation
    toolTipMainText: "Escritorios"
    toolTipSubText: "Clic para cambiar de escritorio, o usa la rueda del mouse"

    TaskManager.VirtualDesktopInfo {
        id: escritorios
    }

    function mover(paso) {
        const ids = escritorios.desktopIds
        const i = ids.indexOf(escritorios.currentDesktop) + paso
        if (i >= 0 && i < ids.length) {
            escritorios.requestActivate(ids[i])
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: fondo.implicitWidth
        Layout.minimumHeight: fondo.implicitHeight
        Layout.preferredWidth: fondo.implicitWidth
        Layout.preferredHeight: fondo.implicitHeight

        Rectangle {
            id: fondo
            anchors.centerIn: parent
            implicitWidth: numeros.implicitWidth
            implicitHeight: numeros.implicitHeight + Kirigami.Units.smallSpacing * 2
            // Sin fondo propio: el panel ya pinta su marco esmerilado, y una
            // píldora encima dibujaba una segunda forma que no encajaba con él
            color: "transparent"

            Grid {
                id: numeros
                anchors.centerIn: parent
                columns: root.vertical ? 1 : Math.max(1, escritorios.numberOfDesktops)
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: escritorios.desktopIds

                    delegate: Item {
                        id: boton
                        required property var modelData
                        required property int index
                        readonly property bool actual: modelData === escritorios.currentDesktop

                        width: root.tam
                        height: root.tam

                        // Un poco hacia dentro: así el círculo deja el mismo aire
                        // arriba, abajo y a los lados dentro del panel
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: width / 2
                            color: boton.actual ? Kirigami.Theme.textColor
                                 : zona.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                 : "transparent"
                            scale: boton.actual ? 1 : (zona.pressed ? 0.9 : 1)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }
                        }

                        // Misma tipografía que la tira de CPU y la barra de la hora
                        Text {
                            anchors.centerIn: parent
                            text: boton.index + 1
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Math.round(root.tam * 0.5)
                            font.weight: boton.actual ? Font.DemiBold : Font.Medium
                            font.letterSpacing: 0.4
                            color: boton.actual ? Kirigami.Theme.backgroundColor : Kirigami.Theme.textColor
                            opacity: boton.actual ? 1 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        MouseArea {
                            id: zona
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: escritorios.requestActivate(boton.modelData)
                        }
                    }
                }
            }
        }

        WheelHandler {
            onWheel: event => {
                root.acumulado += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                if (Math.abs(root.acumulado) >= 120) {
                    root.mover(root.acumulado < 0 ? 1 : -1)
                    root.acumulado = 0
                }
            }
        }
    }
}
