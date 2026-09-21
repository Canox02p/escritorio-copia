import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// CPU, GPU, disco, red y memoria, con la distribución de la referencia.
ColumnLayout {
    id: rend

    property var p
    property var s        // Sensores

    spacing: 10

    // ---- Procesador y gráfica ----
    component Chip: Tarjeta {
        property real grados: 0
        property real uso: 0
        property string modelo: ""

        Layout.fillWidth: true
        Layout.fillHeight: true
        p: rend.p

        Text {
            id: rotuloUso
            anchors.right: parent.right
            anchors.top: parent.top
            text: "Uso"
            color: rend.p.tenue
            font.pixelSize: 11
        }

        // Pastilla con el porcentaje
        Rectangle {
            id: pastilla
            anchors.right: parent.right
            anchors.top: rotuloUso.bottom
            anchors.topMargin: 4
            width: 66; height: 52
            radius: 22
            color: rend.p.velo(0.08)
            border.width: 1
            border.color: rend.p.velo(0.06)

            Text {
                anchors.centerIn: parent
                text: Math.round(uso) + "%"
                color: rend.p.velo(0.5)
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
        }

        Text {
            id: modeloTexto
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: pastilla.left
            anchors.rightMargin: 12
            text: modelo
            color: rend.p.tenue
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Row {
            id: temperatura
            anchors.top: modeloTexto.bottom
            anchors.topMargin: 9
            anchors.left: parent.left
            spacing: 6
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 13; height: 13
                source: "temperature-normal"
                isMask: true
                color: rend.p.tenue
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(grados) + "°C"
                color: rend.p.texto
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: pastilla.left
            anchors.rightMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            height: 7

            Rectangle {
                id: riel
                anchors.left: parent.left
                anchors.right: punto.left
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: rend.p.velo(0.1)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, uso / 100))
                    height: parent.height
                    radius: 3
                    color: rend.p.acento
                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                }
            }

            // El puntito suelto del final, como en la referencia
            Rectangle {
                id: punto
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: rend.p.velo(0.22)
            }
        }
    }

    RowLayout {
        // Una fila dentro de una columna se estira sola: hay que atarla.
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 128
        Layout.maximumHeight: 128
        spacing: 10

    Chip {
        titulo: "CPU"
        icono: "computer-symbolic"
        modelo: rend.s.equipo.cpu || ""
        grados: rend.s.cpuGrados
        uso: rend.s.cpu
    }

    Chip {
        titulo: "GPU"
        icono: "video-display-symbolic"
        modelo: rend.s.equipo.gpu || ""
        grados: rend.s.gpuGrados
        uso: rend.s.gpu
    }

    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

    // ---- Disco ----
    Tarjeta {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 258
        p: rend.p
        margen: 16

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: -6
            spacing: 14

            Aro {
                anchors.verticalCenter: parent.verticalCenter
                width: 108; height: 108
                p: rend.p
                grosor: 8
                valor: (rend.s.disco.porcentaje || 0) / 100
                icono: "drive-harddisk-symbolic"
                cifra: (rend.s.disco.porcentaje || 0) + "%"
                tamanoCifra: 22
                rotulo: "Usado"
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: "Disco"
                    color: rend.p.texto
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Text {
                    text: rend.s.disco.usado
                          ? (rend.s.disco.usado / 1073741824).toFixed(1) + " / "
                            + (rend.s.disco.total / 1073741824).toFixed(0) + " GiB"
                          : "—"
                    color: rend.p.tenue
                    font.pixelSize: 13
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            height: 28
            width: Math.min(parent.width, disco.implicitWidth + 26)
            radius: 14
            color: rend.p.velo(0.07)
            border.width: 1
            border.color: rend.p.borde

            Row {
                id: disco
                anchors.centerIn: parent
                spacing: 8
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13; height: 13
                    source: "drive-harddisk-symbolic"
                    isMask: true
                    color: rend.p.tenue
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(rend.s.disco.origen || "").replace("/dev/", "")
                    color: rend.p.texto
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // ---- Red ----
    Tarjeta {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 300
        p: rend.p
        titulo: "Red"
        icono: "network-wired-symbolic"
        placa: false

        Grafica {
            id: grafica
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(34, parent.height - cifras.implicitHeight - 10)
            p: rend.p
            serieA: rend.s.histBajada
            serieB: rend.s.histSubida
        }

        Column {
            id: cifras
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 5

            component Linea: Item {
                property string icono: ""
                property string rotulo: ""
                property string valor: ""
                width: parent.width
                height: 15

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12
                        source: icono
                        isMask: true
                        color: rend.p.tenue
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rotulo
                        color: rend.p.tenue
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: valor
                    color: rend.p.texto
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Linea { icono: "go-down-symbolic"; rotulo: "Bajada"; valor: rend.s.velocidad(rend.s.bajadaBs) }
            Linea { icono: "go-up-symbolic";   rotulo: "Subida"; valor: rend.s.velocidad(rend.s.subidaBs) }
            Linea {
                icono: "view-refresh-symbolic"
                rotulo: "Total"
                valor: rend.s.totales.rx !== undefined
                       ? "↓" + rend.s.tamano(rend.s.totales.rx) + "  ↑" + rend.s.tamano(rend.s.totales.tx)
                       : "—"
            }
        }
    }

    // ---- Memoria ----
    Tarjeta {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 182
        Layout.maximumWidth: 200
        p: rend.p
        titulo: "Memoria"
        icono: "media-flash-symbolic"
        placa: false

        Aro {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 104; height: 104
            p: rend.p
            grosor: 8
            valor: rend.s.ram / 100
            cifra: Math.round(rend.s.ram) + "%"
            tamanoCifra: 22
            rotulo: "Usada"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: rend.s.ramGB.toFixed(1) + " / " + rend.s.ramTotalGB.toFixed(0) + " GiB"
            color: rend.p.texto
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
    }
}
