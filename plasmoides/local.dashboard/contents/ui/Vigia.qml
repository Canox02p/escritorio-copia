import QtQuick
import org.kde.notificationmanager as NM
import org.kde.plasma.plasma5support as P5Support

// Avisa cuando entra una notificación nueva. Vive en el root del plasmoide
// (igual que el historial del portapapeles): si viviera dentro del popup solo
// se enteraría con el tablero abierto, que es justo cuando no hace falta.
Item {
    id: vigia

    signal llega(var datos)

    // Al arrancar plasmashell el modelo suelta de golpe todas las que ya
    // estaban: durante los primeros segundos no hacemos caso.
    property bool listo: false
    Timer { interval: 4000; running: true; onTriggered: vigia.listo = true }

    NM.Notifications {
        id: modelo
        showNotifications: true
        showJobs: false
        showExpired: false
        showDismissed: false
        sortMode: NM.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NM.Notifications.GroupDisabled
        urgencies: NM.Notifications.LowUrgency | NM.Notifications.NormalUrgency | NM.Notifications.CriticalUrgency
    }

    // El cuerpo llega con marcado de Qt (<b>, <br/>, entidades...) y en una
    // píldora de una línea eso se ve fatal.
    function limpiar(t) {
        return String(t || "")
            .replace(/<br\s*\/?>/gi, " ")
            .replace(/<\?[\s\S]*?\?>/g, "")
            .replace(/<![\s\S]*?>/g, "")
            .replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, '"')
            .replace(/&apos;/g, "'")
            .replace(/&#39;/g, "'")
            .replace(/&nbsp;/g, " ")
            .replace(/\s+/g, " ")
            .trim()
    }

    // ---- Batería: enchufar, desenchufar y quedarse sin carga ----
    P5Support.DataSource {
        id: energia
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }
    readonly property var bateria: energia.data["Battery"] || ({})
    readonly property bool hayBateria: !!bateria["Has Battery"]
    readonly property int carga: bateria["Percent"] || 0
    readonly property bool enchufado: !!(energia.data["AC Adapter"] || {})["Plugged in"]

    property bool enchufadoAntes: false
    property bool avisadaBaja: false
    property bool avisadaCritica: false

    onEnchufadoChanged: {
        if (!vigia.listo || !vigia.hayBateria) { vigia.enchufadoAntes = vigia.enchufado; return }
        if (vigia.enchufado === vigia.enchufadoAntes) return
        vigia.enchufadoAntes = vigia.enchufado
        if (vigia.enchufado) { vigia.avisadaBaja = false; vigia.avisadaCritica = false }
        vigia.llega({
            icono: vigia.enchufado ? "battery-charging-symbolic" : "battery-good-symbolic",
            app: "Batería",
            resumen: vigia.enchufado ? "Cargando" : "Con batería",
            cuerpo: vigia.carga + "%",
            urgente: false,
            creado: new Date()
        })
    }

    onCargaChanged: {
        if (!vigia.listo || !vigia.hayBateria || vigia.enchufado) return
        if (vigia.carga > 25) { vigia.avisadaBaja = false; vigia.avisadaCritica = false; return }
        if (vigia.carga <= 7 && !vigia.avisadaCritica) {
            vigia.avisadaCritica = true
            vigia.avisadaBaja = true
            vigia.llega({
                icono: "battery-empty-symbolic", app: "Batería",
                resumen: "Batería crítica", cuerpo: "Quedan " + vigia.carga + "%, enchufa el cargador",
                urgente: true, creado: new Date()
            })
        } else if (vigia.carga <= 15 && !vigia.avisadaBaja) {
            vigia.avisadaBaja = true
            vigia.llega({
                icono: "battery-low-symbolic", app: "Batería",
                resumen: "Queda poca batería", cuerpo: vigia.carga + "% restante",
                urgente: false, creado: new Date()
            })
        }
    }

    Component.onCompleted: vigia.enchufadoAntes = vigia.enchufado

    Instantiator {
        model: modelo
        delegate: QtObject {
            required property var model
            readonly property var datos: ({
                icono: model.applicationIconName || model.iconName || "dialog-information",
                app: vigia.limpiar(model.applicationName),
                resumen: vigia.limpiar(model.summary),
                cuerpo: vigia.limpiar(model.body),
                urgente: model.urgency === NM.Notifications.CriticalUrgency,
                creado: model.created
            })
        }
        onObjectAdded: (index, obj) => {
            if (!vigia.listo || !obj)
                return
            const d = obj.datos
            // Si no tiene nada que enseñar, no interrumpimos la barra
            if (!d.resumen && !d.cuerpo)
                return
            // Las que ya estaban (el modelo las reinserta al reordenar) no cuentan
            if (d.creado && (new Date().getTime() - d.creado.getTime()) > 15000)
                return
            vigia.llega(d)
        }
    }
}
