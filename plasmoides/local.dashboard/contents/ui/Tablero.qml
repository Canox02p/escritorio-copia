import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Tablero: barra de pestañas con icono y letras, y las cinco vistas.
Rectangle {
    id: tablero

    property var p: paletaPropia
    property string dirCodigo: ""
    property var portapapeles
    property int vista: 0
    property bool abierto: true   // el popup está a la vista
    signal ajustes()

    readonly property var pestanas: [
        { icono: "view-list-details",       texto: "INICIO" },
        { icono: "media-playback-playing-symbolic", texto: "MÚSICA" },
        { icono: "computer-symbolic",       texto: "SISTEMA" },
        { icono: "weather-few-clouds-symbolic", texto: "TIEMPO" },
        { icono: "edit-paste-symbolic",     texto: "PORTAPAPELES" }
    ]

    // Nada de fondo ni borde propios: el diálogo de Plasma ya pinta su marco
    // redondeado y desenfocado. Cualquier rectángulo nuestro encima dibujaba
    // una segunda esquina que no encajaba con la suya.
    color: "transparent"

    Paleta { id: paletaPropia; dirCodigo: tablero.dirCodigo }
    Sensores { id: sensores; dirCodigo: tablero.dirCodigo; activo: tablero.abierto }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ---- Pestañas ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 12
            color: tablero.p.velo(0.05)
            border.width: 0

            Item {
                id: zona
                anchors.fill: parent
                anchors.margins: 4

                Rectangle {
                    id: resalte
                    readonly property var objetivo: repetidor.count, repetidor.itemAt(tablero.vista)
                    x: objetivo ? objetivo.x : 0
                    width: objetivo ? objetivo.width : 0
                    height: parent.height
                    radius: 9
                    color: tablero.p.acento
                    opacity: objetivo ? 1 : 0
                    Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        id: repetidor
                        model: tablero.pestanas

                        delegate: Item {
                            id: pestana
                            required property var modelData
                            required property int index
                            readonly property bool activa: tablero.vista === index
                            readonly property color tinta: activa ? tablero.p.sobreAcento
                                                                  : (sobre.containsMouse ? tablero.p.texto : tablero.p.tenue)

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: !pestana.activa && sobre.containsMouse ? tablero.p.velo(0.09) : "transparent"
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
                                onClicked: tablero.vista = pestana.index
                            }
                        }
                    }
                }
            }
        }

        // ---- Contenido con cruce suave ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            component Hoja: Item {
                property int indice: 0
                readonly property bool activa: tablero.vista === indice

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

            Hoja {
                indice: 0
                VistaInicio {
                    anchors.fill: parent
                    p: tablero.p
                    dirCodigo: tablero.dirCodigo
                    s: sensores
                    onIrA: seccion => tablero.vista = seccion
                }
            }

            Hoja {
                indice: 1
                Pieza {
                    anchors.fill: parent
                    p: tablero.p
                    titulo: "REPRODUCTOR"
                    icono: "media-playback-playing-symbolic"
                    PanelMusica {
                        anchors.fill: parent
                        p: tablero.p
                        dirCodigo: tablero.dirCodigo
                        grande: true
                    }
                }
            }

            Hoja {
                indice: 2
                VistaRendimiento {
                    anchors.fill: parent
                    p: tablero.p
                    s: sensores
                }
            }

            Hoja {
                indice: 3
                VistaClima {
                    anchors.fill: parent
                    p: tablero.p
                    dirCodigo: tablero.dirCodigo
                }
            }

            Hoja {
                indice: 4
                Pieza {
                    anchors.fill: parent
                    p: tablero.p
                    titulo: "PORTAPAPELES"
                    icono: "edit-paste-symbolic"

                    extra: [
                        Rectangle {
                            width: Math.max(17, cuentaClip.implicitWidth + 11)
                            height: 17
                            radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            color: clips.cuantas > 0 ? tablero.p.acento : tablero.p.velo(0.1)
                            Text {
                                id: cuentaClip
                                anchors.centerIn: parent
                                text: clips.cuantas
                                color: clips.cuantas > 0 ? tablero.p.sobreAcento : tablero.p.tenue
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        },
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "LIMPIAR"
                            color: limpiaClip.containsMouse ? tablero.p.acento : tablero.p.velo(0.35)
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                            MouseArea {
                                id: limpiaClip
                                anchors.fill: parent
                                anchors.margins: -5
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clips.limpiar()
                            }
                        }
                    ]

                    PanelPortapapeles {
                        id: clips
                        anchors.fill: parent
                        p: tablero.p
                        modelo: tablero.portapapeles
                    }
                }
            }
        }
    }
}
