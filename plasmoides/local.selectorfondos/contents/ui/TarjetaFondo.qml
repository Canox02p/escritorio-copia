import QtQuick

// Una tarjeta inclinada de la tira. El marco se corta en paralelogramo y la
// imagen lleva la inclinación inversa para verse derecha dentro del corte.
Item {
    id: tarjeta

    property var datos: null
    property bool foco: false
    property bool esActual: false
    property bool cerca: false          // ¿merece la pena cargar su miniatura?
    property bool alta: false           // cambia a la imagen original, sin comprimir
    property real inclinacion: 0.26
    property real anchoNormal: 132
    property real anchoFoco: 560

    signal elegida()
    signal apuntada()

    readonly property real k: inclinacion
    readonly property real sangria: k * height / 2   // cuánto sobresale por cada lado

    width: foco ? anchoFoco : anchoNormal
    z: foco ? 20 : (esActual ? 10 : 1)
    Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    // x' = x - k*y + k*alto/2  →  inclina sin mover el centro
    readonly property matrix4x4 corte: Qt.matrix4x4(1, -k, 0, sangria,
                                                    0, 1, 0, 0,
                                                    0, 0, 1, 0,
                                                    0, 0, 0, 1)
    readonly property matrix4x4 corteInverso: Qt.matrix4x4(1, k, 0, 0,
                                                           0, 1, 0, 0,
                                                           0, 0, 1, 0,
                                                           0, 0, 0, 1)

    // Sombra: tres paralelogramos negros cada vez más grandes por detrás.
    Repeater {
        model: tarjeta.foco ? 3 : 0
        delegate: Item {
            id: sombra
            required property int index
            readonly property real crece: 5 + index * 7
            x: -crece
            y: -crece + 6
            width: tarjeta.width + crece * 2
            height: tarjeta.height + crece * 2
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -tarjeta.k, 0, tarjeta.k * sombra.height / 2,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }
            Rectangle { anchors.fill: parent; color: "black"; opacity: 0.11 }
        }
    }

    Item {
        id: marco
        anchors.fill: parent
        // El recorte va por capa y no con clip: con una matriz de corte, clip
        // pinta de negro lo que queda fuera en vez de dejarlo transparente.
        layer.enabled: true
        layer.smooth: true
        transform: Matrix4x4 { matrix: tarjeta.corte }

        Rectangle {
            anchors.fill: parent
            color: "#1b1b1f"
        }

        // Miniatura (siempre) y, cuando la tarjeta tiene el foco, el original encima.
        Image {
            id: mini
            x: -tarjeta.k * tarjeta.height
            width: tarjeta.width + tarjeta.k * tarjeta.height
            height: tarjeta.height
            source: tarjeta.cerca && tarjeta.datos ? "file://" + tarjeta.datos.thumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: true
            opacity: status === Image.Ready ? 1 : 0
            transform: Matrix4x4 { matrix: tarjeta.corteInverso }
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }

        Image {
            id: original
            x: mini.x
            width: mini.width
            height: mini.height
            source: tarjeta.alta && tarjeta.datos && tarjeta.datos.tipo === "imagen"
                    ? "file://" + tarjeta.datos.ruta : ""
            sourceSize.height: 1000
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            mipmap: true
            opacity: status === Image.Ready ? 1 : 0
            transform: Matrix4x4 { matrix: tarjeta.corteInverso }
            Behavior on opacity { NumberAnimation { duration: 260 } }
        }

        // Las que no tienen el foco se oscurecen un poco
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: tarjeta.foco ? 0 : 0.28
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }

        HoverHandler {
            id: sobre
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: if (hovered) tarjeta.apuntada()
        }
        TapHandler { onTapped: tarjeta.elegida() }
    }

    // Filo del paralelogramo
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        antialiasing: true
        border.width: tarjeta.esActual ? 2 : 1
        border.color: tarjeta.esActual ? "#f2f2f4"
                                       : Qt.rgba(1, 1, 1, tarjeta.foco ? 0.3 : 0.12)
        transform: Matrix4x4 { matrix: tarjeta.corte }
    }

    // Marca de video: en el centro la inclinación no desplaza nada
    Rectangle {
        visible: tarjeta.datos && tarjeta.datos.tipo === "video"
        anchors.centerIn: parent
        width: tarjeta.foco ? 54 : 34
        height: width
        radius: width / 2
        color: Qt.rgba(0, 0, 0, 0.45)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.55)
        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        Canvas {
            anchors.centerIn: parent
            width: parent.width * 0.36
            height: width
            onPaint: {
                const c = getContext("2d")
                c.reset()
                c.fillStyle = "#ffffff"
                c.beginPath()
                c.moveTo(width * 0.12, 0)
                c.lineTo(width, height / 2)
                c.lineTo(width * 0.12, height)
                c.closePath()
                c.fill()
            }
        }
    }

    // Insignia del fondo puesto ahora mismo, siguiendo la inclinación
    Item {
        readonly property real cy: tarjeta.height - 26
        visible: tarjeta.esActual
        opacity: tarjeta.foco ? 1 : 0.9
        width: sello.width
        height: sello.height
        y: cy - height / 2
        x: (tarjeta.width - width) / 2 - tarjeta.k * cy + tarjeta.sangria

        Rectangle {
            id: sello
            width: letra.width + 20
            height: 24
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)

            Text {
                id: letra
                anchors.centerIn: parent
                text: "✓ actual"
                color: "#f2f2f4"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
        }
    }
}
