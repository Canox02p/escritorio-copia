import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
    property int orden: 0   // columna por la que se ordena la lista: 0 CPU, 1 GPU, 2 memoria

    Plasmoid.icon: "utilities-system-monitor"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: "Administrador de tareas"
    toolTipSubText: "CPU " + Math.round(numero(sCpu)) + "% · GPU " + Math.round(numero(sGpu))
                    + "% · RAM " + Math.round(numero(sRam)) + "%"

    Paleta { id: paleta; dirCodigo: root.dirCodigo }

    // ---------- Sensores ----------
    Sensors.Sensor { id: sCpu;      sensorId: "cpu/all/usage";                updateRateLimit: 1000 }
    Sensors.Sensor { id: sCpuTemp;  sensorId: "cpu/all/averageTemperature";   updateRateLimit: 2000 }
    Sensors.Sensor { id: sRam;      sensorId: "memory/physical/usedPercent";  updateRateLimit: 1000 }
    Sensors.Sensor { id: sGpu;      sensorId: "gpu/gpu0/usage";               updateRateLimit: 1000 }
    Sensors.Sensor { id: sGpuTemp;  sensorId: "gpu/gpu0/temperature";         updateRateLimit: 2000 }

    function numero(sensor) {
        const v = Number(sensor.value)
        return isFinite(v) ? v : 0
    }

    // Tocar un dato abre la lista ordenada por él; tocar el mismo otra vez, la cierra.
    function abrir(i) {
        if (root.expanded && root.orden === i) {
            root.expanded = false
        } else {
            root.orden = i
            root.expanded = true
        }
    }

    // ---------- Vista compacta (tira para el panel) ----------
    compactRepresentation: MouseArea {
        id: tira

        readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

        Layout.minimumWidth: horizontal ? fila.implicitWidth + 16 : 0
        Layout.minimumHeight: horizontal ? 0 : fila.implicitHeight + 8
        Layout.preferredWidth: Layout.minimumWidth
        implicitWidth: fila.implicitWidth + 16
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Un solo MouseArea para toda la tira: se mira qué dato hay debajo
        onClicked: mouse => {
            const dato = fila.childAt(mouse.x - fila.x, fila.height / 2)
            root.abrir(dato ? dato.destino : root.orden)
        }

        // Cifras a ancho fijo para que la tira no baile cada segundo.
        function pct(sensor) {
            return String(Math.round(root.numero(sensor))).padStart(2, " ") + "%"
        }

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 20

            component Dato: Row {
                property string etiqueta: ""
                property string valor: ""
                property int destino: 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    text: parent.etiqueta
                    color: Kirigami.Theme.textColor
                    opacity: tira.containsMouse ? 1 : 0.72
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
                Text {
                    text: parent.valor
                    color: Kirigami.Theme.textColor
                    opacity: tira.containsMouse ? 1 : 0.86
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
            }

            Dato { etiqueta: "CPU"; valor: tira.pct(sCpu); destino: 0 }
            Dato { etiqueta: "GPU"; valor: tira.pct(sGpu); destino: 1 }
            Dato { etiqueta: "RAM"; valor: tira.pct(sRam); destino: 2 }
            Dato {
                etiqueta: ""
                valor: String(Math.round(root.numero(sCpuTemp))).padStart(2, " ") + "°C"
                destino: 0
            }
        }
    }

    // ---------- Administrador de tareas ----------
    fullRepresentation: Administrador {
        Layout.minimumWidth: 500
        Layout.minimumHeight: 420
        Layout.preferredWidth: 580
        Layout.preferredHeight: 520

        p: paleta
        dirCodigo: root.dirCodigo
        activo: root.expanded
        orden: root.orden
        onElegir: i => root.orden = i

        cpuTotal: root.numero(sCpu)
        gpuTotal: root.numero(sGpu)
        ramPorcentaje: root.numero(sRam)
        cpuTemp: root.numero(sCpuTemp)
        gpuTemp: root.numero(sGpuTemp)
    }
}
