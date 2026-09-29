import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Colores del escritorio. Salen del MISMO acento que la pantalla de bloqueo:
// colores.sh lee la elección de ~/.config/bloqueo-colores (o el tono del fondo
// si está en "auto") y devuelve la paleta en json. vigila-color.sh avisa cuando
// cambia —al desbloquear, o si se cambia el fondo— y aquí se recarga sola.
Item {
    id: paleta

    property string dirCodigo: ""

    // Cristal esmerilado teñido con el acento: casi todo es un blanco con poca
    // alfa sobre fondo oscuro translúcido, para que el desenfoque de KWin se
    // vea; el acento es el único color pleno.
    property color acento:  "#f2f2f4"
    property color suave:   "#cfcfd4"
    property color fondo:   "#660a0a0c"
    property color tarjeta: "#1affffff"
    property color hueco:   "#1fffffff"
    property color borde:   "#26ffffff"
    property color texto:   "#f4f4f6"
    property color tenue:   "#9a9aa2"

    readonly property color sobreAcento: Qt.hsva(0, 0, acento.hsvValue > 0.6 ? 0.1 : 0.98, 1)

    function velo(alfa) { return Qt.rgba(texto.r, texto.g, texto.b, alfa) }

    // El cambio de color se funde, como en el bloqueo. En la primera carga no:
    // ahí se pasa del blanco de arranque al color real y se vería un parpadeo.
    property bool animar: false
    Behavior on acento  { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on suave   { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on fondo   { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on tarjeta { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on hueco   { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on borde   { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on texto   { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Behavior on tenue   { enabled: paleta.animar; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }

    P5Support.DataSource {
        id: lector
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            paleta.aplicar(data["stdout"])
        }
    }

    // vigila-color.sh se queda bloqueado hasta que el acento cambia. No hay
    // sondeo desde QML: el proceso duerme.
    P5Support.DataSource {
        id: vigia
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            paleta.recargar()
            revigilar.start()
        }
    }

    Timer { id: revigilar; interval: 300; onTriggered: paleta.vigilar() }

    function recargar() {
        if (dirCodigo === "") return
        lector.connectSource("bash '" + dirCodigo + "colores.sh'")
    }

    function vigilar() {
        if (dirCodigo === "") return
        vigia.connectSource("bash '" + dirCodigo + "vigila-color.sh'")
    }

    function aplicar(salida) {
        try {
            const c = JSON.parse(salida)
            acento = c.acento; suave = c.suave; fondo = c.fondo; tarjeta = c.tarjeta
            hueco = c.hueco; borde = c.borde; texto = c.texto; tenue = c.tenue
            animar = true
        } catch (e) { }
    }

    Component.onCompleted: { recargar(); vigilar() }
    onDirCodigoChanged: { recargar(); vigilar() }
}
