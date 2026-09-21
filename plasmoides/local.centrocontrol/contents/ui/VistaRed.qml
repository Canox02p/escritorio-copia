import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.networkmanagement as PlasmaNM

// Redes: conectar, desconectar, olvidar, buscar y contraseña.
Item {
    id: vista

    property var p
    property string abierta: ""      // red desplegada
    property string aviso: ""
    property var mejores: ({})       // nombre de red -> fila que se enseña

    PlasmaNM.Handler { id: gestor }
    PlasmaNM.NetworkStatus { id: estado }
    PlasmaNM.EnabledConnections { id: activadas }
    PlasmaNM.AppletProxyModel {
        id: lista
        sourceModel: PlasmaNM.NetworkModel {}
    }

    Connections {
        target: gestor
        function onConnectionActivationFailed(connectionPath, message) {
            vista.aviso = message !== "" ? message : "No se pudo conectar"
            relojAviso.restart()
        }
    }
    Timer { id: relojAviso; interval: 7000; onTriggered: vista.aviso = "" }

    // La misma red aparece varias veces (una por punto de acceso y perfil
    // guardado): se queda solo la mejor de cada nombre.
    function recalcular() {
        const roles = lista.KItemModels.KRoleNames
        const rNombre = roles.role("Name")
        const rEstado = roles.role("ConnectionState")
        const rSenal  = roles.role("Signal")
        const rRuta   = roles.role("ConnectionPath")
        const elegida = {}
        const puntos = {}
        for (let i = 0; i < lista.rowCount(); i++) {
            const idx = lista.index(i, 0)
            const nombre = lista.data(idx, rNombre) || ""
            if (nombre === "") continue
            const estado = lista.data(idx, rEstado)
            let punto = (lista.data(idx, rSenal) || 0)
            if ((lista.data(idx, rRuta) || "") !== "") punto += 200
            if (estado === PlasmaNM.Enums.Activated || estado === PlasmaNM.Enums.Activating) punto += 1000
            if (!(nombre in puntos) || punto > puntos[nombre]) {
                puntos[nombre] = punto
                elegida[nombre] = i
            }
        }
        vista.mejores = elegida
    }

    Timer { id: relojFiltro; interval: 150; onTriggered: vista.recalcular() }

    // Al abrir busca sola, para que la lista esté fresca
    Timer {
        id: relojArranque
        interval: 350
        onTriggered: if (activadas.wirelessEnabled) gestor.requestScan()
    }

    Component.onCompleted: { recalcular(); relojArranque.start() }
    Connections {
        target: activadas
        function onWirelessEnabledChanged() { if (activadas.wirelessEnabled) relojArranque.restart() }
    }

    Connections {
        target: lista
        function onRowsInserted() { relojFiltro.restart() }
        function onRowsRemoved() { relojFiltro.restart() }
        function onModelReset() { relojFiltro.restart() }
        function onDataChanged() { relojFiltro.restart() }
        function onLayoutChanged() { relojFiltro.restart() }
    }

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
                    text: "REDES"
                    color: vista.p.texto
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                }
                Text {
                    width: parent.width
                    text: estado.activeConnections !== "" ? estado.activeConnections : "Sin conexión"
                    color: vista.p.tenue
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Interruptor {
                p: vista.p
                texto: activadas.wirelessEnabled ? "WIFI" : "WIFI"
                activo: activadas.wirelessEnabled
                onAlternado: gestor.enableWireless(!activadas.wirelessEnabled)
            }
            Pildora {
                p: vista.p
                icono: "network-flightmode-on-symbolic"   // modo avión
                tamano: 10; holgura: 12
                activa: PlasmaNM.Configuration.airplaneModeEnabled
                onPulsada: {
                    const nuevo = !PlasmaNM.Configuration.airplaneModeEnabled
                    gestor.enableAirplaneMode(nuevo)
                    PlasmaNM.Configuration.airplaneModeEnabled = nuevo
                }
            }
            Pildora {
                p: vista.p
                texto: gestor.scanning ? "BUSCANDO…" : "BUSCAR"
                tamano: 10; holgura: 10
                activa: gestor.scanning
                onPulsada: gestor.requestScan()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: vista.aviso !== "" ? 26 : 0
            visible: vista.aviso !== ""
            radius: 8
            color: Qt.rgba(0.88, 0.38, 0.37, 0.16)
            border.width: 1
            border.color: Qt.rgba(0.88, 0.38, 0.37, 0.45)
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: vista.aviso
                color: "#f0a9a8"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            MouseArea { anchors.fill: parent; onClicked: vista.aviso = "" }
        }

        ListView {
            id: filas
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0                     // el hueco va dentro de cada fila
            model: activadas.wirelessEnabled ? lista : null
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: Deslizadera { p: vista.p }

            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 140 } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic } }

            delegate: Item {
                id: fila
                required property var model
                required property int index

                readonly property string nombre: model.Name || model.ItemUniqueName || ""
                readonly property string clave: nombre + model.DevicePath
                readonly property bool conectada: model.ConnectionState === PlasmaNM.Enums.Activated
                readonly property bool conectando: model.ConnectionState === PlasmaNM.Enums.Activating
                readonly property bool guardada: (model.ConnectionPath || "") !== ""
                readonly property bool protegida: model.SecurityType !== undefined
                                                  && model.SecurityType !== PlasmaNM.Enums.NoneSecurity
                                                  && model.SecurityType !== PlasmaNM.Enums.UnknownSecurity
                readonly property bool desplegada: vista.abierta === fila.clave
                readonly property bool repetida: vista.mejores[nombre] !== undefined
                                                 && vista.mejores[nombre] !== index

                width: filas.width - 12
                height: repetida ? 0 : (46 + (desplegada ? acciones.implicitHeight + 10 : 0)) + 6
                visible: !repetida
                Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: marco
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(0, fila.height - 6)
                    radius: 12
                    color: fila.conectada ? vista.p.hueco : (sobre.hovered ? vista.p.velo(0.08) : vista.p.tarjeta)
                    border.width: 1
                    border.color: fila.conectada ? vista.p.acento : vista.p.borde
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
                            id: senal
                            anchors.left: parent.left
                            anchors.leftMargin: 13
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18
                            source: fila.model.ConnectionIcon || "network-wireless-symbolic"
                            isMask: true
                            color: fila.conectada ? vista.p.acento : vista.p.texto
                            opacity: fila.conectada ? 1 : 0.75
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        Column {
                            anchors.left: senal.right
                            anchors.leftMargin: 11
                            anchors.right: derecha.left
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: fila.nombre
                                color: vista.p.texto
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: fila.conectada ? "CONECTADA"
                                      : (fila.conectando ? "CONECTANDO…"
                                      : (fila.guardada ? "GUARDADA" : (fila.protegida ? "PROTEGIDA" : "ABIERTA")))
                                color: fila.conectada ? vista.p.acento : vista.p.tenue
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
                                text: fila.model.Signal !== undefined && fila.model.Signal > 0 ? fila.model.Signal + "%" : ""
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

                    RowLayout {
                        id: acciones
                        anchors { top: cabecera.bottom; left: parent.left; right: parent.right }
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 7
                        opacity: fila.desplegada ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Rectangle {
                            id: campoClave
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            visible: !fila.conectada && fila.protegida && !fila.guardada
                            radius: 14
                            color: vista.p.velo(0.07)
                            border.width: 1
                            border.color: entradaClave.activeFocus ? vista.p.acento : vista.p.borde
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            TextInput {
                                id: entradaClave
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: vista.p.texto
                                font.pixelSize: 11
                                clip: true
                                onAccepted: gestor.addAndActivateConnection(fila.model.DevicePath, fila.model.SpecificPath, text)
                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: entradaClave.text === ""
                                    text: "Contraseña…"
                                    color: vista.p.velo(0.3)
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Item { Layout.fillWidth: true; visible: !campoClave.visible }

                        Pildora {
                            p: vista.p
                            texto: fila.conectada ? "DESCONECTAR" : "CONECTAR"
                            tamano: 10; holgura: 12
                            activa: !fila.conectada
                            onPulsada: {
                                vista.aviso = ""
                                if (fila.conectada) {
                                    gestor.deactivateConnection(fila.model.ConnectionPath, fila.model.DevicePath)
                                } else if (fila.guardada) {
                                    gestor.activateConnection(fila.model.ConnectionPath, fila.model.DevicePath, fila.model.SpecificPath)
                                } else if (fila.protegida && entradaClave.text !== "") {
                                    gestor.addAndActivateConnection(fila.model.DevicePath, fila.model.SpecificPath, entradaClave.text)
                                } else {
                                    gestor.addAndActivateConnection(fila.model.DevicePath, fila.model.SpecificPath)
                                }
                                vista.abierta = ""
                            }
                        }

                        Pildora {
                            p: vista.p
                            texto: "OLVIDAR"
                            tamano: 10; holgura: 12
                            visible: fila.guardada && !fila.conectada
                            onPulsada: {
                                gestor.removeConnection(fila.model.ConnectionPath)
                                vista.abierta = ""
                            }
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
            girando: gestor.scanning
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !activadas.wirelessEnabled || filas.count === 0
        text: !activadas.wirelessEnabled ? "El wifi está apagado"
              : (gestor.scanning ? "Buscando redes…" : "No se ve ninguna red")
        color: vista.p.velo(0.3)
        font.pixelSize: 12
    }
}
