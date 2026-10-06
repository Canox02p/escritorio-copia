import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
    Paleta { id: p; dirCodigo: root.dirCodigo }

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int tam: Math.round(Kirigami.Units.gridUnit * 1.5)
    property real acumulado: 0

    preferredRepresentation: fullRepresentation
    toolTipMainText: "Escritorios"
    toolTipSubText: "Clic para cambiar de escritorio, o usa la rueda del mouse"

    TaskManager.VirtualDesktopInfo {
        id: escritorios
    }

    // `VirtualDesktopInfo.requestActivate()` NO se puede llamar desde QML: en
    // /usr/include/taskmanager/virtualdesktopinfo.h es un método público normal,
    // sin Q_INVOKABLE y sin ser slot (solo `currentDesktopByScreenName` y
    // `currentDesktopByScreenGeometry` lo llevan), así que el clic llamaba a una
    // función que no existe y no pasaba nada. Las PROPIEDADES sí funcionan, por
    // eso el número activo se resaltaba bien.
    // Se cambia por D-Bus, que es lo que de verdad responde.
    P5Support.DataSource {
        id: ejecutor
        engine: "executable"
        connectedSources: []
        // Desconectar al terminar: si no, cada clic deja la fuente colgada.
        onNewData: fuente => ejecutor.disconnectSource(fuente)
    }

    // KWin numera los escritorios desde 1, igual que lo que se pinta.
    function irA(numero) {
        if (numero < 1 || numero > escritorios.numberOfDesktops) return
        ejecutor.connectSource("gdbus call --session --dest org.kde.KWin"
                               + " --object-path /KWin"
                               + " --method org.kde.KWin.setCurrentDesktop " + numero)
    }

    function mover(paso) {
        const ids = escritorios.desktopIds
        const i = ids.indexOf(escritorios.currentDesktop) + paso
        if (i >= 0 && i < ids.length) root.irA(i + 1)
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
                            color: boton.actual ? p.acento
                                 : zona.containsMouse ? p.velo(0.15)
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
                            color: boton.actual ? p.sobreAcento : p.texto
                            opacity: boton.actual ? 1 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        MouseArea {
                            id: zona
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.irA(boton.index + 1)
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
