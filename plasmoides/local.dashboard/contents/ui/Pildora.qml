import QtQuick

// Pestaña de texto: sin icono, solo letras.
Item {
    id: pildora

    property var p
    property string texto: ""
    property bool activa: false
    property real holgura: 11
    property real tamano: 11
    property bool negrita: true
    signal pulsada()

    implicitWidth: etiqueta.implicitWidth + holgura * 2
    implicitHeight: Math.round(etiqueta.implicitHeight + 9)

    Rectangle {
        id: base
        anchors.fill: parent
        radius: height / 2
        color: pildora.activa ? p.acento
                              : (zona.containsMouse ? p.velo(0.10) : "transparent")
        border.width: pildora.activa ? 0 : 1
        border.color: zona.containsMouse ? p.velo(0.28) : p.velo(0.16)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: etiqueta
        anchors.centerIn: parent
        text: pildora.texto
        color: pildora.activa ? p.sobreAcento : (zona.containsMouse ? p.texto : p.tenue)
        font.pixelSize: pildora.tamano
        font.weight: pildora.negrita ? Font.DemiBold : Font.Normal
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pildora.pulsada()
    }
}
