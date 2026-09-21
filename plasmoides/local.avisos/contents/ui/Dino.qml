import QtQuick

// Estado vacío al estilo del dinosaurio del navegador: sprites en píxeles,
// dibujados a mano para poder teñirlos con la paleta.
Item {
    id: escena

    property var p
    property real pixel: 3
    property color tinta: p ? p.velo(0.30) : "#555"

    // Sacado de la captura del dinosaurio de verdad, píxel a píxel, con la
    // rejilla de celdas cuadradas para que no salga estirado.
    readonly property var dino: [
        "............#########.",
        "...........###########",
        "...........##.########",
        "...........###########",
        "...........###########",
        "...........###########",
        "...........######.....",
        "..........#########...",
        "##.......#######......",
        "##......#########.....",
        "##.....###########....",
        "###...############....",
        "####.###########......",
        "################......",
        ".##############.......",
        ".#############........",
        "...###########........",
        "...##########.........",
        "....#####..####.......",
        "....####...####......."
    ]

    readonly property var cactus: [
        "..###..",
        "..###..",
        "#.###..",
        "#.###.#",
        "#.###.#",
        "###.###",
        ".#####.",
        "..###..",
        "..###..",
        "..###..",
        "..###..",
        "..###.."
    ]

    readonly property var nube: [
        "...####.....",
        ".########...",
        "############",
        "..#######..."
    ]

    implicitWidth: 60 * pixel
    implicitHeight: 30 * pixel

    // Pinta un mapa de caracteres como cuadraditos
    component Sprite: Item {
        property var mapa: []
        property real lado: escena.pixel
        property color color: escena.tinta

        implicitWidth: (mapa.length > 0 ? mapa[0].length : 0) * lado
        implicitHeight: mapa.length * lado

        Repeater {
            model: mapa.length
            delegate: Item {
                id: renglon
                required property int index
                // El índice hay que nombrarlo: dentro del Repeater de abajo,
                // `index` es el de la columna y tapa al de la fila.
                readonly property int fila: index
                readonly property string patron: mapa[index]
                y: index * lado
                Repeater {
                    model: renglon.patron.length
                    delegate: Rectangle {
                        required property int index
                        visible: renglon.patron.charAt(index) === "#"
                        x: index * lado
                        width: lado
                        height: lado
                        color: escena.tinta
                    }
                }
            }
        }
    }

    // Nube, arriba a la izquierda del dino
    Sprite {
        mapa: escena.nube
        lado: escena.pixel * 0.9
        x: escena.width * 0.30
        y: 0
        opacity: 0.75
    }

    // Suelo
    Rectangle {
        id: suelo
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(1, escena.pixel * 0.6)
        color: escena.tinta
        opacity: 0.8
    }

    // Piedrecitas del suelo
    Repeater {
        model: [0.26, 0.42, 0.58, 0.74]
        delegate: Rectangle {
            required property var modelData
            x: escena.width * modelData
            anchors.bottom: suelo.top
            anchors.bottomMargin: escena.pixel * 0.8
            width: escena.pixel * 1.2
            height: Math.max(1, escena.pixel * 0.6)
            color: escena.tinta
            opacity: 0.5
        }
    }

    Sprite {
        id: elDino
        mapa: escena.dino
        anchors.left: parent.left
        anchors.leftMargin: escena.pixel
        anchors.bottom: suelo.top
    }

    Sprite {
        mapa: escena.cactus
        lado: escena.pixel * 1.1
        anchors.right: parent.right
        anchors.rightMargin: escena.pixel * 2
        anchors.bottom: suelo.top
    }
}
