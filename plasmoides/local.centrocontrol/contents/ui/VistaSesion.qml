import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.sessions as Sesiones

// Bloquear, cerrar sesión, suspender, reiniciar, apagar.
GridLayout {
    id: sesion

    property var p
    signal cerrar()

    columns: 2
    rowSpacing: 10
    columnSpacing: 10

    Sesiones.SessionManagement { id: gestor }

    component Accion: Boton {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 56
        p: sesion.p
    }

    Accion {
        icono: "system-lock-screen"
        texto: "BLOQUEAR"
        enabled: gestor.canLock
        onPulsado: { sesion.cerrar(); gestor.lock() }
    }
    Accion {
        icono: "system-suspend"
        texto: "SUSPENDER"
        enabled: gestor.canSuspend
        onPulsado: { sesion.cerrar(); gestor.suspend() }
    }
    Accion {
        icono: "system-log-out"
        texto: "CERRAR SESIÓN"
        enabled: gestor.canLogout
        onPulsado: { sesion.cerrar(); gestor.requestLogoutPrompt() }
    }
    Accion {
        icono: "system-reboot"
        texto: "REINICIAR"
        enabled: gestor.canReboot
        onPulsado: { sesion.cerrar(); gestor.requestReboot() }
    }
    Accion {
        Layout.columnSpan: 2
        icono: "system-shutdown"
        texto: "APAGAR"
        peligro: true
        enabled: gestor.canShutdown
        onPulsado: { sesion.cerrar(); gestor.requestShutdown() }
    }
}
