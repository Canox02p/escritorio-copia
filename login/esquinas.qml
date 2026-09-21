    // ── Esquinas: escritorio, energía, usuarios y teclado ────────────
    // (trozo que generar.py mete en Main.qml; no es un fichero QML suelto)
    Item {
        id: esquinas
        anchors.fill: parent
        anchors.margins: 28
        visible: panel.visible

        // Arriba a la izquierda: escritorio con el que entrar
        Pastilla {
            id: pastillaSesion
            anchors.left: parent.left
            anchors.top: parent.top
            abierta: ui.menu === "sesiones"
            onClicked: ui.menu = abierta ? "" : "sesiones"
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ui.sesion ? ui.sesion.glifo : ""
                color: ui.acento
                font.family: ui.mono
                font.pixelSize: 18
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ui.sesion ? ui.sesion.nombre : "Escritorio"
                color: ui.texto
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0140}"
                color: ui.tenue
                font.family: ui.mono
                font.pixelSize: 16
                rotation: pastillaSesion.abierta ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 150 } }
            }
        }
        Menu {
            anchors.left: pastillaSesion.left
            anchors.top: pastillaSesion.bottom
            anchors.topMargin: 8
            abierto: ui.menu === "sesiones"
            titulo: "Escritorio"
            Repeater {
                model: sessionModel
                Fila {
                    actual: index === ui.indiceSesion
                    glifo: ui.glifoSesion(model.name + " " + model.file)
                    texto: model.name
                    detalle: model.comment || ""
                    onClicked: {
                        ui.indiceSesion = index;
                        ui.menu = "";
                        ui.enfocar();
                    }
                }
            }
        }

        // Arriba a la derecha: reiniciar y apagar
        Pastilla {
            anchors.right: parent.right
            anchors.top: parent.top
            relleno: 4
            BotonEsquina {
                texto: "Reiniciar"
                icono: "system-reboot"
                visible: sddm.canReboot
                onClicked: sddm.reboot()
            }
            BotonEsquina {
                texto: "Apagar"
                icono: "system-shutdown"
                visible: sddm.canPowerOff
                onClicked: sddm.powerOff()
            }
        }

        // Abajo a la izquierda: usuario (la lista se abre hacia arriba)
        Pastilla {
            id: pastillaUsuario
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            abierta: ui.menu === "usuarios"
            onClicked: ui.menu = abierta ? "" : "usuarios"
            Cara {
                anchors.verticalCenter: parent.verticalCenter
                icono: ui.manual || !ui.usuario ? "" : ui.usuario.icono
                inicial: ui.nombreReal.charAt(0).toUpperCase()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ui.nombreReal
                color: ui.texto
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0143}"
                color: ui.tenue
                font.family: ui.mono
                font.pixelSize: 16
                rotation: pastillaUsuario.abierta ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 150 } }
            }
        }
        Menu {
            anchors.left: pastillaUsuario.left
            anchors.bottom: pastillaUsuario.top
            anchors.bottomMargin: 8
            abierto: ui.menu === "usuarios"
            titulo: "Usuarios"
            Repeater {
                model: userModel
                Fila {
                    actual: !ui.manual && index === ui.indiceUsuario
                    texto: model.realName || model.name
                    detalle: model.name
                    usuario: true
                    cara: model.icon ? model.icon.toString() : ""
                    onClicked: {
                        ui.manual = false;
                        ui.indiceUsuario = index;
                        campo.text = "";
                        ui.menu = "";
                        campo.forceActiveFocus();
                    }
                }
            }
            // Otro usuario: se escribe el nombre aquí mismo
            Fila {
                actual: ui.manual
                glifo: "\u{F0014}"
                texto: ui.manual ? "" : "Otro usuario…"
                onClicked: {
                    ui.manual = true;
                    campo.text = "";
                    campoUsuario.forceActiveFocus();
                }
                TextInput {
                    id: campoUsuario
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 58
                    anchors.rightMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ui.manual
                    color: ui.texto
                    font.pixelSize: 14
                    selectionColor: ui.acento
                    selectedTextColor: ui.sobreAcento
                    onAccepted: { ui.menu = ""; campo.forceActiveFocus(); }
                    Keys.onEscapePressed: { ui.manual = false; text = ""; ui.menu = ""; campo.forceActiveFocus(); }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.text === ""
                        text: "Escribe el usuario"
                        color: ui.tenue
                        font.pixelSize: 14
                    }
                }
            }
        }

        // Abajo a la derecha: distribución del teclado y equipo
        Pastilla {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            interactiva: keyboard.layouts.length > 1
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F030C}"
                color: ui.acento
                font.family: ui.mono
                font.pixelSize: 17
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const l = keyboard.layouts[keyboard.currentLayout];
                    return (l ? l.shortName.toUpperCase() : "US") + " · " + sddm.hostName;
                }
                color: ui.texto
                font.pixelSize: 13
            }
        }
    }

    component Pastilla: Rectangle {
        id: pastilla
        default property alias contenido: filaPastilla.data
        property bool abierta: false
        property bool interactiva: true
        property int relleno: 18
        signal clicked()
        width: filaPastilla.implicitWidth + 2 * relleno
        height: 46
        radius: 23
        color: Qt.hsla(ui.matiz, 0.3, 0.08, abierta || (interactiva && zonaPastilla.containsMouse) ? 0.75 : 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, abierta ? 0.16 : 0.08)
        MouseArea {
            id: zonaPastilla
            anchors.fill: parent
            enabled: pastilla.interactiva
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pastilla.clicked()
        }
        Row {
            id: filaPastilla
            anchors.centerIn: parent
            spacing: 10
        }
    }

    component BotonEsquina: Rectangle {
        id: botonEsquina
        property string texto
        property string icono
        signal clicked()
        width: filaBoton.implicitWidth + 28
        height: 38
        radius: 19
        color: Qt.rgba(1, 1, 1, zonaBoton.containsMouse ? 0.12 : 0)
        Row {
            id: filaBoton
            anchors.centerIn: parent
            spacing: 8
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                source: botonEsquina.icono
                color: zonaBoton.containsMouse ? ui.acento : ui.texto
                isMask: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: botonEsquina.texto
                color: ui.texto
                font.pixelSize: 13
            }
        }
        MouseArea {
            id: zonaBoton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: botonEsquina.clicked()
        }
    }

    component Menu: Rectangle {
        id: menu
        default property alias contenido: columnaMenu.data
        property bool abierto: false
        property string titulo
        width: 300
        height: columnaMenu.implicitHeight + 20
        radius: 20
        color: Qt.hsla(ui.matiz, 0.3, 0.09, 0.94)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        visible: opacity > 0
        opacity: abierto ? 1 : 0
        scale: abierto ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }   // que el clic no cierre el menú
        Column {
            id: columnaMenu
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 4
            Text {
                leftPadding: 8
                bottomPadding: 2
                text: menu.titulo
                color: ui.tenue
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    component Fila: Rectangle {
        id: fila
        property bool actual: false
        property string glifo
        property string texto
        property string detalle
        property bool usuario: false   // fila de usuario: avatar (o inicial) en vez del glifo
        property string cara
        signal clicked()
        width: parent ? parent.width : 280
        height: 50
        radius: 14
        color: actual ? Qt.rgba(ui.acento.r, ui.acento.g, ui.acento.b, 0.22)
                      : Qt.rgba(1, 1, 1, zonaFila.containsMouse ? 0.08 : 0)
        MouseArea {
            id: zonaFila
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fila.clicked()
        }
        Item {
            id: huecoIcono
            x: 12
            width: 34; height: 34
            anchors.verticalCenter: parent.verticalCenter
            Cara {
                anchors.centerIn: parent
                visible: fila.usuario
                icono: fila.cara
                inicial: fila.texto.charAt(0).toUpperCase()
                tamano: 34
            }
            Text {
                anchors.centerIn: parent
                visible: !fila.usuario
                text: fila.glifo
                color: fila.actual ? ui.acento : ui.texto
                font.family: ui.mono
                font.pixelSize: 20
            }
        }
        Column {
            anchors.left: huecoIcono.right
            anchors.leftMargin: 12
            anchors.right: marca.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: fila.texto
                color: ui.texto
                font.pixelSize: 14
                font.weight: fila.actual ? Font.DemiBold : Font.Normal
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: fila.detalle !== "" && fila.detalle !== fila.texto
                text: fila.detalle
                color: ui.tenue
                font.family: ui.mono
                font.pixelSize: 11
            }
        }
        Text {
            id: marca
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: fila.actual ? "\u{F012C}" : ""
            color: ui.acento
            font.family: ui.mono
            font.pixelSize: 16
        }
    }

    // Avatar redondo; sin foto, la inicial sobre el acento
    component Cara: Rectangle {
        id: caraRedonda
        property string icono
        property string inicial
        property int tamano: 28
        width: tamano; height: tamano
        radius: tamano / 2
        color: Qt.hsla(ui.matiz, 0.4, 0.42, 1)
        Image {
            id: foto
            anchors.fill: parent
            source: ui.esCara(caraRedonda.icono) ? caraRedonda.icono : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        Rectangle { id: circuloFoto; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect {
            anchors.fill: parent
            source: foto
            visible: foto.status === Image.Ready
            maskEnabled: true
            maskSource: circuloFoto
        }
        Text {
            anchors.centerIn: parent
            visible: foto.status !== Image.Ready
            text: caraRedonda.inicial
            color: "white"
            font.pixelSize: caraRedonda.tamano * 0.45
            font.weight: Font.Bold
        }
    }
