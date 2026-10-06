import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigami.primitives as KirigamiPrimitives
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as Vol

// Reproductor MPRIS. `grande` cambia entre la tarjeta del inicio y la vista completa.
Item {
    id: musica

    property var p
    property bool grande: false
    // `columna` apila la vista grande (carátula arriba, datos debajo). Es lo que
    // usa la tarjeta estrecha de Inicio; la pestaña Música va en fila.
    property bool columna: false
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
    // ---- Volumen de la música ----
    // Brave (y Chromium en general) publica `Volume` y `CanControl: true` por
    // MPRIS pero IGNORA la escritura: el valor se queda clavado en 1.0 y el
    // flujo de PulseAudio ni se inmuta, así que la barra salía siempre al 100 %
    // y arrastrarla no hacía nada. Lo que sí responde es el volumen del flujo
    // de audio de la aplicación, así que se manda sobre ese; MPRIS queda de
    // reserva para los reproductores que sí lo implementan (VLC, Spotify…).
    Vol.SinkInputModel { id: flujos }
    property var flujo: null

    function buscarFlujo() {
        if (!flujos || flujos.rowCount() === 0) return null
        const rolObj = flujos.KItemModels.KRoleNames.role("PulseObject")
        const rolCli = flujos.KItemModels.KRoleNames.role("Client")
        const rolNom = flujos.KItemModels.KRoleNames.role("Name")
        const quien = String((musica.jugador && musica.jugador.identity) || "").toLowerCase()
        let unico = null
        let cuantos = 0
        for (let i = 0; i < flujos.rowCount(); i++) {
            const idx = flujos.index(i, 0)
            const obj = flujos.data(idx, rolObj)
            if (!obj) continue
            cuantos++
            unico = obj
            if (quien === "") continue
            // Cada programa publica su nombre en un sitio distinto: se miran todos.
            const cli = flujos.data(idx, rolCli)
            const nombres = []
            if (typeof cli === "string") nombres.push(cli)
            else if (cli && cli.name) nombres.push(cli.name)
            if (obj.properties) {
                nombres.push(obj.properties["application.name"])
                nombres.push(obj.properties["application.process.binary"])
            }
            nombres.push(flujos.data(idx, rolNom))
            for (let k = 0; k < nombres.length; k++) {
                const n = String(nombres[k] || "").toLowerCase()
                if (n !== "" && (n.indexOf(quien) >= 0 || quien.indexOf(n) >= 0)) return obj
            }
        }
        // Si solo hay un programa sonando, no hay dónde equivocarse.
        return cuantos === 1 ? unico : null
    }

    // La rebusca va DIFERIDA a propósito. Haciéndola en el acto se formaba un
    // bucle de enlaces: evaluar `volMusica` lee `jugador.volume`, el modelo de
    // MPRIS reemite el cambio de reproductor, `onJugadorChanged` reescribía
    // `flujo` y `volMusica` volvía a evaluarse. Con el Timer el cambio cae
    // fuera de la evaluación del enlace y la cadena se corta.
    Timer {
        id: rebusca
        interval: 120
        onTriggered: musica.flujo = musica.buscarFlujo()
    }
    function refrescarFlujo() { rebusca.restart() }

    Component.onCompleted: musica.refrescarFlujo()
    onJugadorChanged: musica.refrescarFlujo()
    Connections {
        target: flujos
        function onCountChanged() { musica.refrescarFlujo() }
    }

    // Lo que enseña y mueve la barra de volumen.
    readonly property real volMusica: flujo ? (flujo.muted ? 0 : Math.min(1, flujo.volume / Vol.PulseAudio.NormalVolume))
                                            : (hay && jugador.volume >= 0 ? jugador.volume : 0)
    function ponerVolumen(v) {
        const x = Math.max(0, Math.min(1, v))
        if (flujo) {
            flujo.volume = Math.round(x * Vol.PulseAudio.NormalVolume)
            if (flujo.muted && x > 0) flujo.muted = false
        } else if (hay) {
            jugador.volume = x
        }
    }

    readonly property real volJugador: flujo ? volMusica : (hay && jugador.volume >= 0 ? jugador.volume : 1)
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
            color: musica.p.texto
            opacity: 0.30
            isMask: true
        }
        Text {
            font.family: "JetBrainsMono Nerd Font"
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
                color: musica.p.texto
                opacity: 0.22
                visible: !musica.jugador || !musica.jugador.artUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Item { Layout.fillHeight: true }

            Text {
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: musica.hay ? musica.jugador.track : ""
                color: musica.p.texto
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                font.family: "JetBrainsMono Nerd Font"
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

    // ---- Vista grande: carátula a la izquierda, datos y mandos a la derecha ----
    // Repartido en fila (y no en columna centrada) a petición suya. De paso el
    // alto deja de ir justo: la carátula ya no gasta alto de los textos.
    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        visible: musica.hay && musica.grande && !musica.columna
        spacing: musica.estrecho ? 10 : 20

        // ---- Carátula con la corona de barras ----
        Item {
            id: portada
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: true
            Layout.preferredWidth: portada.ladoReal + aire
            Layout.minimumHeight: 110

            // Largo de las barras de la corona. Al tocarlo, el aire se ajusta
            // solo: la barra sale desde `radio` (carátula/2 + 9) con 2 px de
            // hueco, así que por cada lado hace falta 9 + 2 + altoBarras o
            // Pieza las recorta (tiene clip).
            readonly property real altoBarras: 36
            readonly property real aire: 2 * (9 + 2 + altoBarras)
            // Se mide desde el alto que el layout concede, descontando ese aire.
            readonly property real ladoReal: Math.max(56, Math.min(musica.width * 0.26, height - aire))

            Visualizador {
                anchors.centerIn: parent
                p: musica.p
                dirCodigo: musica.dirCodigo
                activo: musica.sonando
                circular: true
                numBarras: 56
                grosor: 4
                radio: portada.ladoReal / 2 + 9
                altoMaximo: portada.altoBarras
                escala: musica.volumen
                color: musica.p.texto
            }

            KirigamiPrimitives.ShadowedImage {
                anchors.centerIn: parent
                width: portada.ladoReal
                height: portada.ladoReal
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
                    color: musica.p.texto
                    opacity: 0.22
                    visible: !musica.jugador || !musica.jugador.artUrl
                }
            }
        }

        // ---- Título, disco, intérprete, mandos y barras ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.rightMargin: musica.estrecho ? 0 : 6
            spacing: 5

            Item { Layout.fillHeight: true }

            Text {
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: musica.hay ? musica.jugador.track : ""
                color: musica.p.texto
                font.pixelSize: musica.estrecho ? 14 : 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Text {
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: musica.hay ? musica.jugador.album : ""
                color: musica.p.suave
                font.pixelSize: musica.estrecho ? 11 : 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: text !== ""
            }
            Text {
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: musica.hay ? musica.jugador.artist : ""
                color: musica.p.tenue
                font.pixelSize: musica.estrecho ? 11 : 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: text !== ""
            }

            // Los mandos van ENCIMA de la barra de tiempo, como en la referencia.
            Mandos {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                p: musica.p
                musica: musica
                tamano: musica.estrecho ? 17 : 24
                separacion: musica.estrecho ? 4 : 14
            }

            Barra {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.maximumWidth: 360
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignHCenter
                p: musica.p
                valor: musica.hay && musica.jugador.length > 0 ? musica.jugador.position / musica.jugador.length : 0
                izquierda: musica.hay ? musica.reloj(musica.jugador.position) : "0:00"
                derecha: musica.hay ? musica.reloj(musica.jugador.length) : "0:00"
                onSaltar: v => { if (musica.jugador?.canSeek) musica.jugador.position = v * musica.jugador.length }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 360
                Layout.preferredWidth: 0
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: musica.estrecho ? 6 : 10
                Kirigami.Icon {
                    implicitWidth: 14; implicitHeight: 14
                    source: "audio-volume-low-symbolic"
                    color: musica.p.tenue
                    isMask: true
                }
                Barra {
                    Layout.fillWidth: true
                    p: musica.p
                    tiempos: false
                    valor: musica.volMusica
                    onSaltar: v => musica.ponerVolumen(v)
                }
                Kirigami.Icon {
                    implicitWidth: 14; implicitHeight: 14
                    source: "audio-volume-high-symbolic"
                    color: musica.p.tenue
                    isMask: true
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ---- Vista grande apilada: carátula arriba, datos y mandos debajo ----
    // La tarjeta de Inicio es una columna estrecha (~200 px útiles): en fila la
    // carátula se comía el ancho y los textos, mandos y barras quedaban
    // aplastados o recortados por el `clip` de Pieza. Apilado entra todo.
    ColumnLayout {
        id: enColumna
        anchors.fill: parent
        anchors.margins: 4
        visible: musica.hay && musica.grande && musica.columna
        spacing: 4

        // Los cinco mandos ocupan 4.6*tamano + 68 + 4*separacion: de ahí sale
        // el tamaño más grande que cabe sin desbordar la tarjeta.
        readonly property real tamanoMandos: Math.max(14, Math.min(22, (width - 92) / 4.6))

        // ---- Carátula con la corona de barras ----
        // Es el ÚNICO elástico de la columna: en un ColumnLayout lo que no
        // lleva fillHeight se queda clavado en su tamaño preferido, así que si
        // hubiera dos elásticos se repartirían el hueco y la carátula dejaría
        // de encoger cuando falta alto.
        Item {
            id: portadaCol
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100

            // Los 44 px son el aire que necesita la corona para no salirse.
            readonly property real ladoReal: Math.max(56, Math.min(width - 44, height - 44))

            Visualizador {
                anchors.centerIn: parent
                p: musica.p
                dirCodigo: musica.dirCodigo
                activo: musica.sonando
                circular: true
                numBarras: 56
                grosor: 2.5
                radio: portadaCol.ladoReal / 2 + 9
                altoMaximo: 14
                escala: musica.volumen
                color: musica.p.texto
            }

            KirigamiPrimitives.ShadowedImage {
                anchors.centerIn: parent
                width: portadaCol.ladoReal
                height: portadaCol.ladoReal
                radius: width / 2
                source: musica.hay ? musica.jugador.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                color: musica.p.hueco
                shadow.size: 22
                shadow.color: Qt.rgba(0, 0, 0, 0.5)
                shadow.yOffset: 5

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.3
                    height: width
                    source: "media-album-cover"
                    isMask: true
                    color: musica.p.texto
                    opacity: 0.22
                    visible: !musica.jugador || !musica.jugador.artUrl
                }
            }
        }

        // ---- Título, intérprete, mandos y barras ----
        Text {
            font.family: "JetBrainsMono Nerd Font"
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.topMargin: 2
            text: musica.hay ? musica.jugador.track : ""
            color: musica.p.texto
            font.pixelSize: 14
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            font.family: "JetBrainsMono Nerd Font"
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            text: musica.hay ? musica.jugador.artist : ""
            color: musica.p.tenue
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: text !== ""
        }
        Text {
            font.family: "JetBrainsMono Nerd Font"
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            text: musica.hay ? musica.jugador.album : ""
            color: musica.p.suave
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            // El disco es lo primero que sobra cuando la tarjeta es baja.
            visible: text !== "" && enColumna.height > 300
        }

        Mandos {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            p: musica.p
            musica: musica
            tamano: enColumna.tamanoMandos
            separacion: 6
        }

        Barra {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.topMargin: 2
            p: musica.p
            valor: musica.hay && musica.jugador.length > 0 ? musica.jugador.position / musica.jugador.length : 0
            izquierda: musica.hay ? musica.reloj(musica.jugador.position) : "0:00"
            derecha: musica.hay ? musica.reloj(musica.jugador.length) : "0:00"
            onSaltar: v => { if (musica.jugador?.canSeek) musica.jugador.position = v * musica.jugador.length }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: 6
            Kirigami.Icon {
                implicitWidth: 13; implicitHeight: 13
                source: "audio-volume-low-symbolic"
                color: musica.p.tenue
                isMask: true
            }
            Barra {
                Layout.fillWidth: true
                p: musica.p
                tiempos: false
                valor: musica.volMusica
                onSaltar: v => musica.ponerVolumen(v)
            }
            Kirigami.Icon {
                implicitWidth: 13; implicitHeight: 13
                source: "audio-volume-high-symbolic"
                color: musica.p.tenue
                isMask: true
            }
        }
    }
}
