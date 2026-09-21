/*
    Pantalla de bloqueo a medida (estilo "caelestia"): panel de cristal con
    tiempo, ficha del equipo y música a la izquierda; reloj, carátula y
    contraseña en el centro; medidores, previsión y sesión a la derecha.

    El fondo es el del escritorio en ese momento, difuminado (fondo.sh), y el
    acento sale de su paleta. Los puntos de la ficha lo cambian; la elección se
    guarda en ~/.config/bloqueo-colores (línea 1: "auto" o #rrggbb, línea 2:
    el color personalizado).
*/

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as P5Support

Item {
    id: ui

    readonly property string mono: "JetBrainsMono Nerd Font"

    // ── Colores ──────────────────────────────────────────────────────
    property var fondo: ({})          // salida de fondo.sh
    property string eleccion: "auto"  // "auto" o un #rrggbb
    property string propio: ""        // color personalizado guardado
    property bool editando: false     // editor del color personalizado abierto
    property color borrador: "#b4befe"

    // Tonos de la paleta del fondo, avivados para que sirvan de acento y sin repetidos
    readonly property var tonos: {
        const salida = [];
        for (const hex of (ui.fondo.paleta || [])) {
            const c = ui.avivar(hex);
            const gris = c.hslSaturation < 0.1;
            const repetido = salida.some(o => {
                const og = o.hslSaturation < 0.1;
                if (gris || og) return gris && og;
                const d = Math.abs(o.hslHue - c.hslHue);
                return Math.min(d, 1 - d) < 0.05;
            });
            if (!repetido) salida.push(c);
            if (salida.length === 6) break;
        }
        // Fondos de un solo color: se completa con armónicos del tono automático
        const base = ui.tonoFondo;
        const s = Math.max(base.hslSaturation, 0.5), l = base.hslLightness;
        for (const giro of [0.5, 0.08, -0.08, 0.33, -0.33, 0.17]) {
            if (salida.length >= 6) break;
            salida.push(Qt.hsla((Math.max(0, base.hslHue) + giro + 1) % 1, s, l, 1));
        }
        return salida;
    }
    // El tono automático: el más vivo, primando los que más abundan
    readonly property color tonoFondo: {
        const paleta = ui.fondo.paleta || [];
        let mejor = null, puntos = -1;
        paleta.forEach((hex, i) => {
            const c = Qt.color(hex);
            const l = c.hslLightness;
            const p = c.hslSaturation * (l > 0.15 && l < 0.9 ? 1 : 0.3) / (1 + 0.15 * i);
            if (p > puntos) { puntos = p; mejor = c; }
        });
        return mejor ? ui.avivar(mejor) : "#b4befe";
    }
    readonly property color elegido: ui.editando ? ui.borrador
                                   : ui.eleccion === "auto" ? ui.tonoFondo : ui.eleccion
    property color acento: elegido
    Behavior on acento { enabled: !ui.editando; ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }

    readonly property real matiz: Math.max(0, acento.hslHue)
    readonly property color texto: Qt.tint("#eceef6", Qt.rgba(acento.r, acento.g, acento.b, 0.12))
    readonly property color tenue: Qt.tint("#9ba0b4", Qt.rgba(acento.r, acento.g, acento.b, 0.3))
    readonly property color reloj: Qt.tint("#e4e7f2", Qt.rgba(acento.r, acento.g, acento.b, 0.55))
    readonly property color sobreAcento: ui.claro(acento) ? Qt.hsla(matiz, 0.35, 0.12, 1) : "white"

    function avivar(valor) {
        const c = Qt.color(valor);
        const s = c.hslSaturation < 0.06 ? c.hslSaturation : Math.max(c.hslSaturation, 0.5);
        return Qt.hsla(Math.max(0, c.hslHue), s, Math.min(0.82, Math.max(0.7, c.hslLightness)), 1);
    }
    function claro(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b > 0.45; }
    function hex(c) { return c.toString().slice(0, 7); }
    function guardarColores() {
        const linea = s => "'" + s.replace(/[^#0-9a-zA-Z]/g, "") + "'";
        escritor.connectSource("printf '%s\\n%s\\n' " + linea(ui.eleccion) + " " + linea(ui.propio)
                               + " > \"$HOME/.config/bloqueo-colores\"");
    }
    function elegir(valor) {
        ui.eleccion = valor;
        ui.guardarColores();
        campo.forceActiveFocus();
    }

    property var now: new Date()
    property var estado: ({ cpu: 0, temp: 0, ram: 0, disco: 0, bat: 0, carga: "", activo: "", equipo: "", nucleo: "" })
    property var clima: null
    property var musica: null       // delegado del reproductor activo
    property bool sinClave: false   // desbloqueo sin contraseña (huella, etc.)

    readonly property string carpeta: Qt.resolvedUrl(".").toString().replace("file://", "")

    function handleMessage(msg) {
        if (!msg) return;
        if (!root.notification) {
            root.notification = msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg;
        }
    }

    function desbloquear() {
        if (authenticator.graceLocked) return;
        campo.forceActiveFocus();
        authenticator.respond(campo.text);
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    // ── Autenticación ────────────────────────────────────────────────
    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return;
            ui.handleMessage("Contraseña incorrecta");
            graceLockTimer.restart();
            notificationRemoveTimer.restart();
            sacudida.start();
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                ui.sinClave = true;
            }
        }
        function onInfoMessageChanged() { ui.handleMessage(authenticator.infoMessage); }
        function onErrorMessageChanged() { ui.handleMessage(authenticator.errorMessage); }
        function onPromptChanged(msg) { ui.handleMessage(authenticator.prompt); }
        function onPromptForSecretChanged(msg) { campo.forceActiveFocus(); }
    }

    Connections {
        target: root
        function onClearPassword() {
            campo.forceActiveFocus();
            campo.text = "";
            campo.text = Qt.binding(() => PasswordSync.password);
        }
    }

    Binding {
        target: PasswordSync
        property: "password"
        value: campo.text
    }

    SessionManagement { id: sessionManagement }
    Connections {
        target: sessionManagement
        function onAboutToSuspend() { root.clearPassword(); }
    }

    KeyboardIndicator.KeyState { id: capsLockState; key: Qt.Key_CapsLock }

    Timer {
        id: notificationRemoveTimer
        interval: 3000
        onTriggered: root.notification = ""
    }
    Timer {
        id: graceLockTimer
        interval: 3000
        onTriggered: {
            root.clearPassword();
            authenticator.startAuthenticating();
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: ui.now = new Date()
    }

    // ── Datos ────────────────────────────────────────────────────────
    P5Support.DataSource {
        id: fuente
        engine: "executable"
        readonly property string cmdEstado: "bash '" + ui.carpeta + "estado.sh'"
        readonly property string cmdClima: "cat \"$HOME/.cache/dashboard/clima.json\""
        connectedSources: [cmdEstado, cmdClima]
        interval: 3000
        onNewData: (fuenteNombre, datos) => {
            const salida = (datos["stdout"] || "").trim();
            if (!salida) return;
            try {
                if (fuenteNombre === cmdEstado) ui.estado = JSON.parse(salida);
                else ui.clima = JSON.parse(salida);
            } catch (e) {}
        }
    }

    // Fondo del escritorio y colores guardados: una sola vez al abrir
    P5Support.DataSource {
        id: lectorFondo
        engine: "executable"
        onNewData: (nombre, datos) => {
            disconnectSource(nombre);
            try {
                const d = JSON.parse((datos["stdout"] || "").trim());
                ui.fondo = d;
                if (d.propio) ui.propio = d.propio;
                if (d.eleccion) ui.eleccion = d.eleccion;
            } catch (e) {}
        }
        Component.onCompleted: connectSource("bash '" + ui.carpeta + "fondo.sh'")
    }
    P5Support.DataSource {
        id: escritor
        engine: "executable"
        onNewData: (nombre) => disconnectSource(nombre)
    }

    Instantiator {
        model: Mpris.MultiplexerModel {}
        delegate: QtObject {
            readonly property string titulo: model.track || ""
            readonly property string artista: model.artist || model.identity || ""
            readonly property string caratula: model.artUrl ? model.artUrl.toString() : ""
            readonly property bool sonando: model.playbackStatus === Mpris.PlaybackStatus.Playing
            readonly property bool puedeAtras: model.canGoPrevious
            readonly property bool puedeAdelante: model.canGoNext
            readonly property var reproductor: model.container
        }
        onObjectAdded: (i, obj) => ui.musica = obj
        onObjectRemoved: (i, obj) => { if (ui.musica === obj) ui.musica = null; }
    }

    Component.onCompleted: {
        authenticator.startAuthenticating();
        campo.forceActiveFocus();
    }

    // ── Fondo ────────────────────────────────────────────────────────
    // El del escritorio (copia reducida de fondo.sh); si aún no está, el del bloqueo
    Image {
        id: fondoEscritorio
        anchors.fill: parent
        source: ui.fondo.imagen ? "file://" + ui.fondo.imagen : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    readonly property Item capaFondo: fondoEscritorio.status === Image.Ready ? fondoEscritorio
                                    : (typeof wallpaper !== "undefined" ? wallpaper : null)
    MultiEffect {
        anchors.fill: parent
        source: ui.capaFondo
        visible: source !== null
        blurEnabled: true
        blur: 0.7
        blurMax: 64
        brightness: -0.14
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.hsla(ui.matiz, 0.35, 0.04, 0.38)
    }

    MouseArea {
        anchors.fill: parent
        onPressed: campo.forceActiveFocus()
    }

    // Aparición suave
    opacity: 0
    NumberAnimation on opacity { to: 1; duration: 500; easing.type: Easing.OutCubic; running: true }

    // ── Panel principal ──────────────────────────────────────────────
    Item {
        id: panel
        width: 1120
        height: 620
        anchors.centerIn: parent
        scale: Math.min(1, (ui.width - 48) / width, (ui.height - 48) / height)

        // Cristal: el fondo desenfocado recortado a la forma del panel
        ShaderEffectSource {
            id: trozo
            anchors.fill: parent
            visible: false
            sourceItem: ui.capaFondo
            // el panel escala desde su centro: se recorta el trozo que ocupa de verdad
            sourceRect: Qt.rect(panel.x + panel.width * (1 - panel.scale) / 2,
                                panel.y + panel.height * (1 - panel.scale) / 2,
                                panel.width * panel.scale, panel.height * panel.scale)
        }
        Rectangle {
            id: mascara
            anchors.fill: parent
            radius: 32
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: trozo.sourceItem !== null
            source: trozo
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.05
            maskEnabled: true
            maskSource: mascara
        }
        Rectangle {
            anchors.fill: parent
            radius: 32
            color: Qt.hsla(ui.matiz, 0.3, 0.07, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            // ── Columna izquierda ───────────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                spacing: 14

                // Tiempo
                Tarjeta {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 158
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ui.clima ? ui.clima.desc.trim() : "Sin datos del tiempo"
                            color: ui.tenue
                            font.pixelSize: 14
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12
                            Text {
                                text: ui.clima ? ui.clima.temp + "°C" : "--"
                                color: ui.texto
                                font.pixelSize: 44
                                font.weight: Font.Bold
                            }
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40; height: 40
                                source: ui.clima ? ui.clima.icono : "weather-none-available"
                                color: ui.texto
                                isMask: true
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ui.clima ? "Sensación de " + ui.clima.sensacion + "°C" : ""
                            color: ui.texto
                            font.pixelSize: 13
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ui.clima && ui.clima.dias && ui.clima.dias.length
                                  ? "Máx " + ui.clima.dias[0].max + "°C • Mín " + ui.clima.dias[0].min + "°C"
                                  : ""
                            color: ui.tenue
                            font.pixelSize: 12
                        }
                    }
                }

                // Ficha del equipo
                Tarjeta {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 206
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12
                        Row {
                            spacing: 10
                            Rectangle {
                                width: 26; height: 26; radius: 8
                                color: ui.acento
                                Text {
                                    anchors.centerIn: parent
                                    text: ">"
                                    color: ui.sobreAcento
                                    font.family: ui.mono
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "cachyfetch.sh"
                                color: ui.texto
                                font.family: ui.mono
                                font.pixelSize: 14
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 18
                            // Cráneo (calavera.png, silueta blanca) teñido con el acento
                            Item {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 100
                                Image {
                                    id: craneo
                                    anchors.fill: parent
                                    source: "calavera.png"
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: parent
                                    source: craneo
                                    colorization: 1
                                    colorizationColor: ui.acento
                                }
                            }
                            Column {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: [
                                        ["OS  ", "CachyOS"],
                                        ["USER", kscreenlocker_userName],
                                        ["WM  ", "KWin"],
                                        ["UP  ", ui.estado.activo],
                                        ["BATT", ui.estado.bat + "%"]
                                    ]
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        textFormat: Text.StyledText
                                        text: "<font color='" + ui.hex(ui.acento) + "'>" + modelData[0]
                                              + "</font>: " + modelData[1]
                                        color: ui.texto
                                        font.family: ui.mono
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                        // Acento: automático (el del fondo), tonos del fondo y uno propio
                        Row {
                            id: puntos
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10
                            Punto {
                                color: ui.tonoFondo
                                glifo: "󰸉"   // imagen: sigue al fondo
                                marcado: ui.eleccion === "auto" && !ui.editando
                                onClicked: ui.elegir("auto")
                            }
                            Repeater {
                                model: ui.tonos
                                Punto {
                                    color: modelData
                                    marcado: ui.eleccion === ui.hex(modelData) && !ui.editando
                                    onClicked: ui.elegir(ui.hex(modelData))
                                }
                            }
                            Punto {
                                color: ui.editando ? ui.borrador : (ui.propio || Qt.rgba(1, 1, 1, 0.1))
                                glifo: ui.propio ? "󰏫" : "+"   // lápiz / más
                                marcado: ui.editando || (ui.propio !== "" && ui.eleccion === ui.propio)
                                onClicked: {
                                    if (ui.propio && ui.eleccion !== ui.propio) ui.elegir(ui.propio);
                                    else editor.abrir();
                                }
                            }
                        }
                    }
                }

                // Música
                Tarjeta {
                    id: tarjetaMusica
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    opacity: ui.editando ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Image {
                        id: fondoMusica
                        anchors.fill: parent
                        source: ui.musica ? ui.musica.caratula : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    Rectangle {
                        id: mascaraMusica
                        anchors.fill: parent
                        radius: tarjetaMusica.radius
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: fondoMusica
                        visible: fondoMusica.status === Image.Ready
                        blurEnabled: true
                        blur: 0.5
                        blurMax: 32
                        brightness: -0.1
                        saturation: -0.3
                        opacity: 0.55
                        maskEnabled: true
                        maskSource: mascaraMusica
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 36
                        spacing: 4
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: ui.musica && ui.musica.titulo ? ui.musica.titulo : "Nada sonando"
                            color: ui.texto
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: ui.musica ? ui.musica.artista : ""
                            color: ui.tenue
                            font.pixelSize: 13
                        }
                        Item { width: 1; height: 10 }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            opacity: ui.musica ? 1 : 0.4
                            Boton {
                                icono: "media-skip-backward"
                                enabled: ui.musica && ui.musica.puedeAtras
                                onClicked: ui.musica.reproductor.Previous()
                            }
                            Boton {
                                ancho: 60
                                relleno: true
                                icono: ui.musica && ui.musica.sonando ? "media-playback-pause" : "media-playback-start"
                                enabled: ui.musica !== null
                                onClicked: ui.musica.reproductor.PlayPause()
                            }
                            Boton {
                                icono: "media-skip-forward"
                                enabled: ui.musica && ui.musica.puedeAdelante
                                onClicked: ui.musica.reproductor.Next()
                            }
                        }
                    }
                }
            }

            // ── Columna central ─────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item { Layout.preferredHeight: 18 }

                // Reloj: hora grande, minutos y AM/PM apilados
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Text {
                        id: horas
                        text: Qt.formatTime(ui.now, "h AP").split(" ")[0]
                        color: ui.reloj
                        font.pixelSize: 150
                        font.weight: Font.Black
                        font.letterSpacing: -6
                        lineHeight: 0.8
                    }
                    Column {
                        anchors.bottom: horas.bottom
                        anchors.bottomMargin: 18
                        spacing: 6
                        Text {
                            text: Qt.formatTime(ui.now, "mm")
                            color: ui.reloj
                            font.pixelSize: 64
                            font.weight: Font.Black
                            font.letterSpacing: -2
                            lineHeight: 0.8
                        }
                        Text {
                            text: ui.now.getHours() < 12 ? "AM" : "PM"
                            color: ui.reloj
                            font.pixelSize: 34
                            font.weight: Font.Bold
                        }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    text: Qt.locale().toString(ui.now, "dddd • d MMM").toUpperCase().replace(".", "")
                    color: ui.texto
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 14 }

                // Carátula en hexágono redondeado
                Item {
                    id: hexa
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 180

                    Image {
                        id: arte
                        anchors.fill: parent
                        source: ui.musica && ui.musica.caratula ? ui.musica.caratula
                              : (kscreenlocker_userImage ? "file://" + kscreenlocker_userImage : "")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    Rectangle {
                        id: sinArte
                        anchors.fill: parent
                        visible: false
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.hsla(ui.matiz, 0.3, 0.3, 1) }
                            GradientStop { position: 1; color: Qt.hsla(ui.matiz, 0.4, 0.5, 1) }
                        }
                    }
                    Shape {
                        id: formaHexa
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        preferredRendererType: Shape.CurveRenderer
                        // El trazo grueso con uniones redondas es lo que redondea las esquinas
                        ShapePath {
                            fillColor: "white"
                            strokeColor: "white"
                            strokeWidth: 34
                            joinStyle: ShapePath.RoundJoin
                            startX: 0.27 * hexa.width; startY: 17
                            PathLine { x: 0.73 * hexa.width; y: 17 }
                            PathLine { x: hexa.width - 17; y: hexa.height / 2 }
                            PathLine { x: 0.73 * hexa.width; y: hexa.height - 17 }
                            PathLine { x: 0.27 * hexa.width; y: hexa.height - 17 }
                            PathLine { x: 17; y: hexa.height / 2 }
                            PathLine { x: 0.27 * hexa.width; y: 17 }
                        }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: arte.status === Image.Ready ? arte : sinArte
                        maskEnabled: true
                        maskSource: formaHexa
                        brightness: -0.04
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 58; height: 58
                        source: ui.musica && ui.musica.sonando ? "media-playback-pause" : "media-playback-start"
                        color: "white"
                        isMask: true
                        opacity: zonaHexa.containsMouse ? 0.95 : 0.8
                    }
                    MouseArea {
                        id: zonaHexa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (ui.musica) ui.musica.reproductor.PlayPause()
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 14 }

                // Contraseña
                Rectangle {
                    id: caja
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 330
                    Layout.preferredHeight: 50
                    radius: 25
                    color: Qt.rgba(1, 1, 1, campo.activeFocus ? 0.08 : 0.05)
                    border.width: 1
                    border.color: authenticator.graceLocked ? Qt.rgba(1, 0.45, 0.5, 0.6)
                                                            : Qt.rgba(1, 1, 1, campo.activeFocus ? 0.14 : 0.06)

                    transform: Translate { id: desplazo }
                    SequentialAnimation {
                        id: sacudida
                        NumberAnimation { target: desplazo; property: "x"; to: -18; duration: 50 }
                        NumberAnimation { target: desplazo; property: "x"; to: 18; duration: 80 }
                        NumberAnimation { target: desplazo; property: "x"; to: -10; duration: 70 }
                        NumberAnimation { target: desplazo; property: "x"; to: 0; duration: 60 }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: ui.tenue
                        font.family: ui.mono
                        font.pixelSize: 15
                    }

                    TextField {
                        id: campo
                        anchors.fill: parent
                        anchors.leftMargin: 44
                        anchors.rightMargin: 52
                        visible: !ui.sinClave
                        focus: true
                        enabled: !authenticator.graceLocked
                        echoMode: TextInput.Password
                        text: PasswordSync.password
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        cursorDelegate: Item {}
                        background: Item {}
                        cursorVisible: visible
                        onAccepted: ui.desbloquear()
                        Keys.onEscapePressed: root.clearPassword()
                    }

                    // Puntos de la contraseña
                    Row {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -4
                        spacing: 7
                        visible: !ui.sinClave
                        Repeater {
                            model: Math.min(campo.length, 18)
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: ui.acento
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: campo.length === 0 && !ui.sinClave
                        text: authenticator.graceLocked ? "Espera un momento…" : "Contraseña"
                        color: ui.tenue
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: ui.sinClave
                        text: "Pulsa para entrar"
                        color: ui.texto
                        font.pixelSize: 14
                    }

                    Boton {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        ancho: 40
                        alto: 38
                        relleno: campo.length > 0 || ui.sinClave
                        icono: "go-next"
                        onClicked: ui.sinClave ? Qt.quit() : ui.desbloquear()
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    Layout.preferredHeight: 18
                    text: {
                        const partes = [];
                        if (capsLockState.locked) partes.push("Bloq Mayús activado");
                        if (root.notification) partes.push(root.notification);
                        return partes.join(" • ");
                    }
                    color: "#f5a3b5"
                    font.pixelSize: 13
                }
            }

            // ── Columna derecha ─────────────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Medidor {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        valor: ui.estado.cpu
                        icono: ""
                        extra: ui.estado.temp + "°C"
                        acento: ui.acento
                    }
                    Medidor {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        valor: ui.estado.ram
                        icono: ""
                        acento: ui.acento
                        resaltado: true
                    }
                    Medidor {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        valor: ui.estado.disco
                        icono: ""
                        acento: ui.acento
                    }
                }

                // Previsión
                Tarjeta {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        Text {
                            text: ui.clima ? "Próximos días · " + ui.clima.lugar : "Próximos días"
                            color: ui.tenue
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Row {
                            id: filaDias
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Repeater {
                                id: dias
                                model: ui.clima && ui.clima.dias ? ui.clima.dias : []
                                Column {
                                    width: filaDias.width / Math.max(1, dias.count)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: index === 0 ? "Hoy"
                                              : Qt.locale().toString(new Date(modelData.fecha + "T12:00:00"), "ddd").replace(".", "")
                                        color: ui.texto
                                        font.pixelSize: 14
                                    }
                                    Kirigami.Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 38; height: 38
                                        source: modelData.icono
                                        color: ui.acento
                                        isMask: true
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.max + "° / " + modelData.min + "°"
                                        color: ui.tenue
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }
                }

                // Batería y equipo
                Tarjeta {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14
                        Text {
                            text: ui.estado.carga === "Charging" ? "󰂄"
                                : ui.estado.bat > 60 ? "󰂁" : ui.estado.bat > 25 ? "󰁾" : "󰁻"
                            color: ui.estado.bat <= 20 && ui.estado.carga !== "Charging" ? "#f5a3b5" : ui.acento
                            font.family: ui.mono
                            font.pixelSize: 34
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: ui.estado.bat + "% · " + (ui.estado.carga === "Charging" ? "cargando"
                                      : ui.estado.carga === "Full" ? "completa" : "con batería")
                                color: ui.texto
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: ui.estado.equipo + " · Linux " + ui.estado.nucleo
                                color: ui.tenue
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                // Sesión
                Tarjeta {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 124
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Text {
                            text: "Sesión de " + kscreenlocker_userName
                            color: ui.tenue
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Accion {
                                texto: "Suspender"
                                icono: "system-suspend"
                                visible: sessionManagement.canSuspend
                                onClicked: sessionManagement.suspend()
                            }
                            Accion {
                                texto: "Hibernar"
                                icono: "system-suspend-hibernate"
                                visible: sessionManagement.canHibernate
                                onClicked: sessionManagement.hibernate()
                            }
                            Accion {
                                texto: "Otro usuario"
                                icono: "system-switch-user"
                                visible: sessionManagement.canSwitchUser
                                onClicked: sessionManagement.switchUser()
                            }
                        }
                    }
                }
            }
        }

        // Editor del color personalizado: ocupa el sitio de la tarjeta de música
        Rectangle {
            id: editor
            property real h: 0
            property real s: 0
            property real l: 0

            function abrir() {
                const base = Qt.color(ui.propio || ui.hex(ui.acento));
                h = Math.max(0, base.hslHue); s = base.hslSaturation; l = base.hslLightness;
                ui.borrador = base;
                hexCampo.text = ui.hex(base);
                ui.editando = true;
                hexCampo.forceActiveFocus();
            }
            function mover(nh, ns, nl) {
                h = nh; s = ns; l = nl;
                ui.borrador = Qt.hsla(h, s, l, 1);
                hexCampo.text = ui.hex(ui.borrador);
            }
            function usar() {
                ui.propio = ui.hex(ui.borrador);
                ui.editando = false;
                ui.elegir(ui.propio);
            }
            function cancelar() {
                ui.editando = false;
                campo.forceActiveFocus();
            }

            x: 18
            y: 18 + tarjetaMusica.y
            width: tarjetaMusica.width
            height: tarjetaMusica.height
            radius: 20
            color: Qt.hsla(ui.matiz, 0.3, 0.1, 0.9)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            visible: opacity > 0
            opacity: ui.editando ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            MouseArea { anchors.fill: parent }   // que el clic no se cuele al fondo

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: ui.borrador
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: Qt.rgba(1, 1, 1, hexCampo.activeFocus ? 0.1 : 0.06)
                        TextInput {
                            id: hexCampo
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            color: ui.texto
                            selectionColor: ui.acento
                            selectedTextColor: ui.sobreAcento
                            font.family: ui.mono
                            font.pixelSize: 15
                            maximumLength: 7
                            validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                            onTextEdited: {
                                const limpio = text.replace("#", "");
                                if (limpio.length !== 6) return;
                                const c = Qt.color("#" + limpio);
                                if (c.hslSaturation > 0) editor.h = c.hslHue;
                                editor.s = c.hslSaturation;
                                editor.l = c.hslLightness;
                                ui.borrador = c;
                            }
                            onAccepted: editor.usar()
                            Keys.onEscapePressed: editor.cancelar()
                        }
                    }
                    Boton {
                        icono: "dialog-ok-apply"
                        relleno: true
                        ancho: 36; alto: 36
                        onClicked: editor.usar()
                    }
                    Boton {
                        icono: "dialog-cancel"
                        ancho: 36; alto: 36
                        onClicked: editor.cancelar()
                    }
                }

                Barra {
                    valor: editor.h
                    onMovido: v => editor.mover(v, editor.s, editor.l)
                    degradado: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0 / 6; color: "#ff0000" }
                        GradientStop { position: 1 / 6; color: "#ffff00" }
                        GradientStop { position: 2 / 6; color: "#00ff00" }
                        GradientStop { position: 3 / 6; color: "#00ffff" }
                        GradientStop { position: 4 / 6; color: "#0000ff" }
                        GradientStop { position: 5 / 6; color: "#ff00ff" }
                        GradientStop { position: 6 / 6; color: "#ff0000" }
                    }
                }
                Barra {
                    valor: editor.s
                    onMovido: v => editor.mover(editor.h, v, editor.l)
                    degradado: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.hsla(editor.h, 0, editor.l, 1) }
                        GradientStop { position: 1; color: Qt.hsla(editor.h, 1, editor.l, 1) }
                    }
                }
                Barra {
                    valor: editor.l
                    onMovido: v => editor.mover(editor.h, editor.s, v)
                    degradado: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "black" }
                        GradientStop { position: 0.5; color: Qt.hsla(editor.h, editor.s, 0.5, 1) }
                        GradientStop { position: 1; color: "white" }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Tono · intensidad · brillo"
                    color: ui.tenue
                    font.pixelSize: 11
                }
            }
        }
    }

    // ── Piezas pequeñas ──────────────────────────────────────────────
    component Punto: Rectangle {
        id: punto
        property string glifo
        property bool marcado: false
        signal clicked()
        width: 20; height: 20
        radius: 10
        scale: zonaPunto.containsMouse ? 1.18 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8; height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: ui.texto
            visible: punto.marcado
        }
        Text {
            anchors.centerIn: parent
            text: punto.glifo
            color: punto.color.a < 0.5 ? ui.texto : ui.claro(punto.color) ? Qt.rgba(0, 0, 0, 0.6) : "white"
            font.family: ui.mono
            font.pixelSize: 12
        }
        MouseArea {
            id: zonaPunto
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: punto.clicked()
        }
    }

    component Barra: Item {
        id: barra
        property real valor: 0
        property alias degradado: pista.gradient
        signal movido(real v)
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        Rectangle {
            id: pista
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 12
            radius: 6
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: barra.valor * (barra.width - width)
            width: 20; height: 20; radius: 10
            color: "transparent"
            border.width: 3
            border.color: "white"
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function mover(px) { barra.movido(Math.max(0, Math.min(1, (px - 10) / (barra.width - 20)))); }
            onPressed: m => mover(m.x)
            onPositionChanged: m => mover(m.x)
        }
    }
    component Boton: Rectangle {
        id: boton
        property string icono
        property int ancho: 40
        property int alto: 40
        property bool relleno: false
        signal clicked()
        width: ancho; height: alto
        radius: height / 2
        color: relleno ? (zona.pressed ? Qt.darker(ui.acento, 1.2) : ui.acento)
                       : Qt.rgba(1, 1, 1, zona.containsMouse ? 0.14 : 0.07)
        opacity: enabled ? 1 : 0.45
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 18; height: 18
            source: boton.icono
            color: boton.relleno ? ui.sobreAcento : ui.texto
            isMask: true
        }
        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.clicked()
        }
    }

    component Accion: Rectangle {
        id: accion
        property string texto
        property string icono
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: 16
        color: Qt.rgba(1, 1, 1, zonaAccion.containsMouse ? 0.12 : 0.06)
        Column {
            anchors.centerIn: parent
            spacing: 5
            Kirigami.Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 20; height: 20
                source: accion.icono
                color: ui.texto
                isMask: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: accion.texto
                color: ui.texto
                font.pixelSize: 11
            }
        }
        MouseArea {
            id: zonaAccion
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: accion.clicked()
        }
    }
}
