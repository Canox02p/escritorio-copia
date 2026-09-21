import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Reloj, tiempo, calendario, música y avisos.
GridLayout {
    id: inicio

    property var p
    property string dirCodigo: ""
    property var s              // Sensores
    signal irA(int seccion)

    columns: 4
    rowSpacing: 9
    columnSpacing: 9

    property date ahora: new Date()
    // "hh" a secas da 24 horas; con AP delante sale la de 12
    readonly property var partesHora: Qt.formatTime(ahora, "hh:mm:AP").split(":")
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: inicio.visible && !!inicio.Window.window && inicio.Window.window.visible
        onTriggered: inicio.ahora = new Date()
    }

    // Tiempo, solo el resumen: el detalle está en su pestaña
    property var clima: ({})
    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            try { inicio.clima = JSON.parse(data["stdout"]) } catch (e) { }
        }
    }
    function consultarClima() {
        if (dirCodigo !== "") ejecutar.connectSource("bash '" + dirCodigo + "clima.sh'")
    }
    Component.onCompleted: consultarClima()
    onDirCodigoChanged: consultarClima()
    Timer { interval: 900000; running: true; repeat: true; onTriggered: inicio.consultarClima() }

    // ---- Reloj ----
    Pieza {
        Layout.row: 1
        Layout.column: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 150
        Layout.maximumWidth: 175
        p: inicio.p

        Column {
            anchors.centerIn: parent
            spacing: -6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: inicio.partesHora[0]
                color: inicio.p.texto
                font.pixelSize: 46
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "•  •  •"
                color: inicio.p.velo(0.25)
                font.pixelSize: 11
                topPadding: 8
                bottomPadding: 8
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: inicio.partesHora[1]
                color: inicio.p.texto
                font.pixelSize: 46
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: inicio.partesHora[2]
                color: inicio.p.suave
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: 2
                topPadding: 10
            }
        }
    }

    // ---- Calendario ----
    Pieza {
        Layout.row: 1
        Layout.column: 1
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 290
        p: inicio.p
        titulo: "CALENDARIO"
        icono: "view-calendar"

        Calendario {
            anchors.fill: parent
            p: inicio.p
        }
    }

    // ---- Música ----
    Pieza {
        Layout.row: 0
        Layout.column: 3
        Layout.rowSpan: 2
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 215
        Layout.maximumWidth: 235
        p: inicio.p
        titulo: "SONANDO"
        icono: "media-playback-playing-symbolic"

        extra: [
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "VER MÁS"
                color: masMusica.containsMouse ? inicio.p.acento : inicio.p.velo(0.35)
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                MouseArea {
                    id: masMusica
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: inicio.irA(1)
                }
            }
        ]

        PanelMusica {
            anchors.fill: parent
            p: inicio.p
            dirCodigo: inicio.dirCodigo
            grande: true
        }
    }

    // ---- Tiempo ----
    Pieza {
        Layout.row: 0
        Layout.column: 0
        Layout.fillWidth: true
        Layout.preferredWidth: 150
        Layout.maximumWidth: 175
        Layout.preferredHeight: 168
        p: inicio.p
        titulo: "TIEMPO"
        icono: inicio.clima.icono || "weather-few-clouds-symbolic"

        extra: [
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "VER MÁS"
                color: masClima.containsMouse ? inicio.p.acento : inicio.p.velo(0.35)
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                MouseArea {
                    id: masClima
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: inicio.irA(3)
                }
            }
        ]

        // Todo se mide contra el ancho real de la tarjeta: con tamaños fijos
        // el conjunto era más ancho que ella y el icono salía cortado
        Item {
            id: cajaClima
            anchors.fill: parent

            readonly property real lado: Math.max(26, Math.min(40, width * 0.26))

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 4

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(cajaClima.lado * 0.25)

                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: cajaClima.lado; height: cajaClima.lado
                        source: inicio.clima.icono || "weather-few-clouds-symbolic"
                        isMask: true
                        color: inicio.p.texto
                        opacity: 0.9
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: inicio.clima.temp !== undefined ? inicio.clima.temp + "°C" : "—"
                        color: inicio.p.texto
                        font.pixelSize: Math.round(cajaClima.lado * 0.6)
                        font.weight: Font.Bold
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: inicio.clima.desc || ""
                    color: inicio.p.tenue
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ---- Avisos, donde la referencia pone la tarjeta del sistema ----
    Pieza {
        Layout.row: 0
        Layout.column: 1
        Layout.columnSpan: 2
        Layout.fillWidth: true
        Layout.preferredHeight: 168
        p: inicio.p
        titulo: "NOTIFICACIONES"
        icono: "notifications-symbolic"

        extra: [
            Rectangle {
                width: Math.max(17, cuenta.implicitWidth + 11)
                height: 17
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                color: avisos.cuantas > 0 ? inicio.p.acento : inicio.p.velo(0.1)
                Text {
                    id: cuenta
                    anchors.centerIn: parent
                    text: avisos.cuantas
                    color: avisos.cuantas > 0 ? inicio.p.sobreAcento : inicio.p.tenue
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            },
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "LIMPIAR"
                color: limpia.containsMouse ? inicio.p.acento : inicio.p.velo(0.35)
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                MouseArea {
                    id: limpia
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: avisos.limpiar()
                }
            }
        ]

        PanelNotificaciones {
            id: avisos
            anchors.fill: parent
            p: inicio.p
        }
    }

    // ---- Medidores, la columna estrecha de la referencia ----
    Pieza {
        Layout.row: 1
        Layout.column: 2
        Layout.fillHeight: true
        Layout.preferredWidth: 78
        Layout.minimumWidth: 74
        p: inicio.p
        margen: 8

        Column {
            anchors.centerIn: parent
            spacing: 9

            component Medidor: Aro {
                width: 58; height: 58
                p: inicio.p
                grosor: 4
                tamanoCifra: 10
            }

            Medidor {
                icono: "computer-symbolic"
                valor: inicio.s.cpu / 100
                cifra: Math.round(inicio.s.cpu) + "%"
            }
            Medidor {
                icono: "media-flash-symbolic"
                valor: inicio.s.ram / 100
                cifra: Math.round(inicio.s.ram) + "%"
            }
            Medidor {
                icono: "drive-harddisk-symbolic"
                valor: (inicio.s.disco.porcentaje || 0) / 100
                cifra: (inicio.s.disco.porcentaje || 0) + "%"
            }
        }
    }
}
