import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

// Capa superpuesta a pantalla completa, igual que el selector de fondos:
// exclusionZone -1 para que los paneles no le recorten sitio, y teclado en
// exclusiva para que Esc y el buscador funcionen.
Window {
    id: ventana

    visible: true
    color: "transparent"
    title: "Atajos de teclado"

    LayerShell.Window.scope: "atajos-teclado"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    Atajos {
        id: panel
        anchors.fill: parent
        focus: true
        dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
        opacity: 0
        scale: 0.985
        onCerrar: salida.start()

        Component.onCompleted: { opacity = 1; scale = 1 }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    SequentialAnimation {
        id: salida
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 130 }
        ScriptAction { script: Qt.quit() }
    }
}
