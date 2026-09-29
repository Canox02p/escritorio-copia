import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// Lo que enseña la tira del panel cuando llega una notificación: se traga el
// contenido normal (hora y canción) durante unos segundos y luego lo devuelve.
// Va con la misma letra y los mismos colores que el resto de la barra, sin caja
// ni recuadro: solo cambia el contenido. Al pasar el ratón se queda quieta y
// saca debajo la tarjeta con el aviso entero.
Item {
    id: isla

    property var p
    property var aviso: null          // { icono, app, resumen, cuerpo, urgente }
    property bool mostrando: false
    property int anchoMaximo: 330
    property int borde: PlasmaCore.Types.TopEdge

    // Mientras el ratón esté encima, main.qml no deja que se vaya
    readonly property bool sobre: sobreTexto.hovered || sobreTarjeta.hovered
    readonly property bool expandida: mostrando && sobre

    signal pulsada()

    implicitWidth: contenido.implicitWidth
    implicitHeight: Math.max(contenido.implicitHeight, 20)

    opacity: mostrando ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: isla.mostrando ? 190 : 150; easing.type: Easing.OutCubic }
    }

    Row {
        id: contenido
        anchors.centerIn: parent
        anchors.verticalCenterOffset: isla.mostrando ? 0 : 9
        spacing: 8

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 13; height: 13
            source: isla.aviso ? isla.aviso.icono : "dialog-information"
            opacity: isla.sobre ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        // El título, con la letra de la hora
        Text {
            id: titulo
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, isla.anchoMaximo * 0.55)
            text: isla.aviso ? isla.aviso.resumen : ""
            color: isla.p ? isla.p.texto : "#f4f4f6"
            opacity: isla.sobre ? 1 : 0.92
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 0.6
            elide: Text.ElideRight
            visible: text !== ""
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        // El cuerpo, con la letra de la canción
        Text {
            id: cuerpo
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(60, isla.anchoMaximo - titulo.width - 34))
            text: isla.aviso ? isla.aviso.cuerpo : ""
            color: isla.p ? isla.p.texto : "#f4f4f6"
            opacity: isla.sobre ? 0.82 : 0.62
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.weight: Font.Medium
            elide: Text.ElideRight
            visible: text !== ""
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    HoverHandler { id: sobreTexto; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: isla.pulsada() }

    // ---- Tarjeta de debajo, al pasar el ratón ----
    // Pelada a propósito: sin icono grande, sin borde y sin el nombre de la app.
    // Solo un cuadro negro, como el de las notificaciones del sistema.
    PlasmaCore.Dialog {
        id: tarjeta
        visualParent: isla
        location: isla.borde
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        visible: isla.expandida && !!isla.aviso

        mainItem: Item {
            width: 320
            height: marco.height

            Rectangle {
                id: marco
                width: parent.width
                height: columna.implicitHeight + 30
                radius: 12
                color: isla.p ? Qt.rgba(isla.p.fondo.r, isla.p.fondo.g, isla.p.fondo.b, 1) : "#0a0a0c"

                opacity: isla.expandida ? 1 : 0
                scale: isla.expandida ? 1 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                HoverHandler { id: sobreTarjeta }

                Column {
                    id: columna
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 15
                    spacing: 5

                    Text {
                        width: parent.width
                        text: isla.aviso ? isla.aviso.resumen : ""
                        color: isla.p ? isla.p.texto : "#f4f4f6"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Text {
                        width: parent.width
                        text: isla.aviso ? isla.aviso.cuerpo : ""
                        color: isla.p ? isla.p.tenue : "#9a9aa2"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        maximumLineCount: 6
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }
        }
    }
}
