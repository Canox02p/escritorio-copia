import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Estado de la batería: carga, salud, ciclos y consumo.
ColumnLayout {
    id: bat

    property var p
    property string dirCodigo: ""
    property var detalle: ({})

    spacing: 10

    P5Support.DataSource {
        id: energia
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }

    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            try { bat.detalle = JSON.parse(data["stdout"]) } catch (e) { }
        }
    }

    // ---- Perfil de energía: el mismo que cambia el atajo Meta+B ----
    property string perfil: ""

    readonly property var modos: [
        { clave: "power-saver", icono: "battery-profile-powersave-symbolic",   texto: "AHORRO" },
        { clave: "balanced",    icono: "battery-profile-balanced-symbolic",    texto: "EQUILIBRADO" },
        { clave: "performance", icono: "battery-profile-performance-symbolic", texto: "RENDIMIENTO" }
    ]

    readonly property int indiceModo: {
        for (let i = 0; i < bat.modos.length; ++i)
            if (bat.modos[i].clave === bat.perfil) return i
        return -1
    }

    P5Support.DataSource {
        id: perfiles
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            const salida = (data["stdout"] || "").trim()
            if (salida !== "") bat.perfil = salida
            // "vigilar" sale en cuanto el perfil cambia desde fuera: hay que rearmarlo.
            if (source.indexOf("vigilar") >= 0) rearmar.restart()
        }
    }

    function perfilLeer()    { perfiles.connectSource("bash '" + dirCodigo + "perfil.sh' leer") }
    function perfilVigilar() { perfiles.connectSource("bash '" + dirCodigo + "perfil.sh' vigilar") }
    function perfilPoner(v) {
        if (v === bat.perfil) return
        bat.perfil = v   // se pinta al momento; la salida del script lo confirma
        perfiles.connectSource("bash '" + dirCodigo + "perfil.sh' poner " + v)
    }

    Timer { id: rearmar; interval: 400; onTriggered: bat.perfilVigilar() }

    readonly property var datos: energia.data["Battery"] || ({})
    readonly property bool hay: !!datos["Has Battery"]
    readonly property int carga: datos["Percent"] || 0
    readonly property bool enchufado: !!(energia.data["AC Adapter"] || {})["Plugged in"]
    readonly property string estado: datos["State"] || ""

    function consultar() { ejecutar.connectSource("bash '" + dirCodigo + "bateria.sh'") }
    Component.onCompleted: { consultar(); perfilLeer(); perfilVigilar() }
    // Solo con la pestaña a la vista; al volver a verla se refresca en el acto
    readonly property bool aLaVista: bat.visible && !!bat.Window.window && bat.Window.window.visible
    onALaVistaChanged: if (aLaVista) consultar()
    Timer { interval: 30000; running: bat.aLaVista; repeat: true; onTriggered: bat.consultar() }

    // Tarjeta principal
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 96
        radius: 12
        color: bat.p.tarjeta
        border.width: 1
        border.color: bat.p.borde

        Kirigami.Icon {
            id: rayo
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34
            source: bat.enchufado ? "battery-full-charged-symbolic" : "battery-full-symbolic"
            isMask: true
            color: bat.p.acento
        }

        Column {
            anchors.left: rayo.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Row {
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bat.carga + "%"
                    color: bat.p.texto
                    font.pixelSize: 28
                    font.weight: Font.Bold
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: etiquetaEstado.implicitWidth + 18
                    height: 22
                    radius: 11
                    color: bat.p.velo(0.1)
                    border.width: 1
                    border.color: bat.p.borde
                    Text {
                        id: etiquetaEstado
                        anchors.centerIn: parent
                        text: bat.enchufado ? "ENCHUFADO" : "CON BATERÍA"
                        color: bat.p.texto
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.9
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 7
                radius: 4
                color: bat.p.velo(0.12)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, bat.carga / 100))
                    height: parent.height
                    radius: 4
                    color: bat.carga <= 15 && !bat.enchufado ? "#e0605f" : bat.p.acento
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
        }
    }

    // Dos cifras grandes
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        component Cifra: Rectangle {
            property string valor: ""
            property string rotulo: ""
            property string icono: ""
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            radius: 12
            color: bat.p.tarjeta
            border.width: 1
            border.color: bat.p.borde

            Column {
                anchors.centerIn: parent
                spacing: 3
                Kirigami.Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 15; height: 15
                    source: icono
                    isMask: true
                    color: bat.p.acento
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: valor
                    color: bat.p.texto
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: rotulo
                    color: bat.p.tenue
                    font.pixelSize: 9
                    font.letterSpacing: 0.9
                }
            }
        }

        Cifra {
            icono: "view-refresh-symbolic"
            valor: bat.detalle.ciclos !== undefined ? String(bat.detalle.ciclos) : "—"
            rotulo: "CICLOS"
        }
        Cifra {
            icono: "chronometer"
            valor: bat.detalle.restante ? bat.detalle.restante : "—"
            rotulo: "RESTANTE"
        }
        Cifra {
            icono: "battery-profile-performance-symbolic"
            valor: bat.detalle.vatios !== undefined ? bat.detalle.vatios + " W" : "—"
            rotulo: "CONSUMO"
        }
    }

    // Tira de datos finos
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 12
        color: bat.p.velo(0.05)
        border.width: 1
        border.color: bat.p.borde

        Row {
            anchors.centerIn: parent
            spacing: 26

            component Par: Row {
                property string k: ""
                property string v: ""
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: k
                    color: bat.p.tenue
                    font.pixelSize: 10
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: v
                    color: bat.p.texto
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Par { k: "Voltaje";  v: bat.detalle.voltaje !== undefined ? bat.detalle.voltaje + " V" : "—" }
            Par { k: "Salud";    v: bat.detalle.salud !== undefined ? bat.detalle.salud + "%" : "—" }
            Par { k: "Capacidad"; v: bat.detalle.capacidad !== undefined ? bat.detalle.capacidad + " Wh" : "—" }
        }
    }

    // Modo de energía: los tres perfiles de PowerDevil, con el resalte
    // deslizándose igual que en la barra de pestañas.
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: 12
        color: bat.p.velo(0.05)

        Item {
            anchors.fill: parent
            anchors.margins: 4

            Rectangle {
                id: resalteModo
                readonly property var objetivo: repetidorModos.count, repetidorModos.itemAt(bat.indiceModo)
                x: objetivo ? objetivo.x : 0
                width: objetivo ? objetivo.width : 0
                height: parent.height
                radius: 9
                color: bat.p.acento
                opacity: bat.indiceModo >= 0 && objetivo ? 1 : 0
                Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 3

                Repeater {
                    id: repetidorModos
                    model: bat.modos

                    delegate: Item {
                        id: modo
                        required property var modelData
                        required property int index
                        readonly property bool activo: bat.perfil === modo.modelData.clave

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property color tinta: modo.activo ? bat.p.sobreAcento
                                                                   : (sobreModo.containsMouse ? bat.p.texto : bat.p.tenue)

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: !modo.activo && sobreModo.containsMouse ? bat.p.velo(0.09) : "transparent"
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            scale: sobreModo.containsMouse && !modo.activo ? 1.06 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 15; height: 15
                                source: modo.modelData.icono
                                isMask: true
                                color: modo.tinta
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modo.modelData.texto
                                color: modo.tinta
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.9
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        MouseArea {
                            id: sobreModo
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bat.perfilPoner(modo.modelData.clave)
                        }
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
