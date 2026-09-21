import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NM

// Lista de notificaciones del sistema.
Item {
    id: panel

    property var p
    readonly property int cuantas: lista.count

    function limpiar() { modelo.clear(NM.Notifications.ClearExpired) }

    NM.Notifications {
        id: modelo
        showNotifications: true
        showJobs: true
        showExpired: true
        showDismissed: true
        sortMode: NM.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NM.Notifications.GroupDisabled
        urgencies: NM.Notifications.LowUrgency | NM.Notifications.NormalUrgency | NM.Notifications.CriticalUrgency
    }

    // Vacío
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: lista.count === 0
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 62; height: 62
            source: "notifications-symbolic"
            color: panel.p.velo(0.55)
            isMask: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Todo al día"
            color: panel.p.velo(0.32)
            font.pixelSize: 13
        }
    }

    ListView {
        id: lista
        anchors.fill: parent
        clip: true
        spacing: 8
        model: modelo
        boundsBehavior: Flickable.StopAtBounds

        QQC2.ScrollBar.vertical: Deslizadera { p: panel.p }

        delegate: Rectangle {
            id: aviso
            required property var model
            required property int index

            width: lista.width - 12
            height: interior.implicitHeight + 22
            radius: 13
            color: sobre.hovered ? panel.p.velo(0.08) : panel.p.velo(0.045)
            border.width: 1
            border.color: panel.p.velo(0.06)
            Behavior on color { ColorAnimation { duration: 120 } }

            HoverHandler { id: sobre }

            Row {
                id: interior
                anchors.fill: parent
                anchors.margins: 11
                spacing: 11

                Kirigami.Icon {
                    width: 26; height: 26
                    source: aviso.model.applicationIconName || aviso.model.iconName || "dialog-information"
                }

                Column {
                    width: parent.width - 26 - 11 - (sobre.hovered ? 26 : 0)
                    spacing: 3

                    Row {
                        spacing: 6
                        Text {
                            text: aviso.model.applicationName || ""
                            color: panel.p.acento
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                        }
                        Text {
                            text: aviso.model.created ? Qt.formatTime(aviso.model.created, "HH:mm") : ""
                            color: panel.p.velo(0.3)
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        width: parent.width
                        text: aviso.model.summary || ""
                        color: panel.p.texto
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Text {
                        width: parent.width
                        text: (aviso.model.body || "").replace(/<[^>]*>/g, "")
                        color: panel.p.tenue
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }

            // Cerrar
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 7
                width: 20; height: 20; radius: 10
                visible: sobre.hovered
                color: cerrar.containsMouse ? panel.p.velo(0.18) : "transparent"
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 11; height: 11
                    source: "window-close-symbolic"
                    color: panel.p.texto
                    isMask: true
                }
                MouseArea {
                    id: cerrar
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelo.close(modelo.index(aviso.index, 0))
                }
            }
        }
    }
}
