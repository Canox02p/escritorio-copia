import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtWebSockets
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property int numBarras: 48
    readonly property var barrasVacias: new Array(numBarras).fill(0)
    property var barras: barrasVacias

    Paleta { id: p; dirCodigo: root.dirCodigo }

    Plasmoid.icon: "view-media-visualization"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: hayMusica ? reproductor.track : "Visualizador de música"
    toolTipSubText: hayMusica ? reproductor.artist : "Nada sonando"

    // ---------- Música ----------
    Mpris.Mpris2Model { id: mpris }
    readonly property var reproductor: mpris.currentPlayer
    readonly property bool hayMusica: !!reproductor && !!(reproductor.track || reproductor.artist)
    readonly property bool sonando: hayMusica && reproductor.playbackStatus === Mpris.PlaybackStatus.Playing

    Timer {
        interval: 1000
        running: root.sonando
        repeat: true
        onTriggered: root.reproductor.updatePosition()
    }

    // ---------- Captura de audio ----------
    // visualizador.py captura el sonido y manda las barras por WebSocket; se cierra solo sin clientes.
    readonly property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
    property double ultimoArranque: 0

    onSonandoChanged: {
        socket.active = sonando
        if (!sonando) barras = barrasVacias
    }
    Component.onCompleted: socket.active = sonando

    WebSocket {
        id: socket
        url: "ws://127.0.0.1:47863"
        active: false
        onTextMessageReceived: mensaje => root.barras = JSON.parse(mensaje)
        onStatusChanged: {
            if ((status === WebSocket.Error || status === WebSocket.Closed) && root.sonando) {
                root.arrancarServidor()
                reconectar.restart()
            }
        }
    }

    Timer {
        id: reconectar
        interval: 1500
        onTriggered: {
            socket.active = false
            socket.active = root.sonando
        }
    }

    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    function arrancarServidor() {
        const t = Date.now()
        if (t - ultimoArranque < 3000) return
        ultimoArranque = t
        ejecutar.connectSource("setsid -f python3 '" + dirCodigo.replace(/'/g, "'\\''") + "visualizador.py' >/dev/null 2>&1")
    }

    function tiempo(microsegundos) {
        const s = Math.max(0, Math.floor(microsegundos / 1000000))
        const h = Math.floor(s / 3600)
        const m = Math.floor(s % 3600 / 60)
        const ss = String(s % 60).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss
    }

    // ---------- Vista ----------
    fullRepresentation: Item {
        id: vista

        readonly property real radio: Kirigami.Units.gridUnit * 0.9
        readonly property real relleno: Kirigami.Units.largeSpacing * 1.5
        readonly property color tenue: p.velo(0.12)
        readonly property string arte: root.hayMusica ? (root.reproductor.artUrl || "") : ""

        Layout.preferredWidth: Kirigami.Units.gridUnit * 36
        Layout.preferredHeight: Kirigami.Units.gridUnit * 7
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        Layout.minimumHeight: Kirigami.Units.gridUnit * 4

        // Fondo translúcido teñido con la carátula desenfocada
        Rectangle {
            anchors.fill: parent
            radius: vista.radio
            color: Qt.rgba(p.fondo.r, p.fondo.g, p.fondo.b, 0.75)
        }
        Image {
            id: arteFondo
            anchors.fill: parent
            source: vista.arte
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        Rectangle {
            id: mascara
            anchors.fill: parent
            radius: vista.radio
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: arteFondo
            visible: arteFondo.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1.5
            saturation: 0.3
            maskEnabled: true
            maskSource: mascara
            opacity: 0.4
        }
        Rectangle {
            anchors.fill: parent
            radius: vista.radio
            color: "transparent"
            border.color: p.borde
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: vista.relleno
            spacing: Kirigami.Units.smallSpacing

            // Barras
            Item {
                id: visualizador
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real separacion: Math.max(2, Math.round(width / root.numBarras * 0.3))
                readonly property real anchoBarra: (width - separacion * (root.numBarras - 1)) / root.numBarras

                Row {
                    anchors.fill: parent
                    spacing: visualizador.separacion

                    Repeater {
                        model: root.numBarras
                        delegate: Item {
                            required property int index
                            width: visualizador.anchoBarra
                            height: visualizador.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(width, parent.height * (root.barras[parent.index] || 0))
                                radius: Math.min(width / 2, Kirigami.Units.smallSpacing)
                                opacity: 0.35 + 0.65 * Math.min(1, height / parent.height * 1.5)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.lighter(p.acento, 1.25) }
                                    GradientStop { position: 1; color: p.acento }
                                }
                                Behavior on height { NumberAnimation { duration: 50 } }
                            }
                        }
                    }
                }
            }

            // Progreso de la canción (clic para saltar)
            ColumnLayout {
                id: progreso
                visible: root.hayMusica && root.reproductor.length > 0
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                readonly property real fraccion: root.hayMusica && root.reproductor.length > 0
                                                 ? Math.min(1, root.reproductor.position / root.reproductor.length) : 0

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: zonaProgreso.containsMouse ? 6 : 4
                    radius: height / 2
                    color: vista.tenue
                    Behavior on implicitHeight { NumberAnimation { duration: 100 } }

                    Rectangle {
                        width: parent.width * progreso.fraccion
                        height: parent.height
                        radius: height / 2
                        color: p.acento
                    }
                    MouseArea {
                        id: zonaProgreso
                        anchors.fill: parent
                        anchors.margins: -Kirigami.Units.smallSpacing * 2
                        hoverEnabled: true
                        enabled: root.hayMusica && root.reproductor.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: mouse => {
                            const f = Math.max(0, Math.min(1, (mouse.x + anchors.margins) / parent.width))
                            root.reproductor.position = f * root.reproductor.length
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Label {
                        text: root.hayMusica ? root.tiempo(root.reproductor.position) : ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: p.tenue
                        opacity: 0.9
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents3.Label {
                        text: root.hayMusica ? root.tiempo(root.reproductor.length) : ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: p.tenue
                        opacity: 0.9
                    }
                }
            }
        }
    }
}
