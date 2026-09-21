import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

// Ventana de capa superpuesta que ocupa la pantalla entera, por encima de los
// paneles (exclusionZone -1 hace que no le recorten sitio).
Window {
    id: ventana

    visible: true
    color: "transparent"
    title: "Selector de fondos"

    LayerShell.Window.scope: "selector-fondos"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    Selector {
        id: selector
        anchors.fill: parent
        focus: true
        opacity: 0
        scale: 0.985
        onCerrar: salida.start()

        Component.onCompleted: {
            opacity = 1
            scale = 1
        }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    SequentialAnimation {
        id: salida
        NumberAnimation { target: selector; property: "opacity"; to: 0; duration: 130 }
        ScriptAction { script: Qt.quit() }
    }
}
