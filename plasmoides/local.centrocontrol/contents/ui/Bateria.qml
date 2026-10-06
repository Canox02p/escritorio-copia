import QtQuick

// Batería dibujada, que se va vaciando de verdad. No se usa el icono del tema
// porque Papirus solo trae uno fijo (`battery.svg`), sin niveles; los de Breeze
// sí los tienen pero saltan de diez en diez y no pegan con el resto. Dibujada
// además sigue al acento y anima el cambio de carga.
Item {
    id: pila

    property int nivel: 100            // 0..100
    property bool cargando: false
    property color tinta: "white"      // normalmente el acento
    // El rayo de carga va SIEMPRE en blanco, pase lo que pase con el acento:
    // así se ve de un vistazo que está cargando.
    readonly property color rayoColor: "#ffffff"
    property color aviso: "#f5a3b5"    // queda poca y no está enchufada

    readonly property bool bajo: nivel <= 20 && !cargando
    readonly property color color1: bajo ? aviso : tinta
    readonly property real fraccion: Math.min(100, Math.max(0, nivel)) / 100
    // Todo va en proporción al alto, tomando como medida los 12 px de la tira
    // (u = 1 ahí, y salen los mismos números de siempre). Así se puede poner
    // grande sin `scale`, que la pintaba escalonada.
    readonly property real u: height / 12

    implicitWidth: 22
    implicitHeight: 12

    // ---- Cuerpo ----
    Rectangle {
        id: cuerpo
        width: parent.width - 3 * pila.u
        height: parent.height
        radius: 3.5 * pila.u
        color: "transparent"
        border.width: 1.3 * pila.u
        border.color: pila.color1
        Behavior on border.color { ColorAnimation { duration: 250 } }

        // Un velo en el hueco vacío: así el rayo de carga siempre tiene algo
        // detrás y el dibujo no se queda en dos rayas sueltas.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2 * pila.u
            radius: 1.6 * pila.u
            color: pila.color1
            opacity: 0.18
            Behavior on color { ColorAnimation { duration: 250 } }
        }

        // Lo que queda de carga
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 2 * pila.u
            width: Math.max(0, (parent.width - 4 * pila.u) * pila.fraccion)
            height: parent.height - 4 * pila.u
            radius: 1.6 * pila.u
            color: pila.color1
            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }
    }

    // ---- Borne ----
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 2.5 * pila.u
        height: parent.height * 0.42
        radius: 1.2 * pila.u
        color: pila.color1
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    // ---- Rayo, solo mientras carga ----
    Text {
        anchors.centerIn: cuerpo
        visible: pila.cargando
        text: ""                 // rayo de la Nerd Font
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(pila.height * 0.82)
        color: pila.rayoColor
    }
}
