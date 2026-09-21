import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Colores derivados del fondo de pantalla: colores.sh los imprime en json.
Item {
    id: paleta

    property string dirCodigo: ""

    // Blanco y negro con cristal esmerilado: casi todo es blanco con poca alfa
    // sobre un fondo oscuro translúcido, para que el desenfoque de KWin se vea.
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

    P5Support.DataSource {
        id: lector
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            paleta.aplicar(data["stdout"])
        }
    }

    function recargar() {
        if (dirCodigo === "") return
        lector.connectSource("bash '" + dirCodigo + "colores.sh'")
    }

    function aplicar(salida) {
        try {
            const c = JSON.parse(salida)
            acento = c.acento; suave = c.suave; fondo = c.fondo; tarjeta = c.tarjeta
            hueco = c.hueco; borde = c.borde; texto = c.texto; tenue = c.tenue
        } catch (e) { }
    }

    Component.onCompleted: recargar()
    onDirCodigoChanged: recargar()
}
