import QtQuick

// Conmutador deslizable, con su rótulo a la izquierda.
Item {
    id: inter

    property var p
    property string texto: ""
    property bool activo: false
    property bool encendido: true      // si se puede tocar
    signal alternado()

    implicitWidth: (texto !== "" ? rotulo.implicitWidth + 9 : 0) + riel.width
    implicitHeight: 22
    opacity: encendido ? 1 : 0.4

    Text {
        id: rotulo
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: inter.texto !== ""
        text: inter.texto
        color: inter.activo ? inter.p.texto : inter.p.tenue
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Rectangle {
        id: riel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 19
        radius: height / 2
        color: inter.activo ? inter.p.acento : inter.p.velo(0.13)
        border.width: 1
        border.color: inter.activo ? "transparent"
                                   : (zona.containsMouse ? inter.p.velo(0.3) : inter.p.velo(0.18))
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Rectangle {
            id: bola
            y: 3
            x: inter.activo ? riel.width - width - 3 : 3
            width: 13
            height: 13
            radius: height / 2
            color: inter.activo ? inter.p.sobreAcento : inter.p.texto
            opacity: inter.activo ? 1 : 0.8
            scale: zona.pressed ? 0.88 : 1
            Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        enabled: inter.encendido
        cursorShape: Qt.PointingHandCursor
        onClicked: inter.alternado()
    }
}
