import QtQuick
import QtQuick.Layouts
import org.kde.plasma.workspace.calendar as PlasmaCalendar

// Calendario mensual + lista de eventos del día elegido.
ColumnLayout {
    id: cal

    property var p
    property date hoy: new Date()
    property int diaSel: hoy.getDate()
    property int mesSel: hoy.getMonth() + 1
    property int anioSel: hoy.getFullYear()

    spacing: 8

    PlasmaCalendar.Calendar {
        id: motor
        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: cal.hoy
    }

    function mover(delta) {
        const d = new Date(motor.displayedDate)
        d.setDate(1)
        d.setMonth(d.getMonth() + delta)
        motor.displayedDate = d
    }

    function alInicio() {
        motor.displayedDate = cal.hoy
        diaSel = cal.hoy.getDate(); mesSel = cal.hoy.getMonth() + 1; anioSel = cal.hoy.getFullYear()
    }

    // Mes y flechas
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: motor.monthName.charAt(0).toUpperCase() + motor.monthName.slice(1) + " " + motor.year
            color: cal.p.texto
            font.pixelSize: 15
            font.weight: Font.DemiBold

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.alInicio()
            }
        }

        Item { Layout.fillWidth: true }

        Repeater {
            model: [{ t: "‹", d: -1 }, { t: "›", d: 1 }]
            delegate: Rectangle {
                required property var modelData
                implicitWidth: 21; implicitHeight: 21
                radius: 11
                color: sobre.containsMouse ? cal.p.velo(0.12) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.t
                    color: cal.p.texto
                    font.pixelSize: 17
                }
                MouseArea {
                    id: sobre
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cal.mover(parent.modelData.d)
                }
            }
        }
    }

    // Cabecera de días de la semana
    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: 7
            delegate: Text {
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().standaloneDayName((index + Qt.locale().firstDayOfWeek) % 7, Locale.ShortFormat)
                color: cal.p.tenue
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
            }
        }
    }

    // Rejilla del mes
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rowSpacing: 1
        columnSpacing: 1

        Repeater {
            model: motor.daysModel

            delegate: Item {
                id: celda
                required property var model
                required property int index

                readonly property bool esDelMes: model.monthNumber === motor.displayedDate.getMonth() + 1
                readonly property bool esHoy: model.dayNumber === cal.hoy.getDate()
                                              && model.monthNumber === cal.hoy.getMonth() + 1
                                              && model.yearNumber === cal.hoy.getFullYear()
                readonly property bool elegido: model.dayNumber === cal.diaSel
                                                && model.monthNumber === cal.mesSel
                                                && model.yearNumber === cal.anioSel

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 20

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 2, 24)
                    height: Math.min(parent.height - 1, 20)
                    radius: height / 2
                    color: celda.esHoy ? cal.p.acento
                                       : (celda.elegido ? cal.p.velo(0.14)
                                       : (sobreDia.containsMouse ? cal.p.velo(0.08) : "transparent"))
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: celda.model.dayNumber
                        color: celda.esHoy ? cal.p.sobreAcento
                                           : (celda.esDelMes ? cal.p.texto : cal.p.velo(0.28))
                        font.pixelSize: 11
                        font.weight: celda.esHoy || celda.elegido ? Font.DemiBold : Font.Normal
                    }

                    Rectangle {
                        visible: celda.model.eventCount > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 4; height: 4; radius: 2
                        color: celda.esHoy ? cal.p.sobreAcento : cal.p.acento
                    }

                    MouseArea {
                        id: sobreDia
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cal.diaSel = celda.model.dayNumber
                            cal.mesSel = celda.model.monthNumber
                            cal.anioSel = celda.model.yearNumber
                        }
                    }
                }
            }
        }
    }
}
