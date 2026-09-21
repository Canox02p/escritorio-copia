import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// Administrador de tareas: CPU / GPU / memoria arriba (eligen el orden) y la
// lista de procesos agrupados por programa, como el de Windows.
Rectangle {
    id: admin

    property var p
    property string dirCodigo: ""
    property bool activo: true
    property int orden: 0           // 0 CPU, 1 GPU, 2 memoria
    signal elegir(int i)

    // Totales que ya mide la tira del panel
    property real cpuTotal: 0
    property real gpuTotal: 0
    property real ramPorcentaje: 0
    property real cpuTemp: 0
    property real gpuTemp: 0

    property var datos: null
    property var abiertos: ({})     // grupos desplegados
    property var cerrando: ({})     // grupos a los que ya se mandó la señal
    property string confirmando: "" // grupo crítico esperando el segundo clic
    property string filtro: ""
    property var cuentas: ({})
    property bool trasCerrar: false

    // El diálogo ya pinta su marco translúcido; nada de fondo propio.
    color: "transparent"

    readonly property var columnas: [
        { icono: "cpu-symbolic",                   texto: "CPU" },
        { icono: "freon-gpu-temperature-symbolic", texto: "GPU" },
        { icono: "memory-symbolic",                texto: "MEMORIA" }
    ]
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int anchoPct: 58
    readonly property int anchoRam: 82
    readonly property int anchoBoton: 34

    // ---------- Datos ----------
    P5Support.DataSource {
        id: lector
        engine: "executable"
        connectedSources: []
        onNewData: (fuente, datos) => {
            disconnectSource(fuente)
            if (fuente.indexOf(" matar ") >= 0) {
                admin.trasCerrar = true
                admin.refrescar()
                return
            }
            try {
                admin.datos = JSON.parse(datos["stdout"])
                admin.sincronizar()
                // Si el programa sigue vivo (se negó a cerrar o volvió a abrir), deja de verse apagado
                if (admin.trasCerrar) {
                    admin.trasCerrar = false
                    admin.cerrando = ({})
                }
                // La primera lectura solo sirve de referencia: la segunda, ya
                if (!admin.datos.listo) pronto.restart()
            } catch (e) { }
        }
    }

    function refrescar() {
        if (dirCodigo === "") return
        lector.connectSource("python3 '" + dirCodigo + "procesos.py' listar")
    }

    Timer {
        interval: 2000
        running: admin.activo && admin.dirCodigo !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: admin.refrescar()
    }
    Timer { id: pronto; interval: 700; onTriggered: admin.refrescar() }
    Timer { id: olvidar; interval: 3500; onTriggered: admin.confirmando = "" }

    function finalizar(clave, pids, critico) {
        if (critico && confirmando !== clave) {
            confirmando = clave
            olvidar.restart()
            return
        }
        confirmando = ""
        const c = Object.assign({}, cerrando)
        c[clave] = true
        cerrando = c
        lector.connectSource("python3 '" + dirCodigo + "procesos.py' matar " + pids)
    }

    function alternar(clave) {
        const a = Object.assign({}, abiertos)
        if (a[clave]) delete a[clave]
        else a[clave] = true
        abiertos = a
        sincronizar()
    }

    // ---------- Formatos ----------
    function tamano(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(b >= 10737418240 ? 1 : 2) + " GB"
        if (b >= 1048576) return (b / 1048576).toFixed(b < 10485760 ? 1 : 0) + " MB"
        return Math.max(0, Math.round(b / 1024)) + " KB"
    }
    function pct(v) {
        if (v <= 0) return "0%"
        return (v < 10 ? v.toFixed(1) : Math.round(v)) + "%"
    }

    // ---------- Lista ----------
    ListModel { id: filas }

    function valor(x) {
        return orden === 0 ? x.cpu : (orden === 1 ? x.gpu : x.ram)
    }
    function comparar(a, b) {
        return (valor(b) - valor(a)) || (b.ram - a.ram) || a.nombre.localeCompare(b.nombre)
    }

    function construir() {
        const grupos = (datos && datos.grupos) ? datos.grupos.slice() : []
        const f = filtro.trim().toLowerCase()
        const vistos = grupos.filter(g => {
            if (f === "") return true
            if (g.nombre.toLowerCase().indexOf(f) >= 0) return true
            return g.hijos.some(h => h.nombre.toLowerCase().indexOf(f) >= 0 || String(h.pid).indexOf(f) === 0)
        })
        vistos.sort((a, b) => (b.app - a.app) || admin.comparar(a, b))

        const salida = []
        const n = { "APLICACIONES": 0, "SEGUNDO PLANO": 0 }
        for (const g of vistos) {
            const seccion = g.app ? "APLICACIONES" : "SEGUNDO PLANO"
            const clave = "g:" + g.nombre
            n[seccion]++
            salida.push({
                clave: clave, tipo: 0, seccion: seccion,
                nombre: g.nombre, icono: g.icono || "", cuenta: g.hijos.length,
                cpu: g.cpu, gpu: g.gpu, ram: g.ram,
                pids: g.pids.join(" "), critico: g.critico, detalle: ""
            })
            if (abiertos[clave] && g.hijos.length > 1) {
                const hijos = g.hijos.slice().sort(admin.comparar)
                for (const h of hijos) {
                    salida.push({
                        clave: "p:" + h.pid, tipo: 1, seccion: seccion,
                        nombre: h.nombre, icono: "", cuenta: 0,
                        cpu: h.cpu, gpu: h.gpu, ram: h.ram,
                        pids: String(h.pid), critico: g.critico,
                        detalle: "PID " + h.pid + "  ·  " + h.orden
                    })
                }
            }
        }
        cuentas = n
        return salida
    }

    // Se actualiza fila a fila en vez de rehacer el modelo: así no parpadea,
    // no se pierde el desplazamiento y las filas se deslizan al reordenarse.
    function sincronizar() {
        const nuevas = construir()
        for (let i = 0; i < nuevas.length; i++) {
            const n = nuevas[i]
            let j = -1
            for (let k = i; k < filas.count; k++) {
                if (filas.get(k).clave === n.clave) { j = k; break }
            }
            if (j < 0) {
                filas.insert(i, n)
            } else {
                if (j !== i) filas.move(j, i, 1)
                filas.set(i, n)
            }
        }
        if (filas.count > nuevas.length) filas.remove(nuevas.length, filas.count - nuevas.length)
    }

    onOrdenChanged: sincronizar()
    onFiltroChanged: sincronizar()

    // ---------- Piezas ----------
    component Celda: Item {
        property real valor: 0
        property real tope: 100
        property string texto: ""
        property bool resaltada: false

        Layout.preferredWidth: admin.anchoPct
        Layout.fillHeight: true

        // Cuanto más gasta, más se ilumina la celda (el amarillo de Windows, en blanco)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            radius: 7
            readonly property real carga: Math.max(0, Math.min(1, parent.valor / parent.tope))
            color: admin.p.velo(carga > 0.004 ? 0.05 + carga * 0.32 : 0)
            Behavior on color { ColorAnimation { duration: 400 } }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: parent.texto
            color: parent.valor / parent.tope > 0.5 ? admin.p.acento : admin.p.texto
            opacity: parent.valor > 0 || parent.resaltada ? 1 : 0.45
            font.family: admin.mono
            font.pixelSize: 11
            font.weight: parent.resaltada ? Font.Bold : Font.Normal
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 9

        // ---- Tres pestañas: eligen por qué se ordena ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            radius: 12
            color: admin.p.velo(0.05)

            Item {
                anchors.fill: parent
                anchors.margins: 4

                Rectangle {
                    id: resalte
                    readonly property var objetivo: repetidor.count, repetidor.itemAt(admin.orden)
                    x: objetivo ? objetivo.x : 0
                    width: objetivo ? objetivo.width : 0
                    height: parent.height
                    radius: 9
                    color: admin.p.acento
                    Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        id: repetidor
                        model: admin.columnas

                        delegate: Item {
                            id: pestana
                            required property var modelData
                            required property int index
                            readonly property bool activa: admin.orden === index
                            readonly property color tinta: activa ? admin.p.sobreAcento
                                                                  : (sobre.containsMouse ? admin.p.texto : admin.p.tenue)
                            readonly property string cifra: index === 0 ? admin.pct(admin.cpuTotal)
                                                          : index === 1 ? admin.pct(admin.gpuTotal)
                                                          : admin.pct(admin.ramPorcentaje)
                            readonly property string extra: index === 0 ? (admin.cpuTemp > 0 ? Math.round(admin.cpuTemp) + " °C" : "")
                                                          : index === 1 ? (admin.gpuTemp > 0 ? Math.round(admin.gpuTemp) + " °C" : "")
                                                          : (admin.datos ? admin.tamano(admin.datos.ramUsada) + " / " + admin.tamano(admin.datos.ramTotal) : "")

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: !pestana.activa && sobre.containsMouse ? admin.p.velo(0.09) : "transparent"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 10
                                scale: sobre.containsMouse && !pestana.activa ? 1.04 : 1
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                Kirigami.Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20; height: 20
                                    source: pestana.modelData.icono
                                    isMask: true
                                    color: pestana.tinta
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Row {
                                        spacing: 6
                                        Text {
                                            anchors.baseline: cifraTxt.baseline
                                            text: pestana.modelData.texto
                                            color: pestana.tinta
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                            font.letterSpacing: 0.9
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                        }
                                        Text {
                                            id: cifraTxt
                                            text: pestana.cifra
                                            color: pestana.tinta
                                            font.family: admin.mono
                                            font.pixelSize: 15
                                            font.weight: Font.Bold
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                        }
                                    }
                                    Text {
                                        visible: text !== ""
                                        text: pestana.extra
                                        color: pestana.tinta
                                        opacity: 0.75
                                        font.family: admin.mono
                                        font.pixelSize: 9
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: sobre
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: admin.elegir(pestana.index)
                            }
                        }
                    }
                }
            }
        }

        // ---- Buscador ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 10
            color: entrada.activeFocus ? admin.p.hueco : admin.p.tarjeta
            border.width: 1
            border.color: entrada.activeFocus ? admin.p.velo(0.4) : admin.p.borde
            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }

            Kirigami.Icon {
                id: lupa
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                source: "system-search-symbolic"
                isMask: true
                color: admin.p.tenue
            }

            TextInput {
                id: entrada
                anchors.left: lupa.right
                anchors.leftMargin: 9
                anchors.right: resumen.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: admin.p.texto
                selectionColor: admin.p.velo(0.3)
                font.pixelSize: 12
                clip: true
                onTextChanged: admin.filtro = text
                Keys.onEscapePressed: text = ""

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entrada.text === ""
                    text: "Buscar por nombre o PID…"
                    color: admin.p.velo(0.35)
                    font.pixelSize: 12
                }
            }

            Text {
                id: resumen
                anchors.right: limpiar.visible ? limpiar.left : parent.right
                anchors.rightMargin: limpiar.visible ? 8 : 12
                anchors.verticalCenter: parent.verticalCenter
                readonly property int total: admin.datos ? admin.datos.grupos.reduce((s, g) => s + g.hijos.length, 0) : 0
                text: total + " PROCESOS"
                color: admin.p.tenue
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }

            Kirigami.Icon {
                id: limpiar
                visible: entrada.text !== ""
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                source: "edit-clear-symbolic"
                isMask: true
                color: borrar.containsMouse ? admin.p.texto : admin.p.tenue
                MouseArea {
                    id: borrar
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entrada.text = ""
                }
            }
        }

        // ---- Cabecera de columnas ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 4

            component Cabeza: Text {
                property int indice: -1
                readonly property bool activa: admin.orden === indice
                Layout.preferredWidth: admin.anchoPct
                horizontalAlignment: Text.AlignRight
                rightPadding: 8
                color: activa ? admin.p.acento : (toque.containsMouse ? admin.p.texto : admin.p.tenue)
                font.pixelSize: 9
                font.weight: activa ? Font.Bold : Font.DemiBold
                font.letterSpacing: 1.1
                MouseArea {
                    id: toque
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: admin.elegir(parent.indice)
                }
            }

            Text {
                Layout.fillWidth: true
                text: "NOMBRE"
                color: admin.p.tenue
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            Cabeza { indice: 0; text: (activa ? "▾ " : "") + "CPU" }
            Cabeza { indice: 1; text: (activa ? "▾ " : "") + "GPU" }
            Cabeza { indice: 2; text: (activa ? "▾ " : "") + "MEMORIA"; Layout.preferredWidth: admin.anchoRam }
            Item { Layout.preferredWidth: admin.anchoBoton }
        }

        // ---- Procesos ----
        ListView {
            id: lista
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: filas
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: false
            QQC2.ScrollBar.vertical: Deslizadera { p: admin.p }

            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                    NumberAnimation { property: "scale"; to: 0.96; duration: 180 }
                }
            }
            move: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic } }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; to: 1; duration: 150 }
                NumberAnimation { property: "scale"; to: 1; duration: 150 }
            }

            section.property: "seccion"
            section.delegate: Item {
                required property string section
                width: lista.width - 10
                height: 26
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: parent.section + "  ·  " + (admin.cuentas[parent.section] || 0)
                    color: admin.p.tenue
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.3
                }
            }

            delegate: Item {
                id: fila

                required property int index
                required property string clave
                required property int tipo
                required property string nombre
                required property string icono
                required property int cuenta
                required property real cpu
                required property real gpu
                required property real ram
                required property string pids
                required property bool critico
                required property string detalle

                readonly property bool hijo: tipo === 1
                readonly property bool abierto: !!admin.abiertos[clave]
                readonly property bool muriendo: !!admin.cerrando[clave]
                readonly property bool preguntando: admin.confirmando === clave

                width: lista.width - 10
                height: hijo ? 34 : 38
                opacity: muriendo ? 0.4 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: fila.hijo ? 22 : 0
                    radius: fila.hijo ? 8 : 10
                    color: sobreFila.containsMouse ? admin.p.velo(0.09)
                                               : (fila.hijo ? admin.p.velo(0.03) : admin.p.tarjeta)
                    border.width: fila.hijo ? 0 : 1
                    border.color: fila.abierto ? admin.p.velo(0.3) : admin.p.borde
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                // Clic en la fila: desplegar los procesos del grupo
                MouseArea {
                    id: sobreFila
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: fila.cuenta > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (fila.cuenta > 1) admin.alternar(fila.clave)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: fila.hijo ? 34 : 8
                    anchors.rightMargin: 2
                    spacing: 4

                    Kirigami.Icon {
                        visible: !fila.hijo
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        source: "pan-end-symbolic"
                        isMask: true
                        color: admin.p.tenue
                        opacity: fila.cuenta > 1 ? 1 : 0
                        rotation: fila.abierto ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    Item {
                        visible: !fila.hijo
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 20
                        Layout.leftMargin: 2
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            visible: fila.icono !== ""
                            source: fila.icono
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            visible: fila.icono === ""
                            source: "application-x-executable-symbolic"
                            isMask: true
                            color: admin.p.tenue
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.leftMargin: 4
                        spacing: 1

                        Row {
                            width: parent.width
                            spacing: 6
                            Text {
                                id: rotulo
                                width: Math.min(implicitWidth, parent.width - (numero.visible ? numero.width + 6 : 0))
                                text: fila.nombre
                                color: admin.p.texto
                                font.pixelSize: fila.hijo ? 11 : 12
                                font.weight: fila.hijo ? Font.Normal : Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                id: numero
                                anchors.baseline: rotulo.baseline
                                visible: fila.cuenta > 1
                                text: "(" + fila.cuenta + ")"
                                color: admin.p.tenue
                                font.family: admin.mono
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            visible: fila.hijo
                            width: parent.width
                            text: fila.detalle
                            color: admin.p.tenue
                            font.family: admin.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Celda { valor: fila.cpu; texto: admin.pct(fila.cpu); resaltada: admin.orden === 0 }
                    Celda { valor: fila.gpu; texto: admin.pct(fila.gpu); resaltada: admin.orden === 1 }
                    Celda {
                        Layout.preferredWidth: admin.anchoRam
                        valor: fila.ram
                        tope: 2147483648        // 2 GB ya es mucho para un programa
                        texto: admin.tamano(fila.ram)
                        resaltada: admin.orden === 2
                    }

                    // ---- Finalizar tarea ----
                    Item {
                        Layout.preferredWidth: admin.anchoBoton
                        Layout.fillHeight: true

                        Rectangle {
                            id: boton
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            height: fila.hijo ? 22 : 26
                            width: fila.preguntando ? aviso.implicitWidth + 20 : height
                            radius: 8
                            readonly property bool rojo: pulsar.containsMouse || fila.preguntando
                            color: rojo ? "#e5484d" : admin.p.velo(sobreFila.containsMouse ? 0.08 : 0.04)
                            border.width: rojo ? 0 : 1
                            border.color: admin.p.velo(sobreFila.containsMouse ? 0.22 : 0.1)
                            scale: pulsar.pressed ? 0.9 : 1
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 90 } }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                visible: !fila.preguntando
                                width: 12; height: 12
                                source: "window-close-symbolic"
                                isMask: true
                                color: boton.rojo ? "white" : admin.p.texto
                                opacity: boton.rojo || sobreFila.containsMouse ? 1 : 0.55
                            }
                            Text {
                                id: aviso
                                anchors.centerIn: parent
                                visible: fila.preguntando
                                text: "¿SEGURO?"
                                color: "white"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }

                            MouseArea {
                                id: pulsar
                                anchors.fill: parent
                                anchors.margins: -3
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !fila.muriendo
                                onClicked: admin.finalizar(fila.clave, fila.pids, fila.critico)
                            }

                            QQC2.ToolTip {
                                visible: pulsar.containsMouse && !fila.preguntando
                                delay: 600
                                text: fila.critico ? "Finalizar (es parte del escritorio: pide confirmación)"
                                    : (fila.cuenta > 1 ? "Finalizar los " + fila.cuenta + " procesos" : "Finalizar tarea")
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: filas.count === 0
                text: admin.datos ? "Nada coincide con «" + admin.filtro + "»" : "Leyendo procesos…"
                color: admin.p.velo(0.35)
                font.pixelSize: 12
            }
        }
    }
}
