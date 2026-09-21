import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.kitemmodels as KItemModels

// Brillo de pantalla y de teclado.
ColumnLayout {
    id: brillo

    property var p
    property var pantalla: null
    spacing: 10

    ScreenBrightnessControl { id: pantallas; isSilent: false }
    KeyboardBrightnessControl { id: teclado; isSilent: false }

    Connections {
        target: pantallas.displays
        function actualizar() {
            const roles = ["label", "brightness", "maxBrightness", "displayName"]
                .map(n => target.KItemModels.KRoleNames.role(n))
            if (target.rowCount() === 0) { brillo.pantalla = null; return }
            const i = target.index(0, 0)
            brillo.pantalla = {
                etiqueta: target.data(i, roles[0]),
                valor:    target.data(i, roles[1]),
                maximo:   target.data(i, roles[2]),
                nombre:   target.data(i, roles[3])
            }
        }
        function onDataChanged() { actualizar() }
        function onModelReset() { actualizar() }
        function onRowsInserted() { actualizar() }
        function onRowsRemoved() { actualizar() }
    }

    Component.onCompleted: if (pantallas.displays && pantallas.displays.rowCount() > 0) {
        const roles = ["label", "brightness", "maxBrightness", "displayName"]
            .map(n => pantallas.displays.KItemModels.KRoleNames.role(n))
        const i = pantallas.displays.index(0, 0)
        brillo.pantalla = {
            etiqueta: pantallas.displays.data(i, roles[0]),
            valor:    pantallas.displays.data(i, roles[1]),
            maximo:   pantallas.displays.data(i, roles[2]),
            nombre:   pantallas.displays.data(i, roles[3])
        }
    }

    Deslizador {
        Layout.fillWidth: true
        p: brillo.p
        icono: "brightness-high-symbolic"
        titulo: "PANTALLA"
        activo: pantallas.isBrightnessAvailable && brillo.pantalla !== null
        valor: brillo.pantalla ? brillo.pantalla.valor / brillo.pantalla.maximo : 0
        onMovido: v => {
            const minimo = brillo.pantalla.maximo > 100 ? 1 : 0
            pantallas.setBrightness(brillo.pantalla.nombre,
                                    Math.max(minimo, Math.round(v * brillo.pantalla.maximo)))
        }
    }

    Deslizador {
        Layout.fillWidth: true
        p: brillo.p
        icono: "input-keyboard-brightness-symbolic"
        titulo: "TECLADO"
        activo: teclado.isBrightnessAvailable
        valor: teclado.brightnessMax > 0 ? teclado.brightness / teclado.brightnessMax : 0
        onMovido: v => teclado.brightness = Math.round(v * teclado.brightnessMax)
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: !teclado.isBrightnessAvailable
        text: "Este equipo no informa de brillo de teclado."
        color: brillo.p.velo(0.3)
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }
}
