import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Selector de fondos a pantalla completa: barra flotante arriba y tira de
// tarjetas inclinadas debajo, con la del foco crecida en el centro.
FocusScope {
    id: raiz

    signal cerrar()

    property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
    property bool simulado: false          // para las maquetas: no ejecuta nada

    property var fondos: []
    property string actual: ""
    property bool cargando: true
    property string modo: "todos"          // todos | recientes | video
    property string filtroColor: ""
    property string busqueda: ""
    property int indiceFoco: 0
    property int indiceAlta: -1            // a cuál se le carga ya la imagen original
    property bool ratonListo: false        // el puntero no manda hasta que se asienta

    readonly property color tinta:   "#f2f2f4"
    readonly property color barra:   Qt.rgba(0.09, 0.09, 0.10, 0.88)
    readonly property real  alto:    Math.round(height * 0.44)
    readonly property real  anchoFoco: Math.round(alto * 1.42)
    readonly property real  anchoNormal: Math.round(alto * 0.33)
    readonly property real  separacion: 10

    readonly property var colores: [
        { nombre: "rojo",     hex: "#e5484d" },
        { nombre: "naranja",  hex: "#f76b15" },
        { nombre: "amarillo", hex: "#ffc53d" },
        { nombre: "verde",    hex: "#30a46c" },
        { nombre: "azul",     hex: "#0090ff" },
        { nombre: "morado",   hex: "#8e4ec6" },
        { nombre: "rosa",     hex: "#e93d82" },
        { nombre: "gris",     hex: "#8b8d98" }
    ]

    readonly property var visibles: {
        let lista = fondos.filter(f =>
            (modo !== "video" || f.tipo === "video")
            && (filtroColor === "" || f.familia === filtroColor)
            && (busqueda === "" || f.nombre.toLowerCase().includes(busqueda.toLowerCase())))
        if (modo === "recientes")
            lista = lista.slice().sort((a, b) => b.fecha - a.fecha)
        return lista
    }

    readonly property var enfocado: indiceFoco >= 0 && indiceFoco < visibles.length
                                    ? visibles[indiceFoco] : null

    focus: true

    // ---------------------------------------------------------------- datos

    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.indexOf("lista.tsv") >= 0 && source.indexOf("fondos.sh") < 0) {
                // El listado en caché: se pinta al instante mientras se rehace
                if (raiz.fondos.length === 0) raiz.procesar(data["stdout"], false)
            } else if (source.indexOf("fondos.sh") >= 0) {
                raiz.procesar(data["stdout"], true)
            }
        }
    }

    function comillas(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }

    function cargar() {
        if (simulado) return
        ejecutar.connectSource("cat ~/.cache/selector-fondos/lista.tsv 2>/dev/null")
        ejecutar.connectSource("mkdir -p ~/.cache/selector-fondos && bash "
                               + comillas(dirCodigo + "fondos.sh")
                               + " | tee ~/.cache/selector-fondos/lista.tsv")
    }

    function aplicar(fondo) {
        if (!fondo) return
        actual = fondo.ruta
        if (simulado) return
        ejecutar.connectSource("bash " + comillas(dirCodigo + "aplicar.sh")
                               + " " + fondo.tipo + " " + comillas(fondo.ruta))
    }

    function procesar(salida, definitivo) {
        const previo = enfocado ? enfocado.ruta : ""
        const lista = []
        for (const linea of salida.split("\n")) {
            const c = linea.split("\t")
            if (c[0] === "actual" && c.length > 1) {
                actual = c[1]
            } else if (c[0] === "item" && c.length >= 6) {
                lista.push({
                    tipo: c[1], ruta: c[2], thumb: c[3],
                    familia: familiaColor(c[4]), nombre: c[5],
                    fecha: c.length > 6 ? parseInt(c[6]) || 0 : 0
                })
            }
        }
        fondos = lista
        if (definitivo) cargando = false
        recolocar(previo)
    }

    // Deja el foco donde estaba, o en el fondo que está puesto ahora.
    function recolocar(rutaPrevia) {
        const lista = visibles
        let i = rutaPrevia ? lista.findIndex(f => f.ruta === rutaPrevia) : -1
        if (i < 0) i = lista.findIndex(f => f.ruta === actual)
        if (i < 0) i = 0
        indiceFoco = Math.max(0, Math.min(i, lista.length - 1))
    }

    onVisiblesChanged: {
        if (indiceFoco >= visibles.length) indiceFoco = Math.max(0, visibles.length - 1)
    }

    // Elige el color dominante (favoreciendo los vivos) y lo agrupa en familia.
    function familiaColor(histograma) {
        let mejor = null, puntaje = -1
        for (const par of (histograma || "").split(",")) {
            const p = par.split(":")
            if (p.length < 2) continue
            const c = Qt.color(p[1])
            const vivo = c.hsvSaturation > 0.25 && c.hsvValue > 0.25
            const valor = parseInt(p[0]) * (vivo ? 1 : 0.3)
            if (valor > puntaje) { puntaje = valor; mejor = c }
        }
        if (!mejor || mejor.hsvSaturation < 0.2 || mejor.hsvValue < 0.2 || mejor.hsvHue < 0) return "gris"
        const h = mejor.hsvHue * 360
        if (h < 15 || h >= 345) return "rojo"
        if (h < 40) return "naranja"
        if (h < 65) return "amarillo"
        if (h < 165) return "verde"
        if (h < 250) return "azul"
        if (h < 290) return "morado"
        return "rosa"
    }

    function mover(paso) {
        if (visibles.length === 0) return
        indiceFoco = Math.max(0, Math.min(indiceFoco + paso, visibles.length - 1))
    }

    // La imagen original solo se carga si el foco se queda quieto un momento
    Timer {
        id: esperaAlta
        interval: 300
        onTriggered: raiz.indiceAlta = raiz.indiceFoco
    }
    onIndiceFocoChanged: { indiceAlta = -1; esperaAlta.restart() }

    // Al abrir, el puntero está donde quedó (encima del panel del borde), así
    // que durante un momento no se le hace caso o roba el foco de salida.
    Timer { interval: 600; running: true; onTriggered: raiz.ratonListo = true }

    Component.onCompleted: cargar()

    // ---------------------------------------------------------------- fondo

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.22
        TapHandler { onTapped: raiz.cerrar() }
    }

    // ------------------------------------------------------------ teclado

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (raiz.busqueda !== "") { campo.text = ""; buscador.abierto = false }
            else raiz.cerrar()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            raiz.mover(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            raiz.mover(1); event.accepted = true
        } else if (event.key === Qt.Key_Home) {
            raiz.indiceFoco = 0; event.accepted = true
        } else if (event.key === Qt.Key_End) {
            raiz.indiceFoco = Math.max(0, raiz.visibles.length - 1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                   || event.key === Qt.Key_Space) {
            raiz.aplicar(raiz.enfocado); event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            campo.text = campo.text.slice(0, -1)
            buscador.abierto = campo.text !== ""
            event.accepted = true
        } else if (event.text.length === 1 && event.text >= " ") {
            buscador.abierto = true
            campo.text += event.text
            event.accepted = true
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: rueda => {
            const d = rueda.angleDelta.y !== 0 ? rueda.angleDelta.y : rueda.angleDelta.x
            raiz.mover(d > 0 ? -1 : 1)
        }
    }

    // ------------------------------------------------------------- montaje

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((raiz.height - height) / 2) - Math.round(raiz.height * 0.02)
        spacing: Math.round(raiz.height * 0.028)
        width: parent.width

        // --- Barra flotante -------------------------------------------
        Rectangle {
            id: mando
            anchors.horizontalCenter: parent.horizontalCenter
            width: herramientas.width + 24
            height: 46
            radius: 13
            color: raiz.barra
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Row {
                id: herramientas
                anchors.centerIn: parent
                spacing: 7

                // Nombre del fondo apuntado
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(110, Math.min(265, rotulo.implicitWidth + 24))
                    height: 32
                    radius: 9
                    color: Qt.rgba(1, 1, 1, 0.09)
                    Behavior on width { NumberAnimation { duration: 160 } }

                    Text {
                        id: rotulo
                        anchors.centerIn: parent
                        width: parent.width - 20
                        text: raiz.enfocado ? raiz.enfocado.nombre
                                            : (raiz.cargando ? "cargando…" : "sin fondos")
                        color: raiz.tinta
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Modos: todos / recientes / videos
                Repeater {
                    model: [
                        { id: "todos",     dibujo: "rejilla" },
                        { id: "recientes", dibujo: "reloj" },
                        { id: "video",     dibujo: "play" }
                    ]
                    delegate: BotonMando {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        dibujo: modelData.dibujo
                        activo: raiz.modo === modelData.id
                        tinta: raiz.tinta
                        onPulsado: raiz.modo = modelData.id
                    }
                }

                Item { width: 4; height: 1 }

                // Filtro por color dominante
                Repeater {
                    model: raiz.colores
                    delegate: Rectangle {
                        id: pastilla
                        required property var modelData
                        readonly property bool activo: raiz.filtroColor === modelData.nombre
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 8
                        color: modelData.hex
                        border.width: activo || zona.containsMouse ? 2 : 0
                        border.color: raiz.tinta
                        scale: activo ? 1.06 : (zona.containsMouse ? 1.12 : 1)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        MouseArea {
                            id: zona
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: raiz.filtroColor = pastilla.activo ? "" : pastilla.modelData.nombre
                        }
                    }
                }

                Item { width: 2; height: 1 }

                // Buscador: la lupa abre un campo que crece hacia la izquierda
                Row {
                    id: buscador
                    property bool abierto: false
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: buscador.abierto ? 150 : 0
                        height: 30
                        radius: 9
                        clip: true
                        color: Qt.rgba(1, 1, 1, 0.09)
                        opacity: buscador.abierto ? 1 : 0
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        TextInput {
                            id: campo
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: raiz.tinta
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            selectByMouse: true
                            selectionColor: Qt.rgba(1, 1, 1, 0.25)
                            onTextChanged: raiz.busqueda = text
                        }
                    }

                    BotonMando {
                        anchors.verticalCenter: parent.verticalCenter
                        dibujo: "lupa"
                        activo: buscador.abierto
                        tinta: raiz.tinta
                        onPulsado: {
                            buscador.abierto = !buscador.abierto
                            if (!buscador.abierto) campo.text = ""
                        }
                    }
                }
            }
        }

        // --- Tira de tarjetas -----------------------------------------
        Item {
            width: parent.width
            height: raiz.alto
            clip: false

            Row {
                id: tira
                height: parent.height
                spacing: raiz.separacion
                // Centra la tarjeta con el foco: todas las anteriores miden lo normal
                x: Math.round(raiz.width / 2
                              - (raiz.indiceFoco * (raiz.anchoNormal + raiz.separacion)
                                 + raiz.anchoFoco / 2))
                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                Repeater {
                    id: repetidor
                    model: raiz.visibles
                    delegate: TarjetaFondo {
                        required property var modelData
                        required property int index
                        height: raiz.alto
                        datos: modelData
                        foco: index === raiz.indiceFoco
                        esActual: modelData.ruta === raiz.actual
                        cerca: Math.abs(index - raiz.indiceFoco) < 13
                        alta: index === raiz.indiceAlta
                        anchoNormal: raiz.anchoNormal
                        anchoFoco: raiz.anchoFoco
                        onApuntada: if (raiz.ratonListo) raiz.indiceFoco = index
                        onElegida: raiz.aplicar(modelData)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: raiz.visibles.length === 0
                text: raiz.cargando ? "buscando fondos…" : "no hay fondos con ese filtro"
                color: raiz.tinta
                opacity: 0.75
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }
        }
    }
}
