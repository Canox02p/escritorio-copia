import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.volume as Vol

// Salida, micrófono, elección de altavoces y volumen por aplicación.
ColumnLayout {
    id: audio

    property var p
    spacing: 9

    readonly property var salida: Vol.PreferredDevice.sink
    readonly property var entrada: Vol.PreferredDevice.source

    Vol.SinkModel { id: altavoces }
    Vol.SinkInputModel { id: programas }

    // Un aparato puede tener varios puertos (altavoces y jack de auriculares
    // son el mismo sumidero), así que la lista va por puerto, no por aparato.
    property var salidas: []

    function esAuricular(nombre) {
        const n = String(nombre || "").toLowerCase()
        return n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0 || n.indexOf("auricular") >= 0
    }

    function iconoSalida(nombre) {
        const n = String(nombre || "").toLowerCase()
        if (n.indexOf("bluez") >= 0 || n.indexOf("bluetooth") >= 0 || n.indexOf("buds") >= 0)
            return "preferences-system-bluetooth-symbolic"
        if (audio.esAuricular(n)) return "audio-headphones-symbolic"
        if (n.indexOf("hdmi") >= 0 || n.indexOf("displayport") >= 0) return "video-display-symbolic"
        return "audio-speakers-symbolic"
    }

    function recalcularSalidas() {
        const rol = altavoces.KItemModels.KRoleNames.role("PulseObject")
        const nuevas = []
        for (let i = 0; i < altavoces.rowCount(); i++) {
            const o = altavoces.data(altavoces.index(i, 0), rol)
            if (!o) continue
            const puertos = o.ports || []
            if (puertos.length > 1) {
                for (let j = 0; j < puertos.length; j++) {
                    const p = puertos[j]
                    if (!p) continue
                    nuevas.push({
                        objeto: o, puerto: j,
                        etiqueta: p.description || p.name,
                        detalle: o.description,
                        // availability: 0 sin saber, 1 disponible, 2 no disponible
                        disponible: p.availability !== 2,
                        conector: audio.esAuricular(p.name + " " + p.description),
                        icono: audio.iconoSalida(o.name + " " + p.name + " " + p.description)
                    })
                }
            } else {
                nuevas.push({
                    objeto: o, puerto: -1,
                    etiqueta: o.description || o.name,
                    detalle: "",
                    disponible: true,
                    conector: false,
                    icono: audio.iconoSalida(o.name + " " + o.description)
                })
            }
        }
        audio.salidas = nuevas
    }

    readonly property bool aLaVista: audio.visible && !!audio.Window.window && audio.Window.window.visible
    onALaVistaChanged: if (aLaVista) recalcularSalidas()
    Timer { id: relojSalidas; interval: 1500; running: audio.aLaVista; repeat: true; onTriggered: audio.recalcularSalidas() }
    Component.onCompleted: recalcularSalidas()
    Connections {
        target: altavoces
        function onRowsInserted() { audio.recalcularSalidas() }
        function onRowsRemoved() { audio.recalcularSalidas() }
        function onModelReset() { audio.recalcularSalidas() }
        function onDataChanged() { audio.recalcularSalidas() }
    }

    function porcentaje(obj) {
        return obj ? obj.volume / Vol.PulseAudio.NormalVolume : 0
    }
    // Cambiar de altavoces: además de marcarlo por defecto hay que mudar lo
    // que ya está sonando, porque PipeWire deja los programas donde estaban
    // y parece que el cambio no ha hecho nada.
    function elegirSalida(obj, puerto) {
        if (!obj) return
        if (puerto !== undefined && puerto >= 0 && obj.activePortIndex !== puerto)
            obj.activePortIndex = puerto
        obj["default"] = true
        const rol = programas.KItemModels.KRoleNames.role("PulseObject")
        for (let i = 0; i < programas.rowCount(); i++) {
            const flujo = programas.data(programas.index(i, 0), rol)
            if (flujo) flujo.deviceIndex = obj.index
        }
    }

    function poner(obj, v) {
        if (obj) obj.volume = Math.round(v * Vol.PulseAudio.NormalVolume)
    }
    // El nombre de la aplicación llega en sitios distintos según el programa.
    function nombreApp(fila) {
        const obj = fila.PulseObject
        const cli = fila.Client
        if (typeof cli === "string" && cli !== "") return cli
        if (cli && cli.name) return cli.name
        if (obj && obj.properties) {
            const props = obj.properties
            if (props["application.name"]) return props["application.name"]
            if (props["media.name"]) return props["media.name"]
        }
        return fila.Name || "Aplicación"
    }

    component Rotulo: Text {
        color: audio.p.tenue
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 9

        Deslizador {
            Layout.fillWidth: true
            p: audio.p
            icono: audio.salida && audio.salida.muted ? "audio-volume-muted" : "audio-volume-high"
            titulo: "SALIDA"
            activo: !!audio.salida
            valor: audio.porcentaje(audio.salida)
            onMovido: v => audio.poner(audio.salida, v)
        }

        Deslizador {
            Layout.fillWidth: true
            p: audio.p
            icono: audio.entrada && audio.entrada.muted ? "microphone-sensitivity-muted" : "audio-input-microphone"
            titulo: "MICRÓFONO"
            activo: !!audio.entrada
            valor: audio.porcentaje(audio.entrada)
            onMovido: v => audio.poner(audio.entrada, v)
        }
    }

    // ---- Elegir por dónde suena ----
    Rotulo { Layout.topMargin: 2; text: "DISPOSITIVO DE SALIDA" }

    ListView {
        id: listaAltavoces
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 130)
        clip: true
        spacing: 5
        model: audio.salidas
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: Deslizadera { p: audio.p }

        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 140 } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }

        delegate: Rectangle {
            id: aparato
            required property var modelData
            readonly property var objeto: modelData.objeto
            readonly property bool activo: !!objeto && !!audio.salida
                                           && objeto.index === audio.salida.index
                                           && (modelData.puerto < 0 || objeto.activePortIndex === modelData.puerto)

            width: listaAltavoces.width - 12
            height: 38
            radius: 10
            color: activo ? audio.p.hueco : (sobre.hovered ? audio.p.velo(0.08) : audio.p.tarjeta)
            border.width: 1
            border.color: activo ? audio.p.acento : audio.p.borde
            scale: toque.pressed ? 0.985 : 1
            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
            Behavior on scale { NumberAnimation { duration: 90 } }

            HoverHandler { id: sobre; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: toque
                onTapped: audio.elegirSalida(aparato.objeto, aparato.modelData.puerto)
            }

            readonly property bool disponible: aparato.modelData.disponible !== false
            // Un jack vacío sí merece aviso; los altavoces de la tapa están siempre
            readonly property bool apagado: !disponible && aparato.modelData.conector === true

            Kirigami.Icon {
                id: simboloAparato
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                source: aparato.modelData.icono
                isMask: true
                color: aparato.activo ? audio.p.acento : audio.p.texto
                opacity: aparato.activo ? 1 : (aparato.apagado ? 0.4 : 0.7)
            }

            Text {
                anchors.left: simboloAparato.right
                anchors.leftMargin: 10
                anchors.right: marca.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: aparato.modelData.etiqueta
                color: audio.p.texto
                opacity: aparato.apagado ? 0.55 : 1
                font.pixelSize: 11
                font.weight: aparato.activo ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                id: marca
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: aparato.activo ? "EN USO" : (aparato.apagado ? "SIN CONECTAR" : "")
                color: aparato.activo ? audio.p.acento : audio.p.velo(0.35)
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }
    }

    // ---- Volumen por aplicación ----
    Rotulo { Layout.topMargin: 2; text: "APLICACIONES" }

    ListView {
        id: listaApps
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 7
        model: programas
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: Deslizadera { p: audio.p }

        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 140 } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }

        delegate: Deslizador {
            required property var model
            width: ListView.view.width - 12
            p: audio.p
            icono: "audio-volume-high"
            titulo: String(audio.nombreApp(model)).toUpperCase()
            valor: audio.porcentaje(model.PulseObject)
            onMovido: v => audio.poner(model.PulseObject, v)
        }

        Text {
            anchors.centerIn: parent
            visible: programas.count === 0
            text: "Nada reproduciendo audio"
            color: audio.p.velo(0.3)
            font.pixelSize: 12
        }
    }
}
