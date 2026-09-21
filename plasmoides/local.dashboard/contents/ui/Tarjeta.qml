import QtQuick
import org.kde.kirigami as Kirigami

// Tarjeta con título grande y placa de icono, al estilo de la referencia.
Rectangle {
    id: tarjeta

    property var p
    property string titulo: ""
    property string icono: ""
    property real margen: 14
    // true: el icono va en un círculo fino (CPU/GPU). false: suelto al lado
    // del título, como en Red y Memoria.
    property bool placa: true
    default property alias contenido: cuerpo.data
    property alias derecha: extremo.data

    color: p.tarjeta
    radius: 16
    border.width: 1
    border.color: p.borde
    clip: true

    Row {
        id: cabecera
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: tarjeta.margen
        anchors.leftMargin: tarjeta.margen
        spacing: tarjeta.placa ? 11 : 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            radius: 18
            color: "transparent"
            border.width: 1.5
            border.color: tarjeta.p.velo(0.16)
            visible: tarjeta.icono !== "" && tarjeta.placa

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16; height: 16
                source: tarjeta.icono
                isMask: true
                color: tarjeta.p.texto
                opacity: 0.85
            }
        }

        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 17; height: 17
            source: tarjeta.icono
            isMask: true
            color: tarjeta.p.texto
            opacity: 0.9
            visible: tarjeta.icono !== "" && !tarjeta.placa
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tarjeta.titulo
            color: tarjeta.p.texto
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
    }

    Item {
        id: extremo
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: tarjeta.margen
        anchors.rightMargin: tarjeta.margen
        width: childrenRect.width
        height: 34
    }

    Item {
        id: cuerpo
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: cabecera.bottom
        anchors.topMargin: 10
        anchors.leftMargin: tarjeta.margen
        anchors.rightMargin: tarjeta.margen
        anchors.bottomMargin: tarjeta.margen
    }
}
