import QtQuick
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

// Lecturas del sistema en un solo sitio.
Item {
    id: s

    property string dirCodigo: ""
    // Con el tablero cerrado no se mide nada: ni sensores, ni scripts, ni historial
    property bool activo: true
    property var disco: ({})
    property var equipo: ({})
    property var totales: ({})
    readonly property int muestras: 50
    property var histBajada: []
    property var histSubida: []

    Sensors.Sensor { id: cpuUso;   sensorId: "cpu/all/usage";               updateRateLimit: 1000; enabled: s.activo }
    Sensors.Sensor { id: cpuTemp;  sensorId: "cpu/all/averageTemperature";  updateRateLimit: 2000; enabled: s.activo }
    Sensors.Sensor { id: ramPct;   sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000; enabled: s.activo }
    Sensors.Sensor { id: ramUsada; sensorId: "memory/physical/used";        updateRateLimit: 2000; enabled: s.activo }
    Sensors.Sensor { id: ramTotal; sensorId: "memory/physical/total";       updateRateLimit: 60000; enabled: s.activo }
    Sensors.Sensor { id: gpuUso;   sensorId: "gpu/gpu0/usage";              updateRateLimit: 1000; enabled: s.activo }
    Sensors.Sensor { id: gpuTemp;  sensorId: "gpu/gpu0/temperature";        updateRateLimit: 2000; enabled: s.activo }
    Sensors.Sensor { id: bajada;   sensorId: "network/all/download";        updateRateLimit: 1000; enabled: s.activo }
    Sensors.Sensor { id: subida;   sensorId: "network/all/upload";          updateRateLimit: 1000; enabled: s.activo }

    function num(sensor) { const v = Number(sensor.value); return isFinite(v) ? v : 0 }

    readonly property real cpu: num(cpuUso)
    readonly property real cpuGrados: num(cpuTemp)
    readonly property real ram: num(ramPct)
    readonly property real ramGB: num(ramUsada) / 1073741824
    readonly property real ramTotalGB: num(ramTotal) / 1073741824
    readonly property real gpu: num(gpuUso)
    readonly property real gpuGrados: num(gpuTemp)
    readonly property real bajadaBs: num(bajada)
    readonly property real subidaBs: num(subida)

    function tamano(b) {
        if (b < 1048576) return (b / 1024).toFixed(0) + " KB"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB"
        return (b / 1073741824).toFixed(2) + " GB"
    }

    function velocidad(b) {
        if (b < 1024) return Math.round(b) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(b < 10240 ? 1 : 0) + " KB/s"
        return (b / 1048576).toFixed(1) + " MB/s"
    }

    P5Support.DataSource {
        id: ejecutar
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            try {
                const j = JSON.parse(data["stdout"])
                if (source.includes("disco.sh")) s.disco = j
                else if (source.includes("equipo.sh")) s.equipo = j
                else if (source.includes("red.sh")) s.totales = j
            } catch (e) { }
        }
    }

    function consultar() {
        if (dirCodigo === "") return
        ejecutar.connectSource("bash '" + dirCodigo + "disco.sh'")
        ejecutar.connectSource("bash '" + dirCodigo + "red.sh'")
        if (!equipo.cpu) ejecutar.connectSource("bash '" + dirCodigo + "equipo.sh'")
    }

    Component.onCompleted: if (activo) consultar()
    onDirCodigoChanged: if (activo) consultar()
    // Al volver a abrir, la gráfica de red empieza limpia en vez de enlazar con datos viejos
    onActivoChanged: if (activo) {
        histBajada = []
        histSubida = []
        consultar()
    }
    Timer { interval: 30000; running: s.activo; repeat: true; onTriggered: s.consultar() }
    Timer {
        interval: 5000; running: s.activo; repeat: true
        onTriggered: if (s.dirCodigo !== "") ejecutar.connectSource("bash '" + s.dirCodigo + "red.sh'")
    }

    // Historial para la gráfica de red
    Timer {
        interval: 1000; running: s.activo; repeat: true
        onTriggered: {
            const a = s.histBajada.concat([s.bajadaBs])
            const b = s.histSubida.concat([s.subidaBs])
            if (a.length > s.muestras) a.splice(0, a.length - s.muestras)
            if (b.length > s.muestras) b.splice(0, b.length - s.muestras)
            s.histBajada = a
            s.histSubida = b
        }
    }
}
