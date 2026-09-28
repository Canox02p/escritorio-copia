import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// Lo que enseña la tira del panel cuando llega una notificación: se traga el
// contenido normal (hora y canción) durante unos segundos y luego lo devuelve.
// Estilo "isla" de los móviles: píldora con el icono de la app, el título y el
// cuerpo, entrando con un rebotito. Al pasar el ratón se queda quieta, se
// ensancha y saca debajo la tarjeta con el aviso entero.
Item {
    id: isla

    property var p
    property var aviso: null          // { icono, app, resumen, cuerpo, urgente }
    property bool mostrando: false
    property int anchoMaximo: 330
    property int borde: PlasmaCore.Types.TopEdge

    // Mientras el ratón esté encima, main.qml no deja que se vaya
    readonly property bool sobre: sobrePildora.hovered || sobreTarjeta.hovered
    readonly property bool expandida: mostrando && sobre

    signal pulsada()

    implicitWidth: pildora.width
    implicitHeight: Math.max(pildora.height, 20)

    opacity: mostrando ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: isla.mostrando ? 200 : 160; easing.type: Easing.OutCubic }
    }

    // Cuánto texto dejamos ver: al pasar el ratón, bastante más
    readonly property real limite: expandida ? anchoMaximo * 1.75 : anchoMaximo

    Rectangle {
        id: pildora
        anchors.centerIn: parent
        anchors.verticalCenterOffset: isla.mostrando ? 0 : 7
        width: contenido.implicitWidth + 20
        height: contenido.implicitHeight + 7
        radius: height / 2
        color: isla.p ? isla.p.velo(isla.aviso && isla.aviso.urgente ? 0.18
                                  : isla.expandida ? 0.16 : 0.10)
                      : "#22ffffff"
        border.width: 1
        border.color: isla.p ? isla.p.velo(isla.expandida ? 0.14 : 0.08) : "#14ffffff"

        scale: isla.mostrando ? 1 : 0.86
        transformOrigin: Item.Center

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation {
                duration: isla.mostrando ? 340 : 170
                easing.type: isla.mostrando ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.9
            }
        }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        HoverHandler { id: sobrePildora; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: isla.pulsada() }

        Row {
            id: contenido
            anchors.centerIn: parent
            spacing: 7

            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                source: isla.aviso ? isla.aviso.icono : "dialog-information"
            }

            Text {
                id: titulo
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, isla.limite * 0.55)
                text: isla.aviso ? isla.aviso.resumen : ""
                color: isla.p ? isla.p.texto : "#f4f4f6"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                visible: text !== ""
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                color: isla.p ? isla.p.velo(0.4) : "#66ffffff"
                font.pixelSize: 11
                visible: titulo.visible && cuerpo.visible
            }

            Text {
                id: cuerpo
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(60, isla.limite - titulo.width - 40))
                text: isla.aviso ? isla.aviso.cuerpo : ""
                color: isla.p ? isla.p.velo(0.62) : "#a0ffffff"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                elide: Text.ElideRight
                visible: text !== ""
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ---- Tarjeta de debajo, al pasar el ratón ----
    PlasmaCore.Dialog {
        id: tarjeta
        visualParent: pildora
        location: isla.borde
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        visible: isla.expandida && !!isla.aviso

        mainItem: Item {
            width: 330
            height: marco.height

            Rectangle {
                id: marco
                width: parent.width
                height: columna.implicitHeight + 28
                radius: 16
                color: isla.p ? Qt.rgba(isla.p.fondo.r, isla.p.fondo.g, isla.p.fondo.b, 0.94)
                              : "#f00a0a0c"
                border.width: 1
                border.color: isla.p ? isla.p.borde : "#26ffffff"

                opacity: isla.expandida ? 1 : 0
                scale: isla.expandida ? 1 : 0.94
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale {
                    NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                HoverHandler { id: sobreTarjeta }

                Row {
                    id: columna
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 12

                    Kirigami.Icon {
                        width: 30; height: 30
                        source: isla.aviso ? isla.aviso.icono : "dialog-information"
                    }

                    Column {
                        width: parent.width - 30 - 12
                        spacing: 4

                        Text {
                            text: isla.aviso ? isla.aviso.app : ""
                            color: isla.p ? isla.p.acento : "#f2f2f4"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                            visible: text !== ""
                        }

                        Text {
                            width: parent.width
                            text: isla.aviso ? isla.aviso.resumen : ""
                            color: isla.p ? isla.p.texto : "#f4f4f6"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        Text {
                            width: parent.width
                            text: isla.aviso ? isla.aviso.cuerpo : ""
                            color: isla.p ? isla.p.velo(0.66) : "#a8ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }
                }
            }
        }
    }
}
