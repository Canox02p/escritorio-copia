import QtQuick
import QtWebSockets
import org.kde.plasma.plasma5support as P5Support

// Barras que responden al sonido real. Se alimenta de visualizador.py, que
// captura el monitor de la salida y manda las alturas por WebSocket.
Item {
    id: vis

    property var p
    property string dirCodigo: ""
    property bool activo: false            // solo conecta si hace falta
    // Y además solo si se ve: pestaña oculta o popup cerrado no gastan nada
    readonly property bool aLaVista: visible && !!Window.window && Window.window.visible
    readonly property bool enUso: activo && aLaVista
    property int numBarras: 28
    property real grosor: 3
    property real separacion: 2
    property bool circular: false
    property real radio: 60                // solo en modo circular
    property real altoMaximo: 14
    property color color: p ? p.acento : "#ffffff"

    readonly property var vacias: new Array(64).fill(0)
    property var barras: vacias
    property double ultimoArranque: 0

    implicitWidth: circular ? radio * 2 + altoMaximo * 2
                            : numBarras * grosor + (numBarras - 1) * separacion
    implicitHeight: circular ? implicitWidth : altoMaximo

    onEnUsoChanged: {
        socket.active = enUso
        if (!enUso) barras = vacias
    }
    Component.onCompleted: socket.active = enUso

    function arrancarServidor() {
        const t = Date.now()
        if (t - ultimoArranque < 3000 || dirCodigo === "") return
        ultimoArranque = t
        lanzar.connectSource("setsid -f python3 '" + dirCodigo.replace(/'/g, "'\\''") + "visualizador.py' >/dev/null 2>&1")
    }

    P5Support.DataSource {
        id: lanzar
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    WebSocket {
        id: socket
        url: "ws://127.0.0.1:47863"
        active: false
        onTextMessageReceived: mensaje => vis.barras = JSON.parse(mensaje)
        onStatusChanged: estado => {
            if ((estado === WebSocket.Error || estado === WebSocket.Closed) && vis.enUso) {
                vis.arrancarServidor()
                reconectar.restart()
            }
        }
    }

    Timer {
        id: reconectar
        interval: 1500
        onTriggered: { socket.active = false; socket.active = vis.enUso }
    }

    // Sin Behavior en las barras a propósito: el suavizado ya viene hecho de
    // visualizador.py a 60 por segundo, y animar cada barra aparte triplicaba el gasto.

    // Toma una barra del servidor repartiendo las 48 entre las que se pinten
    function altura(i) {
        const fuente = vis.barras
        if (!fuente || fuente.length === 0) return 0
        const j = Math.floor(i * fuente.length / vis.numBarras)
        return Math.max(0, Math.min(1, (fuente[j] || 0) / 1000))   // llegan en milésimas
    }

    // ---- Recta (para la barra del panel) ----
    Row {
        anchors.centerIn: parent
        visible: !vis.circular
        spacing: vis.separacion

        Repeater {
            model: vis.circular ? 0 : vis.numBarras
            delegate: Rectangle {
                required property int index
                width: vis.grosor
                height: Math.max(vis.grosor, vis.altoMaximo * vis.altura(index))
                radius: vis.grosor / 2
                color: vis.color
                opacity: 0.55 + 0.45 * (height / vis.altoMaximo)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- En corona (para la pestaña de música) ----
    Item {
        anchors.fill: parent
        visible: vis.circular

        Repeater {
            model: vis.circular ? vis.numBarras : 0
            delegate: Item {
                required property int index
                anchors.centerIn: parent
                width: vis.grosor
                height: vis.radio * 2
                rotation: index * 360 / vis.numBarras

                Rectangle {
                    width: vis.grosor
                    height: Math.max(vis.grosor, vis.altoMaximo * vis.altura(index))
                    radius: vis.grosor / 2
                    color: vis.color
                    opacity: 0.5 + 0.5 * (height / vis.altoMaximo)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 2
                }
            }
        }
    }
}
