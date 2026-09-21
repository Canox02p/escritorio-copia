import QtQuick
import org.kde.kirigami as Kirigami

// Tarjeta pulsable con icono y texto (sesión, conmutadores…).
Rectangle {
    id: boton

    property var p
    property string icono: ""
    property string texto: ""
    property string detalle: ""
    property bool encendido: false
    property bool peligro: false
    signal pulsado()

    radius: 12
    color: encendido ? p.acento : (zona.containsMouse ? p.hueco : p.tarjeta)
    border.width: 1
    border.color: encendido ? "transparent" : (zona.containsMouse ? p.velo(0.3) : p.borde)
    Behavior on color { ColorAnimation { duration: 130 } }

    readonly property color tinta: encendido ? p.sobreAcento : p.texto

    Row {
        anchors.centerIn: parent
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: 10
            color: boton.encendido ? Qt.rgba(0, 0, 0, 0.13) : boton.p.velo(0.07)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 17; height: 17
                source: boton.icono
                isMask: true
                color: boton.peligro && !boton.encendido ? "#e0605f" : boton.tinta
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: boton.texto
                color: boton.tinta
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
            Text {
                text: boton.detalle
                color: boton.encendido ? Qt.rgba(0, 0, 0, 0.55) : boton.p.tenue
                font.pixelSize: 10
                visible: text !== ""
            }
        }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: boton.pulsado()
    }
}
