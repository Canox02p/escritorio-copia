import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt

// Bluetooth: encender, buscar, ser visible, emparejar y conectar.
Item {
    id: vista

    property var p
    property string abierta: ""

    readonly property QtObject gestor: BluezQt.Manager
    readonly property var adaptador: gestor.usableAdapter
                                     || (gestor.adapters.length > 0 ? gestor.adapters[0] : null)
    readonly property bool encendido: !!adaptador && adaptador.powered && !gestor.bluetoothBlocked
    readonly property bool buscando: !!adaptador && adaptador.discovering

    BluezQt.DevicesModel { id: aparatos }

    function alternar() {
        if (!adaptador) return
        const nuevo = !vista.encendido
        gestor.bluetoothBlocked = !nuevo
        adaptador.powered = nuevo
    }

    // El icono que publica cada aparato suele ser a color y queda como una
    // mancha al teñirlo; se traduce a uno simbólico.
    function iconoAparato(ap) {
        const n = (ap && ap.icon) ? String(ap.icon) : ""
        if (n.indexOf("headset") >= 0 || n.indexOf("headphone") >= 0) return "audio-headphones-symbolic"
        if (n.indexOf("audio") >= 0 || n.indexOf("speaker") >= 0) return "audio-speakers-symbolic"
        if (n.indexOf("phone") >= 0) return "smartphone-symbolic"
        if (n.indexOf("mouse") >= 0) return "input-mouse-symbolic"
        if (n.indexOf("keyboard") >= 0) return "input-keyboard-symbolic"
        if (n.length > 9 && n.slice(-9) === "-symbolic") return n
        return "preferences-system-bluetooth-symbolic"
    }

    function buscar() {
        if (!adaptador) return
        if (adaptador.discovering) { adaptador.stopDiscovery(); relojBusqueda.stop() }
        else { adaptador.startDiscovery(); relojBusqueda.restart() }
    }

    // Al abrir (y en cuanto se encienda) busca sola; para a los 30 s
    // para no dejar la radio trabajando de balde.
    function buscarSola() {
        if (vista.encendido && vista.adaptador && !vista.adaptador.discovering) {
            vista.adaptador.startDiscovery()
            relojBusqueda.restart()
        }
    }

    Timer { id: relojBusqueda; interval: 30000; onTriggered: if (vista.adaptador && vista.adaptador.discovering) vista.adaptador.stopDiscovery() }
    Timer { id: relojArranque; interval: 350; onTriggered: vista.buscarSola() }

    Component.onCompleted: relojArranque.start()
    onEncendidoChanged: if (encendido) relojArranque.restart()

    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Column {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "BLUETOOTH"
                    color: vista.p.texto
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                }
                Text {
                    width: parent.width
                    text: !vista.adaptador ? "Sin adaptador"
                          : (!vista.encendido ? "Apagado"
                          : (vista.gestor.connectedDevices.length > 0
                             ? vista.gestor.connectedDevices.length + " conectado(s)"
                             : (vista.buscando ? "Buscando…" : "Encendido")))
                    color: vista.p.tenue
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Interruptor {
                p: vista.p
                texto: vista.encendido ? "ENCENDIDO" : "APAGADO"
                activo: vista.encendido
                encendido: !!vista.adaptador
                onAlternado: vista.alternar()
            }
            Pildora {
                p: vista.p
                texto: vista.buscando ? "BUSCANDO…" : "BUSCAR"
                tamano: 10; holgura: 10
                activa: vista.buscando
                onPulsada: vista.buscar()
            }
            Pildora {
                p: vista.p
                texto: "VISIBLE"
                tamano: 10; holgura: 10
                activa: !!vista.adaptador && vista.adaptador.discoverable
                onPulsada: if (vista.adaptador) vista.adaptador.discoverable = !vista.adaptador.discoverable
            }
        }

        ListView {
            id: filas
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0                     // el hueco va dentro de cada fila
            model: vista.encendido ? aparatos : null
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: Deslizadera { p: vista.p }

            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 140 } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic } }

            delegate: Item {
                id: fila
                required property var model

                readonly property var aparato: model.Device
                readonly property string clave: aparato ? aparato.address : ""
                readonly property bool conectado: !!aparato && aparato.connected
                readonly property bool emparejado: !!aparato && aparato.paired
                readonly property bool desplegada: vista.abierta === fila.clave

                width: filas.width - 12
                height: 46 + (desplegada ? 38 : 0) + 6
                Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: marco
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(0, fila.height - 6)
                    radius: 12
                    color: fila.conectado ? vista.p.hueco : (sobre.hovered ? vista.p.velo(0.08) : vista.p.tarjeta)
                    border.width: 1
                    border.color: fila.conectado ? vista.p.acento : vista.p.borde
                    clip: true
                    scale: toque.pressed ? 0.99 : 1
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    HoverHandler { id: sobre; cursorShape: Qt.PointingHandCursor }

                Item {
                    id: cabecera
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 46

                    TapHandler {
                        id: toque
                        onTapped: vista.abierta = fila.desplegada ? "" : fila.clave
                    }

                    Kirigami.Icon {
                        id: simbolo
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18
                        source: vista.iconoAparato(fila.aparato)
                        isMask: true
                        color: fila.conectado ? vista.p.acento : vista.p.texto
                        opacity: fila.conectado ? 1 : 0.75
                    }

                    Column {
                        anchors.left: simbolo.right
                        anchors.leftMargin: 11
                        anchors.right: derecha.left
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: (fila.aparato && (fila.aparato.name || fila.aparato.address)) || ""
                            color: vista.p.texto
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: fila.conectado ? "CONECTADO" : (fila.emparejado ? "EMPAREJADO" : "SIN EMPAREJAR")
                            color: fila.conectado ? vista.p.acento : vista.p.tenue
                            font.pixelSize: 9
                            font.letterSpacing: 0.8
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        id: derecha
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: fila.aparato && fila.aparato.battery ? fila.aparato.battery.percentage + "%" : ""
                            color: vista.p.tenue
                            font.pixelSize: 11
                        }
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12
                            source: "arrow-down"
                            isMask: true
                            color: vista.p.tenue
                            rotation: fila.desplegada ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Row {
                    anchors { top: cabecera.bottom; left: parent.left }
                    anchors.leftMargin: 12
                    spacing: 7
                    opacity: fila.desplegada ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Pildora {
                        p: vista.p
                        texto: fila.conectado ? "DESCONECTAR" : "CONECTAR"
                        tamano: 10; holgura: 12
                        activa: !fila.conectado
                        onPulsada: {
                            if (!fila.aparato) return
                            if (fila.conectado) fila.aparato.disconnectFromDevice()
                            else fila.aparato.connectToDevice()
                        }
                    }
                    Pildora {
                        p: vista.p
                        texto: "EMPAREJAR"
                        tamano: 10; holgura: 12
                        visible: !fila.emparejado
                        onPulsada: if (fila.aparato) fila.aparato.pair()
                    }
                    Pildora {
                        p: vista.p
                        texto: "DE CONFIANZA"
                        tamano: 10; holgura: 12
                        visible: fila.emparejado
                        activa: !!fila.aparato && fila.aparato.trusted
                        onPulsada: if (fila.aparato) fila.aparato.trusted = !fila.aparato.trusted
                    }
                }
                }
            }
        }

        // Círculo girando mientras busca
        Ruleta {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
            p: vista.p
            lado: 20
            girando: vista.buscando
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !vista.encendido || filas.count === 0
        text: !vista.adaptador ? "Este equipo no tiene Bluetooth"
              : (!vista.encendido ? "El Bluetooth está apagado"
              : (vista.buscando ? "Buscando dispositivos…" : "No hay dispositivos — pulsa BUSCAR"))
        color: vista.p.velo(0.3)
        font.pixelSize: 12
    }
}
