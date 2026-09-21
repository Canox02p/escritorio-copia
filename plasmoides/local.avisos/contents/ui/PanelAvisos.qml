import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.volume as Vol
import org.kde.notificationmanager as NM

// Centro de avisos: lista arriba, accesos rápidos abajo.
Item {
    id: root

    property var p
    property string dirCodigo: ""

    // Sin fondo propio: el panel ya pinta su marco redondeado y esmerilado.
    // Poner otro rectángulo encima dibujaba una segunda esquina por dentro.

    // ---- Sonido ----
    readonly property var salida: Vol.PreferredDevice.sink
    readonly property var entrada: Vol.PreferredDevice.source
    readonly property bool silenciado: !!salida && salida.muted
    readonly property bool micApagado: !!entrada && entrada.muted

    // ---- No molestar ----
    // Server es un singleton: instanciarlo tumba el componente entero
    NM.Settings { id: ajustesAvisos }
    readonly property bool noMolestar: ajustesAvisos.notificationsInhibitedUntil > new Date()
                                       || NM.Server.inhibited

    function alternarNoMolestar() {
        if (noMolestar) {
            ajustesAvisos.notificationsInhibitedUntil = undefined
            ajustesAvisos.revokeApplicationInhibitions()
        } else {
            // Hasta que se vuelva a tocar
            const hasta = new Date()
            hasta.setFullYear(hasta.getFullYear() + 1)
            ajustesAvisos.notificationsInhibitedUntil = hasta
        }
        ajustesAvisos.save()
    }

    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }
    function correr(orden) { ejecutar.connectSource(orden) }


        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 11

            // ---- Cabecera ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Notificaciones"
                    color: p.texto
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: Math.max(20, cuenta.implicitWidth + 12)
                    height: 20
                    radius: 10
                    color: avisos.cuantas > 0 ? p.acento : p.velo(0.1)
                    Text {
                        id: cuenta
                        anchors.centerIn: parent
                        text: avisos.cuantas
                        color: avisos.cuantas > 0 ? p.sobreAcento : p.tenue
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }

            // ---- Lista ----
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: p.velo(0.035)
                border.width: 1
                border.color: p.borde

                PanelNotificaciones {
                    id: avisos
                    anchors.fill: parent
                    anchors.margins: 10
                    p: root.p
                }
            }

            // ---- Accesos rápidos ----
            Text {
                text: "ACCESOS RÁPIDOS"
                color: p.tenue
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 8
                columnSpacing: 8

                Conmutador {
                    Layout.fillWidth: true
                    p: root.p
                    icono: root.silenciado ? "audio-volume-muted" : "audio-volume-high"
                    pista: root.silenciado ? "Sonido apagado" : "Silenciar"
                    activo: root.silenciado
                    onPulsado: if (root.salida) root.salida.muted = !root.salida.muted
                }

                Conmutador {
                    Layout.fillWidth: true
                    p: root.p
                    icono: root.micApagado ? "microphone-sensitivity-muted" : "audio-input-microphone"
                    pista: root.micApagado ? "Micrófono apagado" : "Micrófono"
                    activo: root.micApagado
                    onPulsado: if (root.entrada) root.entrada.muted = !root.entrada.muted
                }

                Conmutador {
                    Layout.fillWidth: true
                    p: root.p
                    icono: root.noMolestar ? "notifications-disabled" : "notifications"
                    pista: root.noMolestar ? "Avisos silenciados" : "No molestar"
                    activo: root.noMolestar
                    onPulsado: root.alternarNoMolestar()
                }

                Conmutador {
                    Layout.fillWidth: true
                    p: root.p
                    icono: "configure"
                    pista: "Ajustes del sistema"
                    onPulsado: root.correr("systemsettings")
                }
            }

            // ---- Los dos botones anchos ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                component Ancho: Rectangle {
                    property string icono: ""
                    property string texto: ""
                    property bool alerta: false
                    signal pulsado()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 13
                    color: zonaAncho.containsMouse ? p.velo(0.13) : p.velo(0.06)
                    border.width: 1
                    border.color: p.borde
                    scale: zonaAncho.pressed ? 0.98 : 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 9
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            source: icono
                            isMask: true
                            color: alerta ? "#e0605f" : p.texto
                            opacity: 0.9
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: texto
                            color: p.texto
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: zonaAncho
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.pulsado()
                    }
                }

                Ancho {
                    icono: "edit-delete"
                    texto: "Vaciar avisos"
                    alerta: true
                    onPulsado: avisos.limpiar()
                }

                Ancho {
                    icono: "preferences-desktop-wallpaper"
                    texto: "Fondos"
                    // Abre el selector a pantalla completa (capa superpuesta).
                    onPulsado: root.correr("bash ~/.local/share/plasma/plasmoids/local.selectorfondos/contents/code/abrir.sh")
                }
            }
        }
}
