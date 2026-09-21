import QtQuick
import QtQuick.Shapes

// Círculo girando: se enseña mientras se busca.
Item {
    id: ruleta

    property var p
    property real lado: 20
    property bool girando: false

    implicitWidth: lado
    implicitHeight: lado
    opacity: girando ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // Aro de fondo
    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeColor: ruleta.p.velo(0.13)
            strokeWidth: 2
            fillColor: "transparent"
            PathAngleArc {
                centerX: ruleta.lado / 2; centerY: ruleta.lado / 2
                radiusX: ruleta.lado / 2 - 1.5; radiusY: ruleta.lado / 2 - 1.5
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // Arco que da vueltas
    Shape {
        id: arco
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeColor: ruleta.p.acento
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ruleta.lado / 2; centerY: ruleta.lado / 2
                radiusX: ruleta.lado / 2 - 1.5; radiusY: ruleta.lado / 2 - 1.5
                startAngle: 0; sweepAngle: 100
            }
        }

        RotationAnimator on rotation {
            running: ruleta.girando && ruleta.visible && !!ruleta.Window.window && ruleta.Window.window.visible
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 850
        }
    }
}
