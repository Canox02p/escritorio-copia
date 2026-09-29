import QtQuick

// El bongo cat del sticker: dos fotogramas que se alternan para que parezca que
// golpea mientras hay un aviso a la vista. Al acabar se queda con las dos patas
// quietas.
Item {
    id: gato

    property bool tocando: false
    property int alto: 20
    // Energía del sonido (0..1) para golpear al ritmo. Con -1 golpea solo, a
    // intervalo fijo, que es lo que quieren las notificaciones.
    property real energia: -1
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
        running: gato.tocando && gato.visible && gato.energia < 0
        interval: 130
        repeat: true
        onTriggered: gato.paso = !gato.paso
    }

    // Detector de golpe tonto pero suficiente: media móvil de los graves y un
    // disparo con histéresis, para que no suene dos veces el mismo bombo ni se
    // quede clavado cuando la canción sube de volumen.
    property real media: 0
    property bool armado: true

    onEnergiaChanged: {
        if (gato.energia < 0 || !gato.tocando) return
        gato.media = gato.media * 0.88 + gato.energia * 0.12
        const arriba = Math.max(0.10, gato.media * 1.30)
        const abajo = arriba * 0.6
        if (gato.armado && gato.energia > arriba) {
            gato.paso = !gato.paso
            gato.armado = false
        } else if (!gato.armado && gato.energia < abajo) {
            gato.armado = true
        }
    }

    onTocandoChanged: if (!tocando) paso = false
}
