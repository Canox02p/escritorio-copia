import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.clipboard as Klip

PlasmoidItem {
    id: root

    readonly property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
    property int seccion: 0
    readonly property int cuantasSecciones: 5

    Plasmoid.icon: "view-list-details"
    toolTipMainText: "Tablero"
    toolTipSubText: root.sonando ? root.jugador.track : "Reloj, música y sistema"
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Paleta { id: paleta; dirCodigo: root.dirCodigo }

    // Historial del portapapeles. Tiene que vivir AQUÍ y no dentro del popup:
    // Klipper solo captura mientras este objeto existe, y la representación
    // completa se destruye cada vez que se cierra el tablero.
    Klip.HistoryModel { id: historialClip }

    // ---- Atajos que abren una sección concreta (Meta+V) ----
    // escucha.sh se queda bloqueado esperando la señal del atajo y devuelve el
    // número de sección. No hay sondeo: el proceso duerme.
    P5Support.DataSource {
        id: escucha
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            const encontrado = String(data["stdout"] || "").match(/\d+/)
            const n = encontrado ? parseInt(encontrado[0]) : -1
            if (n >= 0 && n < root.cuantasSecciones) root.abrir(n)
            reconectar.start()
        }
    }

    Timer {
        id: reconectar
        interval: 150
        onTriggered: escucha.connectSource("bash '" + root.dirCodigo + "escucha.sh'")
    }

    Component.onCompleted: reconectar.start()

    // ---- Música ----
    Mpris.Mpris2Model { id: mpris }
    readonly property var jugador: mpris.currentPlayer
    readonly property bool hayMusica: !!jugador && !!(jugador.track || jugador.artist)
    readonly property bool sonando: hayMusica && jugador.playbackStatus === Mpris.PlaybackStatus.Playing

    // Con una ventana a pantalla completa la barra no se ve: nada se anima en ella
    Tapado { id: tapado }
    readonly property bool barraALaVista: !tapado.pantallaCompleta

    // ---- Reloj ----
    property string hora: ""
    function ponerHora() { hora = Qt.formatTime(new Date(), "h:mm AP") }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.ponerHora() }

    function abrir(i) {
        if (root.expanded && root.seccion === i) {
            root.expanded = false
        } else {
            root.seccion = i
            root.expanded = true
        }
    }

    // ---- En el panel: hora, canción, visualizador y el botón de abrir ----
    compactRepresentation: Item {
        id: tira

        readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

        Layout.minimumWidth: horizontal ? fila.implicitWidth + 14 : 0
        Layout.minimumHeight: horizontal ? 0 : fila.implicitHeight + 14
        implicitWidth: fila.implicitWidth + 14
        implicitHeight: Math.max(fila.implicitHeight, 20)

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 16

            // La hora abre Inicio
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: reloj.implicitWidth
                height: Math.max(reloj.implicitHeight, 20)

                Text {
                    id: reloj
                    anchors.centerIn: parent
                    text: root.hora
                    color: paleta.texto
                    opacity: tocaHora.containsMouse || (root.expanded && root.seccion === 0) ? 1 : 0.9
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                MouseArea {
                    id: tocaHora
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.abrir(0)
                }
            }

            // La canción y su visualizador abren Música
            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hayMusica
                width: grupoMusica.implicitWidth
                height: Math.max(grupoMusica.implicitHeight, 20)

                Row {
                    id: grupoMusica
                    anchors.centerIn: parent
                    spacing: 12

                    Marquesina {
                        anchors.verticalCenter: parent.verticalCenter
                        texto: root.hayMusica ? root.jugador.track : ""
                        color: paleta.texto
                        opacidad: tocaMusica.containsMouse || (root.expanded && root.seccion === 1) ? 0.95 : 0.66
                        tamano: 11
                        maximo: 190
                        andando: root.barraALaVista
                    }

                    Visualizador {
                        anchors.verticalCenter: parent.verticalCenter
                        p: paleta
                        dirCodigo: root.dirCodigo
                        activo: root.sonando && root.barraALaVista
                        numBarras: 22
                        grosor: 2
                        separacion: 2
                        altoMaximo: 14
                        color: paleta.texto
                    }
                }

                MouseArea {
                    id: tocaMusica
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.abrir(1)
                }
            }
        }
    }

    fullRepresentation: Tablero {
        Layout.minimumWidth: 640
        Layout.minimumHeight: 470
        Layout.preferredWidth: 780
        Layout.preferredHeight: 560

        p: paleta
        dirCodigo: root.dirCodigo
        portapapeles: historialClip
        vista: root.seccion
        abierto: root.expanded
        onVistaChanged: root.seccion = vista
        onAjustes: Plasmoid.internalAction("configure").trigger()
    }
}
