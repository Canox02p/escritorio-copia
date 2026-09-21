import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Centro de control: barra de pestañas con icono y letras + contenido.
Rectangle {
    id: centro

    property var p: paletaPropia
    property string dirCodigo: ""
    property int vista: 0
    signal cerrar()

    readonly property var pestanas: [
        { icono: "network-wireless",                     texto: "RED" },
        { icono: "bluetooth-symbolic",                   texto: "BLUETOOTH" },
        { icono: "audio-volume-high",                    texto: "AUDIO" },
        { icono: "brightness-high-symbolic",             texto: "BRILLO" },
        { icono: "battery-full-symbolic",                texto: "BATERÍA" },
        { icono: "system-shutdown",                      texto: "SESIÓN" }
    ]

    // Nada de fondo ni borde propios: el diálogo ya pinta su marco redondeado
    // y translúcido. Un rectángulo encima lo aplanaba y dibujaba una segunda
    // esquina que no encajaba con la suya.
    color: "transparent"

    Paleta { id: paletaPropia; dirCodigo: centro.dirCodigo }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ---- Pestañas ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 12
            color: centro.p.velo(0.05)
            border.width: 0

            Item {
                id: zona
                anchors.fill: parent
                anchors.margins: 4

                // El resalte se desliza de una pestaña a otra
                Rectangle {
                    id: resalte
                    readonly property var objetivo: repetidor.count, repetidor.itemAt(centro.vista)
                    x: objetivo ? objetivo.x : 0
                    width: objetivo ? objetivo.width : 0
                    height: parent.height
                    radius: 9
                    color: centro.p.acento
                    opacity: objetivo ? 1 : 0
                    Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        id: repetidor
                        model: centro.pestanas

                        delegate: Item {
                            id: pestana
                            required property var modelData
                            required property int index
                            readonly property bool activa: centro.vista === index

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property color tinta: activa ? centro.p.sobreAcento
                                                                  : (sobre.containsMouse ? centro.p.texto : centro.p.tenue)

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: !pestana.activa && sobre.containsMouse ? centro.p.velo(0.09) : "transparent"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                scale: sobre.containsMouse && !pestana.activa ? 1.06 : 1
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                Kirigami.Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 17; height: 17
                                    source: pestana.modelData.icono
                                    isMask: true
                                    color: pestana.tinta
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: pestana.modelData.texto
                                    color: pestana.tinta
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.7
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            MouseArea {
                                id: sobre
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: centro.vista = pestana.index
                            }
                        }
                    }
                }
            }
        }

        // ---- Contenido, con cruce suave entre pestañas ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            component Hoja: Item {
                property int indice: 0
                readonly property bool activa: centro.vista === indice

                anchors.fill: parent
                opacity: activa ? 1 : 0
                visible: opacity > 0.01
                enabled: activa
                transform: Translate {
                    y: activa ? 0 : 12
                    Behavior on y { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            }

            Hoja { indice: 0; VistaRed       { anchors.fill: parent; p: centro.p } }
            Hoja { indice: 1; VistaBluetooth { anchors.fill: parent; p: centro.p } }
            Hoja { indice: 2; VistaAudio     { anchors.fill: parent; p: centro.p } }
            Hoja { indice: 3; VistaBrillo    { anchors.fill: parent; p: centro.p } }
            Hoja { indice: 4; VistaBateria   { anchors.fill: parent; p: centro.p; dirCodigo: centro.dirCodigo } }
            Hoja { indice: 5; VistaSesion    { anchors.fill: parent; p: centro.p; onCerrar: centro.cerrar() } }
        }
    }
}
