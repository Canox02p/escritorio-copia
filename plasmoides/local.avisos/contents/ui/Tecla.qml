import QtQuick

// Una tecla dibujada como tecla de verdad: relieve suave, borde y monoespaciada.
Item {
    id: tecla

    property var p
    property string texto: ""
    property real tamano: 11

    implicitWidth: Math.max(implicitHeight, etiqueta.implicitWidth + 14)
    implicitHeight: Math.round(tamano + 13)

    Rectangle {
        id: cuerpo
        anchors.fill: parent
        radius: 6
        color: tecla.p.velo(0.10)
        border.width: 1
        border.color: tecla.p.velo(0.22)

        // Brillo de arriba: le da el relieve de tecla sin usar imágenes.
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 1
            height: parent.height * 0.45
            radius: 5
            color: tecla.p.velo(0.07)
        }

        // Sombra fina de abajo, para que parezca que sobresale.
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            anchors.margins: 1
            height: 2
            radius: 2
            color: "#33000000"
        }
    }

    Text {
        id: etiqueta
        anchors.centerIn: parent
        text: tecla.texto
        color: tecla.p.texto
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: tecla.tamano
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3
    }
}
