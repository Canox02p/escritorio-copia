import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support

// Lista de los atajos de teclado del sistema, agrupados por componente.
// Es un FocusScope reutilizable: la ventana que lo contiene solo lo enmarca.
FocusScope {
    id: vista

    property var p: paletaPropia
    property string dirCodigo: ""
    signal cerrar()

    Paleta { id: paletaPropia; dirCodigo: vista.dirCodigo }

    property var todos: []          // {componente, descripcion, teclas}
    property string filtro: ""
    property bool soloAsignados: true

    readonly property int cuantosConTecla: {
        let n = 0
        for (let i = 0; i < todos.length; i++) if (todos[i].teclas !== "") n++
        return n
    }

    // ---- Datos ----
    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: (fuente, datos) => {
            ejecutar.disconnectSource(fuente)
            const salida = datos["stdout"] || ""
            const filas = []
            const lineas = salida.split("\n")
            for (let i = 0; i < lineas.length; i++) {
                if (lineas[i] === "") continue
                const c = lineas[i].split("\t")
                if (c.length < 3) continue
                filas.push({ componente: c[0], descripcion: c[1], teclas: c[2] })
            }
            vista.todos = filas
        }
    }

    Component.onCompleted: ejecutar.connectSource('bash "' + dirCodigo + 'atajos.sh"')

    // ---- Filtrado y agrupado ----
    function visibles() {
        const t = filtro.toLowerCase()
        const fuera = []
        for (let i = 0; i < todos.length; i++) {
            const a = todos[i]
            if (soloAsignados && a.teclas === "") continue
            if (t !== "" && (a.descripcion + " " + a.teclas + " " + a.componente).toLowerCase().indexOf(t) < 0) continue
            fuera.push(a)
        }
        return fuera
    }

    // Se recalcula entero y se mete en un ListModel para poder usar `section`.
    function rehacer() {
        const lista = visibles()
        modelo.clear()
        for (let i = 0; i < lista.length; i++) modelo.append(lista[i])
    }

    ListModel { id: modelo }
    onTodosChanged: rehacer()
    onFiltroChanged: rehacer()
    onSoloAsignadosChanged: rehacer()

    // Parte una combinación en teclas sueltas. Ojo: "Meta++" es Meta y la tecla +.
    function partes(combo) {
        const marca = "\u0001"
        const t = combo.replace(/\+\+$/, "+" + marca).split("+")
        const r = []
        for (let i = 0; i < t.length; i++) {
            const x = t[i] === marca ? "+" : t[i]
            if (x !== "") r.push(vista.bonito(x))
        }
        return r
    }

    // Nombres largos de KDE a algo que se lea de un vistazo.
    function bonito(k) {
        switch (k) {
        case "Up": return "↑"
        case "Down": return "↓"
        case "Left": return "←"
        case "Right": return "→"
        case "Return":
        case "Enter": return "⏎"
        case "Backspace": return "⌫"
        case "Delete": return "Supr"
        case "Escape": return "Esc"
        case "Space": return "Espacio"
        case "Print": return "Impr Pant"
        case "Volume Up": return "Vol +"
        case "Volume Down": return "Vol −"
        case "Volume Mute": return "Silenciar"
        case "Microphone Mute": return "Mic"
        case "Microphone Volume Up": return "Mic +"
        case "Microphone Volume Down": return "Mic −"
        case "Monitor Brightness Up": return "Brillo +"
        case "Monitor Brightness Down": return "Brillo −"
        case "Media Play": return "▶"
        case "Media Pause": return "⏸"
        case "Media Next": return "⏭"
        case "Media Previous": return "⏮"
        case "Media Stop": return "⏹"
        case "PgUp": return "Re Pág"
        case "PgDown": return "Av Pág"
        }
        return k
    }

    // ---- Fondo ----
    Rectangle {
        anchors.fill: parent
        color: "#cc0a0a0c"
        MouseArea { anchors.fill: parent; onClicked: vista.cerrar() }
    }

    Keys.onEscapePressed: vista.cerrar()
    Keys.onPressed: evento => {
        if (evento.key === Qt.Key_Backspace) {
            vista.filtro = vista.filtro.slice(0, -1)
            evento.accepted = true
        } else if (evento.text && evento.text.length === 1 && evento.text >= " ") {
            vista.filtro += evento.text
            evento.accepted = true
        }
    }

    // ---- Tarjeta central ----
    Rectangle {
        id: tarjeta
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 980)
        height: Math.min(parent.height - 100, 760)
        radius: 20
        color: "#1c1b24"
        border.width: 1
        border.color: vista.p.borde

        // Que un clic dentro no cierre.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            // ---- Cabecera ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    font.family: "JetBrainsMono Nerd Font"
                    text: "ATAJOS DE TECLADO"
                    color: vista.p.texto
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.2
                }
                Text {
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true
                    text: modelo.count + " de " + vista.cuantosConTecla + " con tecla asignada"
                    color: vista.p.tenue
                    font.pixelSize: 11
                }
                Pildora {
                    p: vista.p
                    texto: "ASIGNADOS"
                    activa: vista.soloAsignados
                    onPulsada: vista.soloAsignados = true
                }
                Pildora {
                    p: vista.p
                    texto: "TODOS"
                    activa: !vista.soloAsignados
                    onPulsada: vista.soloAsignados = false
                }
            }

            // ---- Buscador (se escribe directamente, sin pinchar) ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 11
                color: vista.p.velo(0.06)
                border.width: 1
                border.color: vista.filtro !== "" ? vista.p.velo(0.30) : vista.p.borde
                Behavior on border.color { ColorAnimation { duration: 160 } }

                Text {
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: vista.filtro !== "" ? vista.filtro : "Escribe para buscar…"
                    color: vista.filtro !== "" ? vista.p.texto : vista.p.tenue
                    font.pixelSize: 13
                }
                Text {
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: vista.filtro !== ""
                    text: "Esc para salir · Retroceso borra"
                    color: vista.p.tenue
                    font.pixelSize: 10
                }
            }

            // ---- Lista ----
            ListView {
                id: lista
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: modelo
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds

                section.property: "componente"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    required property string section
                    width: lista.width
                    height: 34
                    Text {
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 7
                        text: parent.section.toUpperCase()
                        color: vista.p.acento
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.6
                        opacity: 0.85
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: vista.p.velo(0.10)
                    }
                }

                delegate: Rectangle {
                    id: fila
                    required property string descripcion
                    required property string teclas

                    width: lista.width
                    height: 38
                    radius: 9
                    color: zonaFila.containsMouse ? vista.p.velo(0.07) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea { id: zonaFila; anchors.fill: parent; hoverEnabled: true }

                    Text {
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: combinaciones.left
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: fila.descripcion
                        color: vista.p.texto
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        opacity: fila.teclas === "" ? 0.45 : 0.92
                    }

                    Row {
                        id: combinaciones
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // Una acción puede tener varias combinaciones; vienen
                        // separadas por " | " y se enseñan con una "o" en medio.
                        Repeater {
                            model: fila.teclas === "" ? [] : fila.teclas.split(" | ")

                            Row {
                                id: grupo
                                required property int index
                                required property string modelData
                                spacing: 8

                                Text {
                                    font.family: "JetBrainsMono Nerd Font"
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: grupo.index > 0
                                    text: "o"
                                    color: vista.p.tenue
                                    font.pixelSize: 10
                                    font.italic: true
                                }

                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: vista.partes(grupo.modelData)
                                        Tecla { p: vista.p; texto: modelData }
                                    }
                                }
                            }
                        }

                        Text {
                            font.family: "JetBrainsMono Nerd Font"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: fila.teclas === ""
                            text: "sin asignar"
                            color: vista.p.tenue
                            font.pixelSize: 10
                            font.italic: true
                        }
                    }
                }
            }
        }
    }
}
