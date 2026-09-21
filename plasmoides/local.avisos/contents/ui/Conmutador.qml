import QtQuick
import org.kde.kirigami as Kirigami

// Botón cuadrado de acceso rápido: se enciende cuando está activo.
Rectangle {
    id: boton

    property var p
    property string icono: ""
    property string pista: ""
    property bool activo: false
    property bool alerta: false        // para acciones destructivas
    signal pulsado()

    implicitWidth: 60
    implicitHeight: 42
    radius: 13
    color: activo ? p.acento
                  : (zona.containsMouse ? p.velo(0.13) : p.velo(0.06))
    border.width: 1
    border.color: activo ? "transparent" : p.borde
    scale: zona.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 90 } }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: 18; height: 18
        source: boton.icono
        isMask: true
        color: boton.activo ? boton.p.sobreAcento
                            : (boton.alerta ? "#e0605f" : boton.p.texto)
        opacity: boton.activo ? 1 : 0.85
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: boton.pulsado()
    }

    // Etiqueta al pasar por encima
    Rectangle {
        visible: zona.containsMouse && boton.pista !== ""
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: etiqueta.implicitWidth + 16
        height: 24
        radius: 12
        color: boton.p.hueco
        border.width: 1
        border.color: boton.p.borde
        z: 10

        Text {
            id: etiqueta
            anchors.centerIn: parent
            text: boton.pista
            color: boton.p.texto
            font.pixelSize: 10
        }
    }
}
