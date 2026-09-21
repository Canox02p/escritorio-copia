import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
    property var fondos: []
    property string actual: ""
    property bool cargando: false
    property string filtroTipo: "todos"
    property string filtroColor: ""
    property string busqueda: ""

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

    readonly property var visibles: fondos.filter(f =>
        (filtroTipo === "todos" || f.tipo === filtroTipo)
        && (filtroColor === "" || f.familia === filtroColor)
        && (busqueda === "" || f.nombre.toLowerCase().includes(busqueda.toLowerCase())))

    Plasmoid.icon: "preferences-desktop-wallpaper"
    toolTipMainText: "Selector de fondos"
    toolTipSubText: "Cambia tu fondo de pantalla (imágenes y videos)"

    Component.onCompleted: cargar()
    onExpandedChanged: if (root.expanded) cargar()

    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.includes("fondos.sh")) {
                root.procesar(data["stdout"])
            }
        }
    }

    function comillas(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function cargar() {
        cargando = true
        ejecutar.connectSource("bash " + comillas(dirCodigo + "fondos.sh"))
    }

    function aplicar(fondo) {
        actual = fondo.ruta
        ejecutar.connectSource("bash " + comillas(dirCodigo + "aplicar.sh") + " " + fondo.tipo + " " + comillas(fondo.ruta))
    }

    function procesar(salida) {
        const lista = []
        for (const linea of salida.split("\n")) {
            const c = linea.split("\t")
            if (c[0] === "actual" && c.length > 1) {
                actual = c[1]
            } else if (c[0] === "item" && c.length >= 6) {
                lista.push({ tipo: c[1], ruta: c[2], thumb: c[3], familia: familiaColor(c[4]), nombre: c[5] })
            }
        }
        fondos = lista
        cargando = false
    }

    // Elige el color dominante (favoreciendo los colores vivos) y lo agrupa en una familia.
    function familiaColor(histograma) {
        let mejor = null
        let puntaje = -1
        for (const par of histograma.split(",")) {
            const p = par.split(":")
            if (p.length < 2) continue
            const c = Qt.color(p[1])
            const vivo = c.hsvSaturation > 0.25 && c.hsvValue > 0.25
            const valor = parseInt(p[0]) * (vivo ? 1 : 0.3)
            if (valor > puntaje) {
                puntaje = valor
                mejor = c
            }
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

    fullRepresentation: ColumnLayout {
        id: vista
        Layout.preferredWidth: Kirigami.Units.gridUnit * 62
        Layout.preferredHeight: Kirigami.Units.gridUnit * 21
        Layout.minimumWidth: Kirigami.Units.gridUnit * 36
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        spacing: Kirigami.Units.largeSpacing

        readonly property color tenue: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)

        // Barra de filtros
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
            implicitWidth: filtros.implicitWidth + Kirigami.Units.largeSpacing * 2
            implicitHeight: filtros.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: height / 2
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

            RowLayout {
                id: filtros
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing * 2

                Repeater {
                    model: [
                        { id: "todos",  icono: "view-grid",            texto: "Todos" },
                        { id: "imagen", icono: "image-x-generic",      texto: "Imágenes" },
                        { id: "video",  icono: "media-playback-start", texto: "Videos" }
                    ]
                    delegate: PlasmaComponents3.ToolButton {
                        required property var modelData
                        icon.name: modelData.icono
                        text: modelData.texto
                        display: QQC2.AbstractButton.IconOnly
                        checkable: true
                        checked: root.filtroTipo === modelData.id
                        onClicked: root.filtroTipo = modelData.id
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    color: vista.tenue
                }

                Repeater {
                    model: root.colores
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool activo: root.filtroColor === modelData.nombre
                        implicitWidth: Math.round(Kirigami.Units.gridUnit * 1.3)
                        implicitHeight: implicitWidth
                        radius: Kirigami.Units.smallSpacing * 1.5
                        color: modelData.hex
                        border.width: activo ? 2 : 0
                        border.color: Kirigami.Theme.textColor
                        scale: activo || zonaChip.containsMouse ? 1.18 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        MouseArea {
                            id: zonaChip
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.filtroColor = chip.activo ? "" : chip.modelData.nombre
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    color: vista.tenue
                }

                PlasmaComponents3.TextField {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    placeholderText: "Buscar…"
                    onTextChanged: root.busqueda = text
                }
            }
        }

        // Tira de tarjetas inclinadas
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: tira
                readonly property real inclinacion: 0.22
                readonly property real altoTarjeta: height - Kirigami.Units.largeSpacing * 2

                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: Kirigami.Units.largeSpacing
                leftMargin: inclinacion * altoTarjeta / 2 + Kirigami.Units.largeSpacing
                rightMargin: leftMargin
                clip: true
                cacheBuffer: width
                boundsBehavior: Flickable.StopAtBounds
                model: root.visibles

                delegate: Item {
                    id: tarjeta
                    required property var modelData
                    readonly property real k: tira.inclinacion
                    readonly property bool esActual: modelData.ruta === root.actual

                    width: Math.round(tira.altoTarjeta * 0.6)
                    height: tira.height
                    z: sobre.hovered ? 2 : (esActual ? 1 : 0)

                    Item {
                        id: cuerpo
                        // Inclina la tarjeta sin mover su centro: x' = x - k*y + k*alto/2
                        readonly property matrix4x4 corte: Qt.matrix4x4(1, -tarjeta.k, 0, tarjeta.k * height / 2,
                                                                         0, 1, 0, 0,
                                                                         0, 0, 1, 0,
                                                                         0, 0, 0, 1)
                        width: parent.width
                        height: tira.altoTarjeta
                        anchors.centerIn: parent
                        scale: sobre.hovered ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        Item {
                            id: marco
                            anchors.fill: parent
                            clip: true
                            transform: Matrix4x4 { matrix: cuerpo.corte }

                            // La imagen lleva la inclinación inversa para verse derecha dentro del marco
                            Image {
                                x: -tarjeta.k * cuerpo.height
                                width: cuerpo.width + tarjeta.k * cuerpo.height
                                height: cuerpo.height
                                source: "file://" + tarjeta.modelData.thumb
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                mipmap: true
                                opacity: status === Image.Ready ? 1 : 0
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, tarjeta.k, 0, 0,
                                                         0, 1, 0, 0,
                                                         0, 0, 1, 0,
                                                         0, 0, 0, 1)
                                }
                                Behavior on opacity { NumberAnimation { duration: 250 } }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "black"
                                opacity: sobre.hovered || tarjeta.esActual ? 0 : 0.3
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * 0.4
                                opacity: sobre.hovered || tarjeta.esActual ? 1 : 0
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.8) }
                                }
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }

                            HoverHandler {
                                id: sobre
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: root.aplicar(tarjeta.modelData)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            antialiasing: true
                            border.width: tarjeta.esActual ? 3 : (sobre.hovered ? 2 : 1)
                            border.color: tarjeta.esActual ? Kirigami.Theme.highlightColor
                                                           : Qt.rgba(1, 1, 1, sobre.hovered ? 0.85 : 0.18)
                            transform: Matrix4x4 { matrix: cuerpo.corte }
                        }

                        // Marca de video (en el centro la inclinación no desplaza nada)
                        Rectangle {
                            visible: tarjeta.modelData.tipo === "video"
                            anchors.centerIn: parent
                            width: Kirigami.Units.gridUnit * 2.4
                            height: width
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0.55)
                            border.color: Qt.rgba(1, 1, 1, 0.6)

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: parent.width * 0.5
                                height: width
                                source: "media-playback-start"
                                color: "white"
                                isMask: true
                            }
                        }

                        // Nombre, desplazado para seguir la inclinación de la tarjeta
                        ColumnLayout {
                            width: parent.width - Kirigami.Units.largeSpacing * 2
                            y: parent.height - height - Kirigami.Units.largeSpacing
                            x: (parent.width - width) / 2 - tarjeta.k * (y + height / 2) + tarjeta.k * parent.height / 2
                            spacing: 0
                            opacity: sobre.hovered || tarjeta.esActual ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: tarjeta.modelData.nombre
                                color: "white"
                                font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                visible: tarjeta.esActual
                                text: "✓ Actual"
                                color: "white"
                                opacity: 0.85
                                font: Kirigami.Theme.smallFont
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            // La rueda del mouse desplaza la tira horizontalmente
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    const minX = tira.originX - tira.leftMargin
                    const maxX = Math.max(minX, tira.originX + tira.contentWidth + tira.rightMargin - tira.width)
                    tira.contentX = Math.min(maxX, Math.max(minX, tira.contentX - delta))
                }
            }

            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: tira.count === 0
                iconName: root.cargando ? "view-refresh" : "preferences-desktop-wallpaper"
                text: root.cargando ? "Cargando fondos…" : "No hay fondos con ese filtro"
            }
        }
    }
}
