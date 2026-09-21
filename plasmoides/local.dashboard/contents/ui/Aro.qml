import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Medidor en arco, como los de la referencia: 3/4 de círculo con el hueco abajo.
Item {
    id: aro

    property var p
    property real valor: 0             // 0..1
    property real grosor: 7
    property color color: p ? p.acento : "#ffffff"
    property string cifra: ""
    property string rotulo: ""
    property string icono: ""      // si se pone, manda sobre la cifra
    property real tamanoCifra: 19

    readonly property real inicio: 135
    readonly property real barrido: 270

    implicitWidth: 92
    implicitHeight: 92

    // Riel y relleno en una sola figura con el renderizador de curvas: con dos
    // Shape separadas y sin él, dentro de Plasma el riel no llegaba a verse
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // El riel tiene que leerse: si no, el relleno parece un trozo suelto
            strokeColor: aro.p ? aro.p.velo(0.22) : "#444"
            strokeWidth: aro.grosor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: aro.width / 2; centerY: aro.height / 2
                radiusX: (Math.min(aro.width, aro.height) - aro.grosor) / 2
                radiusY: (Math.min(aro.width, aro.height) - aro.grosor) / 2
                startAngle: aro.inicio; sweepAngle: aro.barrido
            }
        }

        ShapePath {
            strokeColor: aro.color
            strokeWidth: aro.grosor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                id: arco
                centerX: aro.width / 2; centerY: aro.height / 2
                radiusX: (Math.min(aro.width, aro.height) - aro.grosor) / 2
                radiusY: (Math.min(aro.width, aro.height) - aro.grosor) / 2
                startAngle: aro.inicio
                sweepAngle: Math.max(0.1, aro.barrido * Math.max(0, Math.min(1, aro.valor)))
                Behavior on sweepAngle { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(aro.width * 0.26)
            height: width
            source: aro.icono
            isMask: true
            color: aro.p ? aro.p.texto : "white"
            opacity: 0.85
            visible: aro.icono !== ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: aro.cifra
            visible: text !== ""
            color: aro.p ? aro.p.texto : "white"
            font.pixelSize: aro.tamanoCifra
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: aro.rotulo
            color: aro.p ? aro.p.tenue : "gray"
            font.pixelSize: 9
            font.letterSpacing: 0.8
            visible: text !== ""
        }
    }
}
