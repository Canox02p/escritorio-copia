import QtQuick
import org.kde.kirigami as Kirigami

// Control deslizante con icono, título y porcentaje.
Item {
    id: des

    property var p
    property string icono: ""
    property string titulo: ""
    property real valor: 0          // 0..1
    property string sufijo: "%"
    property bool activo: true
    signal movido(real v)

    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: des.p.tarjeta
        border.width: 1
        border.color: des.p.borde
        opacity: des.activo ? 1 : 0.45
    }

    Kirigami.Icon {
        id: simbolo
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18
        source: des.icono
        isMask: true
        color: des.p.texto
        opacity: des.activo ? 0.9 : 0.4
    }

    Text {
        id: rotulo
        anchors.left: simbolo.right
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 9
        text: des.titulo
        color: des.p.tenue
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: rotulo.verticalCenter
        text: Math.round(des.valor * 100) + des.sufijo
        color: des.p.texto
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    Rectangle {
        id: riel
        anchors.left: simbolo.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 13
        height: 6
        radius: 3
        color: des.p.velo(0.13)

        Rectangle {
            width: Math.max(0, Math.min(1, des.valor)) * parent.width
            height: parent.height
            radius: 3
            color: des.activo ? des.p.acento : des.p.velo(0.3)
        }

        Rectangle {
            x: Math.max(0, Math.min(1, des.valor)) * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: zona.containsMouse || zona.pressed ? 14 : 11
            height: width
            radius: width / 2
            color: des.p.texto
            visible: des.activo
            Behavior on width { NumberAnimation { duration: 110 } }
        }

        MouseArea {
            id: zona
            anchors.fill: parent
            anchors.topMargin: -14
            anchors.bottomMargin: -10
            hoverEnabled: true
            enabled: des.activo
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => des.movido(Math.max(0, Math.min(1, mouse.x / width)))
            onPositionChanged: mouse => { if (pressed) des.movido(Math.max(0, Math.min(1, mouse.x / width))) }
        }
    }
}
