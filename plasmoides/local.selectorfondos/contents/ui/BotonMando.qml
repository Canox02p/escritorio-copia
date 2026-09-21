import QtQuick

// Botón de la barra flotante. Los iconos van dibujados a mano para que no
// dependan del tema (fuera de plasmashell los nombres no siempre resuelven).
Rectangle {
    id: boton

    property string dibujo: "rejilla"   // rejilla | reloj | play | lupa
    property bool activo: false
    property color tinta: "#f2f2f4"

    signal pulsado()

    width: 32
    height: 32
    radius: 9
    color: activo ? Qt.rgba(1, 1, 1, 0.16)
                  : (raton.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent")
    Behavior on color { ColorAnimation { duration: 130 } }

    readonly property color trazo: activo ? tinta : Qt.rgba(tinta.r, tinta.g, tinta.b, 0.72)

    // Rejilla: cuatro cuadraditos
    Grid {
        visible: boton.dibujo === "rejilla"
        anchors.centerIn: parent
        columns: 2
        spacing: 3
        Repeater {
            model: 4
            delegate: Rectangle {
                width: 6; height: 6; radius: 1.5
                color: boton.trazo
            }
        }
    }

    Canvas {
        id: lienzo
        visible: boton.dibujo !== "rejilla"
        anchors.centerIn: parent
        width: 17
        height: 17
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = boton.trazo
            c.fillStyle = boton.trazo
            c.lineWidth = 1.5
            c.lineCap = "round"

            if (boton.dibujo === "reloj") {
                c.beginPath()
                c.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI * 2)
                c.stroke()
                c.beginPath()
                c.moveTo(width / 2, height * 0.3)
                c.lineTo(width / 2, height / 2)
                c.lineTo(width * 0.72, height * 0.62)
                c.stroke()
            } else if (boton.dibujo === "play") {
                c.beginPath()
                c.moveTo(width * 0.24, height * 0.14)
                c.lineTo(width * 0.84, height / 2)
                c.lineTo(width * 0.24, height * 0.86)
                c.closePath()
                c.fill()
            } else if (boton.dibujo === "lupa") {
                c.beginPath()
                c.arc(width * 0.43, height * 0.43, width * 0.31, 0, Math.PI * 2)
                c.stroke()
                c.beginPath()
                c.moveTo(width * 0.67, height * 0.67)
                c.lineTo(width * 0.92, height * 0.92)
                c.stroke()
            }
        }
    }

    onTrazoChanged: lienzo.requestPaint()
    onDibujoChanged: lienzo.requestPaint()

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: boton.pulsado()
    }
}
