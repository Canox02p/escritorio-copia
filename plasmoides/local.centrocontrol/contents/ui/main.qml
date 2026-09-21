import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.volume as Vol
import org.kde.bluezqt as BluezQt
import org.kde.plasma.networkmanagement as PlasmaNM

PlasmoidItem {
    id: root

    readonly property string dirCodigo: decodeURIComponent(Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, ""))
    property int seccion: 0

    Plasmoid.icon: "preferences-system"
    toolTipMainText: "Centro de control"
    toolTipSubText: "Red, Bluetooth, audio, brillo, batería y sesión"
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    Paleta { id: paleta; dirCodigo: root.dirCodigo }

    // Datos que se ven en la tira del panel
    readonly property var salida: Vol.PreferredDevice.sink
    readonly property int volumen: salida ? Math.round(salida.volume / Vol.PulseAudio.NormalVolume * 100) : 0
    readonly property bool silenciado: !!salida && salida.muted
    readonly property QtObject bluetooth: BluezQt.Manager
    readonly property var adaptadorBt: bluetooth.usableAdapter
                                       || (bluetooth.adapters.length > 0 ? bluetooth.adapters[0] : null)
    // El icono de Bluetooth solo está en la barra si el aparato está encendido.
    readonly property bool btEncendido: !!adaptadorBt && adaptadorBt.powered && !bluetooth.bluetoothBlocked
    readonly property bool btActivo: bluetooth.connectedDevices.length > 0

    PlasmaNM.NetworkStatus { id: estadoRed }
    PlasmaNM.ConnectionIcon { id: simboloRed }
    PlasmaNM.EnabledConnections { id: radios }
    // Ojo: activeConnections nunca viene vacío (sin red dice "Desconectado"),
    // así que se decide con el icono de Plasma y la conectividad real de NM
    readonly property string iconoPlasma: simboloRed.connectionIcon || ""
    readonly property bool hayEnlace: iconoPlasma !== "" && !/disconnected|offline|unavailable|flightmode/.test(iconoPlasma)
    // 4 = internet completo; 0 = NM no lo comprueba (entonces basta con el enlace)
    readonly property bool conectado: hayEnlace && (estadoRed.connectivity === 4 || estadoRed.connectivity === 0)
    readonly property bool porCable: iconoPlasma.indexOf("wired") >= 0
    readonly property bool modoAvion: PlasmaNM.Configuration.airplaneModeEnabled
    // Wifi apagado y sin cable: el icono de internet se quita de la barra
    readonly property bool redVisible: modoAvion || hayEnlace || simboloRed.connecting || radios.wirelessEnabled
    // "network-wireless-80" → intensidad real de la señal
    readonly property string iconoSenal: {
        const n = parseInt((iconoPlasma.match(/(\d+)$/) || [0, 100])[1])
        return "network-wireless-signal-" + (n >= 80 ? "excellent" : n >= 60 ? "good" : n >= 40 ? "ok" : n >= 20 ? "weak" : "none") + "-symbolic"
    }
    readonly property string iconoRed: modoAvion ? "network-flightmode-on-symbolic"
                                       : simboloRed.connecting ? "network-wireless-acquiring-symbolic"
                                       : conectado ? (porCable ? "network-wired-activated-symbolic" : iconoSenal)
                                       : "network-wireless-disconnected-symbolic"   // sin conexión o sin internet
    readonly property string pistaRed: modoAvion ? "Modo avión"
                                       : conectado ? estadoRed.activeConnections
                                       : simboloRed.connecting ? "Conectando…"
                                       : hayEnlace ? "Conectado, pero sin internet" : "Sin conexión"

    P5Support.DataSource {
        id: energia
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }
    readonly property var bateria: energia.data["Battery"] || ({})
    readonly property bool hayBateria: !!bateria["Has Battery"]
    readonly property int carga: bateria["Percent"] || 0
    readonly property bool enchufado: !!(energia.data["AC Adapter"] || {})["Plugged in"]

    function abrir(i) {
        if (root.expanded && root.seccion === i) {
            root.expanded = false
        } else {
            root.seccion = i
            root.expanded = true
        }
    }

    // ---- Tira del panel ----
    compactRepresentation: MouseArea {
        id: tira

        readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

        Layout.minimumWidth: horizontal ? fila.implicitWidth + 10 : 0
        Layout.minimumHeight: horizontal ? 0 : fila.implicitHeight + 10
        implicitWidth: fila.implicitWidth + 10
        hoverEnabled: true
        onClicked: root.abrir(root.seccion)

        // Cada trozo abre su pestaña. Mismo lenguaje que la tira de CPU/GPU:
        // monoespaciada, sin fondos redondeados, y el aire lo dan los huecos.
        component Trozo: Item {
            id: trozo
            property string icono: ""
            property string texto: ""
            property bool encendido: false
            property int destino: 0
            property string pista: ""

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: contenido.implicitWidth
            implicitHeight: Math.max(contenido.implicitHeight, 16)

            Row {
                id: contenido
                anchors.centerIn: parent
                spacing: 7

                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14
                    source: trozo.icono
                    isMask: true
                    color: trozo.encendido ? paleta.acento : paleta.texto
                    opacity: toque.containsMouse ? 1 : (trozo.encendido ? 0.95 : 0.78)
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: trozo.texto
                    visible: text !== ""
                    color: paleta.texto
                    opacity: toque.containsMouse ? 1 : 0.86
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
            }

            MouseArea {
                id: toque
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.abrir(trozo.destino)
                onContainsMouseChanged: if (containsMouse && trozo.pista !== "") {
                    root.toolTipMainText = trozo.pista
                }
            }
        }

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 18

            Trozo {
                visible: root.redVisible
                icono: root.iconoRed
                destino: 0
                pista: root.pistaRed
            }
            Trozo {
                icono: root.silenciado ? "audio-volume-muted" : "audio-volume-high"
                texto: root.volumen + "%"
                destino: 2
                pista: "Volumen " + root.volumen + "%"
            }
            Trozo {
                visible: root.btEncendido
                icono: root.btActivo ? "bluetooth-active-symbolic" : "bluetooth-symbolic"
                encendido: root.btActivo
                destino: 1
                pista: root.btActivo ? root.bluetooth.connectedDevices.length + " dispositivo(s)" : "Bluetooth encendido"
            }
            Trozo {
                visible: root.hayBateria
                icono: root.enchufado ? "battery-full-charged-symbolic" : "battery-full-symbolic"
                texto: root.carga + "%"
                destino: 4
                pista: root.enchufado ? "Enchufado · " + root.carga + "%" : "Batería " + root.carga + "%"
            }
            Trozo {
                icono: "system-shutdown"
                destino: 5
                pista: "Apagar, reiniciar, bloquear…"
            }
        }
    }

    fullRepresentation: Centro {
        Layout.minimumWidth: 480
        Layout.minimumHeight: 380
        Layout.preferredWidth: 540
        Layout.preferredHeight: 430

        p: paleta
        dirCodigo: root.dirCodigo
        vista: root.seccion
        onVistaChanged: root.seccion = vista
        onCerrar: root.expanded = false
    }
}
