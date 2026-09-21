import QtQuick
import org.kde.taskmanager as TaskManager

// ¿Hay una ventana a pantalla completa en el escritorio actual? Entonces los
// paneles de arriba no se ven y lo que se anima en ellos puede descansar.
// (Una ventana maximizada no cuenta: los paneles le reservan su sitio.)
QtObject {
    id: tapado

    property bool pantallaCompleta: false

    readonly property TaskManager.VirtualDesktopInfo escritorios: TaskManager.VirtualDesktopInfo {}
    readonly property TaskManager.ActivityInfo actividades: TaskManager.ActivityInfo {}

    readonly property TaskManager.TasksModel ventanas: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: tapado.escritorios.currentDesktop
        activity: tapado.actividades.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true
        onDataChanged: Qt.callLater(tapado.revisar)
        onCountChanged: Qt.callLater(tapado.revisar)
    }

    function revisar() {
        const rolVentana = TaskManager.AbstractTasksModel.IsWindow
        const rolCompleta = TaskManager.AbstractTasksModel.IsFullScreen
        let hay = false
        for (let i = 0; i < ventanas.count && !hay; i++) {
            const t = ventanas.index(i, 0)
            hay = !!ventanas.data(t, rolVentana) && !!ventanas.data(t, rolCompleta)
        }
        pantallaCompleta = hay
    }

    Component.onCompleted: revisar()
}
