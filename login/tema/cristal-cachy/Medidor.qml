import QtQuick
import QtQuick.Shapes

// Aro con porcentaje, icono y un dato pequeño encima (temperatura, etc.)
Item {
    id: medidor
    property real valor: 0          // 0..100
    property string icono: ""       // glifo Nerd Font
    property string extra: ""
    property color acento: "#b4befe"
    property bool resaltado: false

    implicitWidth: 92
    implicitHeight: 92

    Rectangle {
        anchors.fill: parent
        radius: width * 0.34
        color: medidor.resaltado ? Qt.rgba(medidor.acento.r, medidor.acento.g, medidor.acento.b, 0.28)
                                 : Qt.rgba(1, 1, 1, 0.05)
    }

    Shape {
        anchors.fill: parent
        anchors.margins: 10
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 1, 1, 0.16)
            strokeWidth: 4
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: (medidor.width - 20) / 2; centerY: (medidor.height - 20) / 2
                radiusX: Math.min(medidor.width, medidor.height) / 2 - 12; radiusY: radiusX
                startAngle: 130; sweepAngle: 280
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: medidor.acento
            strokeWidth: 4
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: (medidor.width - 20) / 2; centerY: (medidor.height - 20) / 2
                radiusX: Math.min(medidor.width, medidor.height) / 2 - 12; radiusY: radiusX
                startAngle: 130; sweepAngle: 280 * Math.max(0.01, Math.min(1, medidor.valor / 100))
                Behavior on sweepAngle { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Text {
                text: medidor.icono
                color: Qt.rgba(1, 1, 1, 0.75)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }
            Text {
                visible: medidor.extra !== ""
                text: medidor.extra
                color: Qt.rgba(1, 1, 1, 0.75)
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(medidor.valor) + "%"
            color: "#e6e9f5"
            font.pixelSize: 24
            font.weight: Font.Bold
        }
    }
}
