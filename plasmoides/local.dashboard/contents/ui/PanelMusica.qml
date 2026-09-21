import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigami.primitives as KirigamiPrimitives
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as Vol

// Reproductor MPRIS. `grande` cambia entre la tarjeta del inicio y la vista completa.
Item {
    id: musica

    property var p
    property bool grande: false
    property string dirCodigo: ""
    property alias modelo: mpris

    readonly property var jugador: mpris.currentPlayer
    readonly property bool hay: !!jugador && !!(jugador.track || jugador.artist || jugador.album)
    readonly property bool sonando: hay && jugador.playbackStatus === Mpris.PlaybackStatus.Playing
    // En la tarjeta de Inicio la vista grande va en un hueco estrecho: los
    // mandos tienen un ancho mínimo y si no se encogen empujan la columna.
    readonly property bool estrecho: musica.width < 280
    readonly property real lado: grande ? Math.min(musica.width * 0.42, musica.height * 0.36)
                                      : Math.max(52, Math.min(74, musica.height - 6))

    Mpris.Mpris2Model { id: mpris }

    // Volumen que se oye (1 = 100 %), para que la corona crezca con él: el de
    // la salida en uso por el del propio reproductor (el deslizador de abajo).
    // Por encima de 100 % sigue creciendo un poco, hasta 1.3.
    readonly property var salida: Vol.PreferredDevice.sink
    // Sin salida conocida (aún conectando) o reproductor sin volumen: tamaño normal.
    readonly property real volSalida: !salida ? 1 : salida.muted ? 0
        : salida.volume / Vol.PulseAudio.NormalVolume
    readonly property real volJugador: hay && jugador.volume >= 0 ? jugador.volume : 1
    readonly property real volumen: Math.min(1.3, volSalida * volJugador)

    Timer {
        running: musica.sonando && musica.visible && !!musica.Window.window && musica.Window.window.visible
        interval: 1000
        repeat: true
        onTriggered: musica.jugador.updatePosition()
    }

    function reloj(us) {
        const s = Math.max(0, Math.floor(us / 1000000))
        const m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }

    // Sin reproductor
    ColumnLayout {
        anchors.centerIn: parent
        visible: !musica.hay
        spacing: 8
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: musica.grande ? 56 : 34
            implicitHeight: implicitWidth
            source: "media-playback-pause"
            color: musica.p.velo(0.25)
            isMask: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Nada sonando"
            color: musica.p.velo(0.35)
            font.pixelSize: 12
        }
    }

    // ---- Vista compacta (fila) ----
    RowLayout {
        anchors.fill: parent
        visible: musica.hay && !musica.grande
        spacing: 14

        KirigamiPrimitives.ShadowedImage {
            Layout.preferredWidth: musica.lado
            Layout.preferredHeight: musica.lado
            Layout.alignment: Qt.AlignVCenter
            radius: 14
            source: musica.hay ? musica.jugador.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            color: musica.p.hueco

            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.4
                height: width
                source: "media-album-cover"
                isMask: true
                color: musica.p.velo(0.2)
                visible: !musica.jugador || !musica.jugador.artUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: musica.hay ? musica.jugador.track : ""
                color: musica.p.texto
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: musica.hay ? musica.jugador.artist : ""
                color: musica.p.tenue
                font.pixelSize: 12
                elide: Text.ElideRight
                visible: text !== ""
            }

            Barra {
                Layout.fillWidth: true
                Layout.topMargin: 7
                p: musica.p
                valor: musica.hay && musica.jugador.length > 0 ? musica.jugador.position / musica.jugador.length : 0
                izquierda: musica.hay ? musica.reloj(musica.jugador.position) : "0:00"
                derecha: musica.hay ? musica.reloj(musica.jugador.length) : "0:00"
                onSaltar: v => { if (musica.jugador?.canSeek) musica.jugador.position = v * musica.jugador.length }
            }

            Mandos {
                Layout.topMargin: 4
                Layout.leftMargin: -6
                p: musica.p
                musica: musica
                tamano: 17
                separacion: 4
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ---- Vista grande (columna centrada) ----
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        visible: musica.hay && musica.grande
        spacing: 9

        Item { Layout.fillHeight: true }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: musica.lado + 40
            Layout.preferredHeight: musica.lado + 40

            // Corona de barras que responde a lo que suena
            Visualizador {
                anchors.centerIn: parent
                p: musica.p
                dirCodigo: musica.dirCodigo
                activo: musica.sonando
                circular: true
                numBarras: 56
                grosor: 2.5
                radio: musica.lado / 2 + 9
                altoMaximo: 14
                escala: musica.volumen
                color: musica.p.texto
            }

            KirigamiPrimitives.ShadowedImage {
                anchors.centerIn: parent
                width: musica.lado
                height: musica.lado
                radius: width / 2
                source: musica.hay ? musica.jugador.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                color: musica.p.hueco
                shadow.size: 26
                shadow.color: Qt.rgba(0, 0, 0, 0.5)
                shadow.yOffset: 6

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.3
                    height: width
                    source: "media-album-cover"
                    isMask: true
                    color: musica.p.velo(0.2)
                    visible: !musica.jugador || !musica.jugador.artUrl
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.topMargin: 6
            text: musica.hay ? musica.jugador.track : ""
            color: musica.p.texto
            font.pixelSize: musica.estrecho ? 13 : 16
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            text: musica.hay ? musica.jugador.artist : ""
            color: musica.p.suave
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            text: musica.hay ? musica.jugador.album : ""
            color: musica.p.tenue
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: text !== ""
        }

        Barra {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.maximumWidth: 420
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignHCenter
            p: musica.p
            valor: musica.hay && musica.jugador.length > 0 ? musica.jugador.position / musica.jugador.length : 0
            izquierda: musica.hay ? musica.reloj(musica.jugador.position) : "0:00"
            derecha: musica.hay ? musica.reloj(musica.jugador.length) : "0:00"
            onSaltar: v => { if (musica.jugador?.canSeek) musica.jugador.position = v * musica.jugador.length }
        }

        Mandos {
            Layout.alignment: Qt.AlignHCenter
            p: musica.p
            musica: musica
            tamano: musica.estrecho ? 17 : 26
            separacion: musica.estrecho ? 2 : 18
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 300
            Layout.preferredWidth: 0
            Layout.fillWidth: true
            spacing: musica.estrecho ? 6 : 10
            Kirigami.Icon {
                implicitWidth: 15; implicitHeight: 15
                source: "audio-volume-low-symbolic"
                color: musica.p.tenue
                isMask: true
            }
            Barra {
                Layout.fillWidth: true
                p: musica.p
                tiempos: false
                valor: musica.hay ? musica.jugador.volume : 0
                onSaltar: v => { if (musica.hay) musica.jugador.volume = v }
            }
            Kirigami.Icon {
                implicitWidth: 15; implicitHeight: 15
                source: "audio-volume-high-symbolic"
                color: musica.p.tenue
                isMask: true
            }
        }

        Item { Layout.fillHeight: true }
    }
}
