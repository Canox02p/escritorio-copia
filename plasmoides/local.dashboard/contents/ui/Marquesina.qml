import QtQuick

// Texto que se desplaza cuando no cabe, con dos copias para que el bucle
// no tenga saltos. Si cabe entero, se queda quieto.
Item {
    id: m

    property string texto: ""
    property color color: "white"
    property real opacidad: 1
    property string familia: "JetBrainsMono Nerd Font"
    property int tamano: 11
    property int grosor: Font.Medium
    property real maximo: 190
    property real hueco: 34          // aire entre una vuelta y la siguiente
    property real velocidad: 26      // píxeles por segundo
    property bool andando: true

    readonly property bool desborda: medida.implicitWidth > maximo

    implicitWidth: desborda ? maximo : medida.implicitWidth
    implicitHeight: medida.implicitHeight
    clip: true

    // Copia oculta solo para medir
    Text {
        id: medida
        visible: false
        text: m.texto
        font.family: m.familia
        font.pixelSize: m.tamano
        font.weight: m.grosor
    }

    Row {
        id: cinta
        spacing: m.hueco
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: primera
            text: m.texto
            color: m.color
            opacity: m.opacidad
            font.family: m.familia
            font.pixelSize: m.tamano
            font.weight: m.grosor
        }

        Text {
            text: m.desborda ? m.texto : ""
            color: m.color
            opacity: m.opacidad
            font.family: m.familia
            font.pixelSize: m.tamano
            font.weight: m.grosor
        }
    }

    NumberAnimation {
        id: paseo
        target: cinta
        property: "x"
        from: 0
        to: -(primera.implicitWidth + m.hueco)
        duration: Math.max(600, (primera.implicitWidth + m.hueco) / m.velocidad * 1000)
        loops: Animation.Infinite
        running: m.desborda && m.andando
    }

    // Al cambiar de canción se vuelve a empezar desde el principio
    onTextoChanged: {
        cinta.x = 0
        if (m.desborda && m.andando) paseo.restart()
    }
    onDesbordaChanged: if (!desborda) { paseo.stop(); cinta.x = 0 }
}
