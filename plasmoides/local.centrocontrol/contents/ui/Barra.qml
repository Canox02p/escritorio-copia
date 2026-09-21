import QtQuick

// Barra de progreso/volumen con tiempos opcionales.
Item {
    id: barra

    property var p
    property real valor: 0
    property bool tiempos: true
    property string izquierda: ""
    property string derecha: ""
    signal saltar(real v)

    implicitHeight: tiempos ? 26 : 14

    Rectangle {
        id: riel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 5
        height: 4
        radius: 2
        color: barra.p.velo(0.14)

        Rectangle {
            width: Math.max(0, Math.min(1, barra.valor)) * parent.width
            height: parent.height
            radius: 2
            color: barra.p.acento
        }

        Rectangle {
            visible: zona.containsMouse || zona.pressed
            x: Math.max(0, Math.min(1, barra.valor)) * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 11; height: 11; radius: 6
            color: barra.p.texto
        }

        MouseArea {
            id: zona
            anchors.fill: parent
            anchors.topMargin: -7
            anchors.bottomMargin: -7
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => barra.saltar(Math.max(0, Math.min(1, mouse.x / width)))
            onPositionChanged: mouse => { if (pressed) barra.saltar(Math.max(0, Math.min(1, mouse.x / width))) }
        }
    }

    Text {
        visible: barra.tiempos
        anchors.left: parent.left
        anchors.top: riel.bottom
        anchors.topMargin: 4
        text: barra.izquierda
        color: barra.p.tenue
        font.pixelSize: 10
    }
    Text {
        visible: barra.tiempos
        anchors.right: parent.right
        anchors.top: riel.bottom
        anchors.topMargin: 4
        text: barra.derecha
        color: barra.p.tenue
        font.pixelSize: 10
    }
}
