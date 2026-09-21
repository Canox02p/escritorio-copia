import QtQuick
import org.kde.kirigami as Kirigami

// Tarjeta con cabecera de letras espaciadas.
Rectangle {
    id: pieza

    property var p
    property string titulo: ""
    property string icono: ""
    default property alias contenido: cuerpo.data
    property alias extra: derecha.data
    property real margen: 11

    color: p.tarjeta
    radius: 12
    clip: true
    border.width: 1
    border.color: p.borde

    Item {
        id: cabecera
        visible: pieza.titulo !== ""
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: pieza.margen }
        height: visible ? 16 : 0

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12
                source: pieza.icono
                isMask: true
                color: pieza.p.acento
                visible: pieza.icono !== ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pieza.titulo
                color: pieza.p.tenue
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4
            }
        }

        Row {
            id: derecha
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
        }
    }

    Item {
        id: cuerpo
        anchors {
            top: cabecera.visible ? cabecera.bottom : parent.top
            topMargin: cabecera.visible ? 12 : pieza.margen
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: pieza.margen; rightMargin: pieza.margen; bottomMargin: pieza.margen
        }
    }
}
