import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Tiempo actual y tres días (datos de wttr.in, sin configurar nada).
ColumnLayout {
    id: clima

    property var p
    property string dirCodigo: ""
    property var datos: ({})

    spacing: 9

    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            try { clima.datos = JSON.parse(data["stdout"]) } catch (e) { }
        }
    }

    function consultar() {
        if (dirCodigo !== "") ejecutar.connectSource("bash '" + dirCodigo + "clima.sh'")
    }
    Component.onCompleted: consultar()
    onDirCodigoChanged: consultar()
    Timer { interval: 900000; running: true; repeat: true; onTriggered: clima.consultar() }

    function diaCorto(fecha) {
        const d = new Date(fecha + "T12:00:00")
        return Qt.formatDate(d, "ddd")
    }

    // ---- Ahora ----
    Pieza {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 5
        p: clima.p
        titulo: "AHORA"
        icono: clima.datos.icono || "weather-few-clouds-symbolic"

        extra: [
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clima.datos.lugar || ""
                color: clima.p.tenue
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        ]

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 62; height: 62
                source: clima.datos.icono || "weather-few-clouds-symbolic"
                isMask: true
                color: clima.p.texto
                opacity: 0.9
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: clima.datos.temp !== undefined ? clima.datos.temp + "°C" : "—"
                    color: clima.p.texto
                    font.pixelSize: 34
                    font.weight: Font.Bold
                }
                Text {
                    text: clima.datos.desc || "Buscando el tiempo…"
                    color: clima.p.suave
                    font.pixelSize: 12
                }
            }
        }

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            component Dato: Row {
                property string rotulo: ""
                property string valor: ""
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: rotulo
                    color: clima.p.tenue
                    font.pixelSize: 10
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: valor
                    color: clima.p.texto
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Dato { rotulo: "Sensación"; valor: clima.datos.sensacion !== undefined ? clima.datos.sensacion + "°C" : "—" }
            Dato { rotulo: "Humedad";   valor: clima.datos.humedad !== undefined ? clima.datos.humedad + "%" : "—" }
            Dato { rotulo: "Viento";    valor: clima.datos.viento !== undefined ? clima.datos.viento + " km/h" : "—" }
        }
    }

    // ---- Próximos días ----
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 4
        spacing: 9

        Repeater {
            model: clima.datos.dias || []
            delegate: Pieza {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                p: clima.p

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: index === 0 ? "HOY" : clima.diaCorto(modelData.fecha).toUpperCase()
                        color: clima.p.tenue
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    Kirigami.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 30; height: 30
                        source: modelData.icono
                        isMask: true
                        color: clima.p.texto
                        opacity: 0.85
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 7
                        Text {
                            text: modelData.max + "°"
                            color: clima.p.texto
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: modelData.min + "°"
                            color: clima.p.tenue
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
