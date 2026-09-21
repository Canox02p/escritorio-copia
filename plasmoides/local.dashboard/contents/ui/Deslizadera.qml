import QtQuick
import QtQuick.Controls as QQC2

// Barra de desplazamiento fina, al margen, que no tapa el contenido.
QQC2.ScrollBar {
    id: barra

    property var p

    policy: QQC2.ScrollBar.AsNeeded
    width: 5
    padding: 0

    contentItem: Rectangle {
        implicitWidth: 5
        radius: 3
        color: barra.pressed ? barra.p.texto : barra.p.velo(0.32)
        opacity: barra.active || barra.hovered ? 1 : 0.55
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    background: Rectangle {
        radius: 3
        color: barra.p.velo(0.06)
        opacity: barra.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
