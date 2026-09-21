import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

// Botonera del reproductor.
Row {
    id: mandos

    property var p
    property var musica
    property real tamano: 22
    property real separacion: 12

    spacing: separacion

    component Boton: Item {
        id: boton
        property string icono: ""
        property bool activo: false
        property bool encendido: true
        property real lado: mandos.tamano
        signal pulsado()

        width: lado + 12
        height: lado + 12
        opacity: encendido ? 1 : 0.32

        Kirigami.Icon {
            anchors.centerIn: parent
            width: boton.lado
            height: boton.lado
            source: boton.icono
            isMask: true
            color: boton.activo ? mandos.p.acento
                                : (toque.containsMouse ? mandos.p.texto : mandos.p.tenue)
            scale: toque.containsMouse ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: toque
            anchors.fill: parent
            hoverEnabled: true
            enabled: boton.encendido
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.pulsado()
        }
    }

    Boton {
        anchors.verticalCenter: parent.verticalCenter
        icono: "media-playlist-shuffle"
        activo: mandos.musica.hay && mandos.musica.jugador.shuffle === Mpris.ShuffleStatus.On
        encendido: mandos.musica.hay
        lado: mandos.tamano * 0.8
        onPulsado: mandos.musica.jugador.shuffle =
            mandos.musica.jugador.shuffle === Mpris.ShuffleStatus.On ? Mpris.ShuffleStatus.Off : Mpris.ShuffleStatus.On
    }

    Boton {
        anchors.verticalCenter: parent.verticalCenter
        icono: "media-skip-backward"
        encendido: mandos.musica.hay && mandos.musica.jugador.canGoPrevious
        onPulsado: mandos.musica.jugador.Previous()
    }

    // Play/pausa relleno
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: mandos.tamano + 20
        height: width
        radius: width / 2
        color: sobrePlay.containsMouse ? mandos.p.suave : mandos.p.acento
        opacity: mandos.musica.hay ? 1 : 0.32
        Behavior on color { ColorAnimation { duration: 140 } }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: mandos.tamano
            height: width
            source: mandos.musica.sonando ? "media-playback-pause" : "media-playback-start"
            isMask: true
            color: mandos.p.sobreAcento
        }

        MouseArea {
            id: sobrePlay
            anchors.fill: parent
            hoverEnabled: true
            enabled: mandos.musica.hay
            cursorShape: Qt.PointingHandCursor
            onClicked: mandos.musica.jugador.PlayPause()
        }
    }

    Boton {
        anchors.verticalCenter: parent.verticalCenter
        icono: "media-skip-forward"
        encendido: mandos.musica.hay && mandos.musica.jugador.canGoNext
        onPulsado: mandos.musica.jugador.Next()
    }

    Boton {
        anchors.verticalCenter: parent.verticalCenter
        icono: mandos.musica.hay && mandos.musica.jugador.loopStatus === Mpris.LoopStatus.Track
               ? "media-playlist-repeat-song" : "media-playlist-repeat"
        activo: mandos.musica.hay && mandos.musica.jugador.loopStatus !== Mpris.LoopStatus.None
        encendido: mandos.musica.hay
        lado: mandos.tamano * 0.8
        onPulsado: {
            const j = mandos.musica.jugador
            j.loopStatus = j.loopStatus === Mpris.LoopStatus.None ? Mpris.LoopStatus.Playlist
                         : (j.loopStatus === Mpris.LoopStatus.Playlist ? Mpris.LoopStatus.Track : Mpris.LoopStatus.None)
        }
    }
}
