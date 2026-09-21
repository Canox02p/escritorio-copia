import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

// Historial del portapapeles (Klipper).
//
// El modelo NO se instancia aquí: vive en main.qml, porque el popup del
// plasmoide se destruye al cerrarse y la captura del portapapeles solo
// ocurre mientras el HistoryModel existe.
Item {
    id: panel

    property var p
    property var modelo
    readonly property int cuantas: lista.count

    function limpiar() { if (modelo) modelo.clearHistory() }

    // ---- Buscador ----
    Rectangle {
        id: busqueda
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 28
        radius: 9
        color: campo.activeFocus ? panel.p.velo(0.10) : panel.p.velo(0.05)
        border.width: 1
        border.color: campo.activeFocus ? panel.p.velo(0.26) : panel.p.velo(0.10)
        Behavior on color { ColorAnimation { duration: 140 } }

        Kirigami.Icon {
            id: lupa
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12
            source: "search-symbolic"
            isMask: true
            color: panel.p.tenue
        }

        TextInput {
            id: campo
            anchors {
                left: lupa.right; leftMargin: 8
                right: parent.right; rightMargin: 9
                verticalCenter: parent.verticalCenter
            }
            color: panel.p.texto
            font.pixelSize: 12
            selectByMouse: true
            selectionColor: panel.p.acento
            selectedTextColor: panel.p.sobreAcento
            clip: true

            Text {
                anchors.fill: parent
                visible: campo.text === "" && !campo.activeFocus
                text: "Buscar en el historial…"
                color: panel.p.velo(0.30)
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }

            Keys.onEscapePressed: campo.text = ""
        }
    }

    // ---- Vacío ----
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: lista.count === 0

        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 62; height: 62
            source: "edit-copy-symbolic"
            color: panel.p.velo(0.13)
            isMask: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: campo.text !== "" ? "Sin coincidencias" : "Nada copiado todavía"
            color: panel.p.velo(0.32)
            font.pixelSize: 13
        }
    }

    // ---- Historial ----
    ListView {
        id: lista
        anchors {
            top: busqueda.bottom; topMargin: 9
            left: parent.left; right: parent.right; bottom: parent.bottom
        }
        clip: true
        spacing: 7
        boundsBehavior: Flickable.StopAtBounds

        QQC2.ScrollBar.vertical: Deslizadera { p: panel.p }

        model: KItemModels.KSortFilterProxyModel {
            sourceModel: panel.modelo
            filterRoleName: "display"
            filterRegularExpression: RegExp(campo.text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i")
        }

        delegate: Rectangle {
            id: trozo
            required property var model
            required property int index

            readonly property int tipo: parseInt(model.type) || 2
            readonly property bool esImagen: tipo === 4
            readonly property bool esEnlace: tipo === 8

            width: lista.width - 12
            height: Math.max(42, interior.implicitHeight + 20)
            radius: 11
            color: sobre.hovered ? panel.p.velo(0.09) : panel.p.velo(0.045)
            border.width: 1
            border.color: trozo.index === 0 ? panel.p.velo(0.18) : panel.p.velo(0.06)
            Behavior on color { ColorAnimation { duration: 120 } }

            HoverHandler { id: sobre }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: panel.modelo.moveToTop(trozo.model.uuid)
            }

            Row {
                id: interior
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // Marca de tipo / miniatura
                Item {
                    width: 24
                    height: trozo.esImagen ? 24 : interior.height - 0
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        visible: trozo.esImagen
                        source: trozo.esImagen && trozo.model.decoration !== undefined
                                ? trozo.model.decoration : ""
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        smooth: true
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        visible: !trozo.esImagen
                        source: trozo.esEnlace ? "link-symbolic" : "edit-copy-symbolic"
                        isMask: true
                        color: trozo.index === 0 ? panel.p.acento : panel.p.velo(0.34)
                    }
                }

                Column {
                    width: parent.width - 24 - 10 - (sobre.hovered ? 56 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Row {
                        spacing: 6
                        visible: trozo.index === 0 || trozo.esImagen || trozo.esEnlace
                        Text {
                            text: trozo.index === 0 ? "EN EL PORTAPAPELES"
                                                    : (trozo.esImagen ? "IMAGEN" : "ENLACE")
                            color: panel.p.acento
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.9
                        }
                    }

                    Text {
                        width: parent.width
                        text: (trozo.model.display || "").replace(/\s+/g, " ").trim()
                        color: trozo.index === 0 ? panel.p.texto : panel.p.suave
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }

            // Acciones al pasar por encima
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                visible: sobre.hovered

                Rectangle {
                    width: 22; height: 22; radius: 8
                    color: aCopiar.containsMouse ? panel.p.acento : panel.p.velo(0.12)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        source: "edit-copy-symbolic"
                        isMask: true
                        color: aCopiar.containsMouse ? panel.p.sobreAcento : panel.p.texto
                    }
                    MouseArea {
                        id: aCopiar
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.modelo.moveToTop(trozo.model.uuid)
                    }
                }

                Rectangle {
                    width: 22; height: 22; radius: 8
                    color: aBorrar.containsMouse ? panel.p.velo(0.22) : panel.p.velo(0.12)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 11; height: 11
                        source: "window-close-symbolic"
                        isMask: true
                        color: panel.p.texto
                    }
                    MouseArea {
                        id: aBorrar
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.modelo.remove(trozo.model.uuid)
                    }
                }
            }
        }
    }
}
