import QtQuick
import QtQuick.Shapes

// Wifi dibujado: los arcos de siempre. No se usa el icono del tema porque
// Papirus-Dark dibuja el wifi como un abanico MACIZO (un `path` con fill,
// sin arcos), que al teñirlo con isMask se lee como un rombo o una gema.
// Breeze sí trae los arcos, pero salta de 20 en 20 y obligaría a apuntar a
// una ruta fija de otro tema. Dibujado sigue al acento y anima el cambio.
Item {
    id: wifi

    property int nivel: 100            // 0..100; cuántos arcos se encienden
    property bool conectado: true      // false: todo apagado y aspa
    property color tinta: "white"      // normalmente el acento
    property real apagado: 0.26        // opacidad de los arcos que no llegan

    implicitWidth: 16
    implicitHeight: 13

    // Todo se calcula desde la altura: los arcos solo ocupan ±48° desde arriba,
    // así que a lo ancho gastan 0.74·r y caben de sobra.
    readonly property real cx: width / 2
    readonly property real cy: height * 0.88
    readonly property real grosor: Math.max(1, height * 0.115)
    readonly property real rPunto: Math.max(0.9, height * 0.085)

    readonly property int encendidos: !conectado ? 0
                                      : nivel >= 70 ? 3
                                      : nivel >= 45 ? 2
                                      : nivel >= 18 ? 1 : 0

    // El punto de abajo siempre se ve.
    Rectangle {
        x: wifi.cx - wifi.rPunto
        y: wifi.cy - wifi.rPunto
        width: wifi.rPunto * 2
        height: wifi.rPunto * 2
        radius: wifi.rPunto
        color: wifi.tinta
        opacity: wifi.conectado ? 1 : wifi.apagado
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    // Tres arcos crecientes.
    Repeater {
        model: 3
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // 0 es las 3 en punto y crece en sentido horario, así que arriba
            // son 270°: se centra ahí y se abre ±48°.
            ShapePath {
                fillColor: "transparent"
                strokeColor: wifi.tinta
                strokeWidth: wifi.grosor
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: wifi.cx
                    centerY: wifi.cy
                    radiusX: wifi.height * (0.26 + index * 0.21)
                    radiusY: wifi.height * (0.26 + index * 0.21)
                    startAngle: 222
                    sweepAngle: 96
                }
            }
            opacity: index < wifi.encendidos ? 1 : wifi.apagado
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }
    }

    // Aspa cuando no hay conexión.
    Item {
        visible: !wifi.conectado
        width: wifi.height * 0.42
        height: width
        x: wifi.width - width
        y: wifi.height - height
        Repeater {
            model: 2
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: Math.max(1, wifi.height * 0.1)
                radius: height / 2
                color: wifi.tinta
                rotation: index === 0 ? 45 : -45
            }
        }
    }
}
