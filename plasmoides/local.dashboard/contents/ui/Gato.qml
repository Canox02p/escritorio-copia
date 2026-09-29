import QtQuick

// El bongo cat del sticker: dos fotogramas que se alternan para que parezca que
// golpea mientras hay un aviso a la vista. Al acabar se queda con las dos patas
// quietas.
Item {
    id: gato

    property bool tocando: false
    property int alto: 20
    readonly property real proporcion: 117 / 72

    implicitWidth: Math.round(alto * proporcion)
    implicitHeight: alto

    property bool paso: false

    Image {
        id: dibujo
        anchors.fill: parent
        source: Qt.resolvedUrl("../imagenes/" + (gato.paso ? "gato-2.png" : "gato-1.png"))
        fillMode: Image.PreserveAspectFit
        sourceSize.height: gato.alto * 3      // nítido en pantallas con escala
        smooth: true
        mipmap: true
        asynchronous: true

        // Entra de un saltito
        scale: gato.tocando ? 1 : 0.55
        transformOrigin: Item.Bottom
        Behavior on scale {
            NumberAnimation {
                duration: gato.tocando ? 360 : 150
                easing.type: gato.tocando ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 2.2
            }
        }
    }

    Timer {
        running: gato.tocando && gato.visible
        interval: 130
        repeat: true
        onTriggered: gato.paso = !gato.paso
    }

    onTocandoChanged: if (!tocando) paso = false
}
