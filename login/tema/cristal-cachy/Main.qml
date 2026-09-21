/*
    Inicio de sesión (tema de SDDM) GENERADO desde la pantalla de bloqueo
    local.bloqueo por ~/.local/share/login-cristal/generar.py. No editar a mano:
    cambiar LockScreenUi.qml o generar.py y volver a generar.

    El greeter corre como el usuario «sddm» y no puede leer la carpeta personal;
    sincronizar.sh deja en datos/ el fondo (fondo.jpg), su paleta (fondo.json),
    los colores elegidos (colores) y el tiempo (clima.json). Si aquí se elige
    otro color se escribe datos/colores y sincronizar.sh lo devuelve al bloqueo.
*/

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

Item {
    id: ui
    width: 1920
    height: 1080

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
                               + " > '" + ui.datos + "colores'");
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
    readonly property string datos: carpeta + "datos/"

    property string mensaje: ""
    property bool entrando: false
    property string menu: ""          // "sesiones" o "usuarios": menú abierto en una esquina

    // Usuario y escritorio elegidos
    property int indiceUsuario: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property bool manual: false       // «Otro usuario…»: nombre escrito a mano
    property int indiceSesion: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property var usuario: listaUsuarios.count > ui.indiceUsuario ? listaUsuarios.objectAt(ui.indiceUsuario) : null
    readonly property var sesion: listaSesiones.count > ui.indiceSesion ? listaSesiones.objectAt(ui.indiceSesion) : null
    readonly property string nombreUsuario: ui.manual || !ui.usuario ? campoUsuario.text.trim() : ui.usuario.nombre
    readonly property string nombreReal: ui.manual || !ui.usuario ? (ui.nombreUsuario || "?") : ui.usuario.real

    function glifoSesion(texto) {
        const n = texto.toLowerCase();
        return n.includes("hypr") ? "\uf359" : n.includes("plasma") ? "\uf373" : "\u{F0379}";
    }
    // La cara genérica de SDDM no cuenta como avatar
    function esCara(icono) { return !!icono && !icono.toString().endsWith("/faces/.face.icon"); }

    function enfocar() {
        if ((ui.manual || listaUsuarios.count === 0) && campoUsuario.text === "") {
            ui.menu = "usuarios";
            campoUsuario.forceActiveFocus();
        } else {
            campo.forceActiveFocus();
        }
    }
    function entrar() {
        if (ui.entrando) return;
        if (ui.nombreUsuario === "") {
            ui.mensaje = "Elige o escribe un usuario";
            ui.enfocar();
            return;
        }
        ui.entrando = true;
        ui.mensaje = "";
        sddm.login(ui.nombreUsuario, campo.text, ui.indiceSesion);
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    // ── Autenticación ────────────────────────────────────────────────
    Connections {
        target: sddm
        function onLoginSucceeded() { salida.start(); }
        function onLoginFailed() {
            ui.entrando = false;
            ui.mensaje = "Contraseña incorrecta";
            campo.text = "";
            sacudida.start();
            campo.forceActiveFocus();
            borrarMensaje.restart();
        }
        function onInformationMessage(texto) { ui.mensaje = texto; }
    }
    Timer { id: borrarMensaje; interval: 3500; onTriggered: ui.mensaje = "" }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: ui.now = new Date()
    }

    // ── Datos ────────────────────────────────────────────────────────
    P5Support.DataSource {
        id: fuente
        engine: "executable"
        readonly property string cmdEstado: "bash '" + ui.carpeta + "estado.sh'"
        readonly property string cmdClima: "cat '" + ui.datos + "clima.json'"
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

    // Paleta del fondo y colores guardados: una sola vez al abrir
    P5Support.DataSource {
        id: lectorFondo
        engine: "executable"
        onNewData: (nombre, datos) => {
            disconnectSource(nombre);
            const lineas = (datos["stdout"] || "").split("\n");
            let paleta = [];
            try { paleta = JSON.parse(lineas[0]).paleta || []; } catch (e) {}
            ui.fondo = { imagen: ui.datos + "fondo.jpg", paleta: paleta };
            if (/^#[0-9a-fA-F]{6}$/.test(lineas[2] || "")) ui.propio = lineas[2];
            if (lineas[1] === "auto" || /^#[0-9a-fA-F]{6}$/.test(lineas[1] || "")) ui.eleccion = lineas[1];
        }
        Component.onCompleted: connectSource("cd '" + ui.datos + "' && head -1 fondo.json; sed -n '1,2p' colores")
    }    P5Support.DataSource {
        id: escritor
        engine: "executable"
        onNewData: (nombre) => disconnectSource(nombre)
    }

    Instantiator {
        id: listaUsuarios
        model: userModel
        delegate: QtObject {
            readonly property string nombre: model.name
            readonly property string real: model.realName || model.name
            readonly property string icono: model.icon ? model.icon.toString() : ""
            readonly property bool conCara: ui.esCara(icono)
        }
    }
    Instantiator {
        id: listaSesiones
        model: sessionModel
        delegate: QtObject {
            readonly property string nombre: model.name
            readonly property string corto: model.name.replace(/ \(.*\)$/, "")
            readonly property string glifo: ui.glifoSesion(model.name + " " + model.file)
        }
    }

    Component.onCompleted: ui.enfocar()

    // ── Fondo ────────────────────────────────────────────────────────
    // El del escritorio (copiado por sincronizar.sh); si no está, el de theme.conf
    Image {
        id: fondoReserva
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    Image {
        id: fondoEscritorio
        anchors.fill: parent
        source: ui.fondo.imagen ? "file://" + ui.fondo.imagen : ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
    }
    readonly property Item capaFondo: fondoEscritorio.status === Image.Ready ? fondoEscritorio
                                    : (fondoReserva.status === Image.Ready ? fondoReserva : null)
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
        onPressed: { ui.menu = ""; ui.enfocar(); }
    }

    // Aparición suave
    opacity: 0
    NumberAnimation on opacity { to: 1; duration: 500; easing.type: Easing.OutCubic; running: true }
    NumberAnimation { id: salida; target: ui; property: "opacity"; to: 0; duration: 300 }

    // ── Panel principal ──────────────────────────────────────────────
    Item {
        id: panel
        visible: typeof primaryScreen === "undefined" || primaryScreen
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
                                        ["USER", ui.nombreUsuario || "?"],
                                        ["WM  ", ui.sesion ? ui.sesion.corto : "?"],
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
                        source: ui.usuario && ui.usuario.conCara && !ui.manual ? ui.usuario.icono : ""
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
                        visible: false
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: zonaHexa.containsMouse
                        text: "\u{F0019}"   // cambiar de usuario
                        color: "white"
                        font.family: ui.mono
                        font.pixelSize: 58
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: arte.status !== Image.Ready && !zonaHexa.containsMouse
                        text: ui.nombreReal.charAt(0).toUpperCase()
                        color: "white"
                        opacity: 0.9
                        font.pixelSize: 72
                        font.weight: Font.Black
                    }
                    MouseArea {
                        id: zonaHexa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ui.menu = ui.menu === "usuarios" ? "" : "usuarios"
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
                    border.color: ui.mensaje === "Contraseña incorrecta" ? Qt.rgba(1, 0.45, 0.5, 0.6)
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
                        enabled: !ui.entrando
                        echoMode: TextInput.Password
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        cursorDelegate: Item {}
                        background: Item {}
                        cursorVisible: visible
                        onAccepted: ui.entrar()
                        Keys.onEscapePressed: { text = ""; ui.menu = ""; }
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
                        text: ui.entrando ? "Entrando…" : "Contraseña"
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
                        onClicked: ui.entrar()
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    Layout.preferredHeight: 18
                    text: {
                        const partes = [];
                        if (keyboard.capsLock) partes.push("Bloq Mayús activado");
                        if (ui.mensaje) partes.push(ui.mensaje);
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
                            text: "Sesión de " + ui.nombreReal
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
                                visible: sddm.canSuspend
                                onClicked: sddm.suspend()
                            }
                            Accion {
                                texto: "Hibernar"
                                icono: "system-suspend-hibernate"
                                visible: sddm.canHibernate
                                onClicked: sddm.hibernate()
                            }
                            Accion {
                                texto: "Otro usuario"
                                icono: "system-switch-user"
                                onClicked: ui.menu = ui.menu === "usuarios" ? "" : "usuarios"
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

    // ── Esquinas: escritorio, energía, usuarios y teclado ────────────
    // (trozo que generar.py mete en Main.qml; no es un fichero QML suelto)
    Item {
        id: esquinas
        anchors.fill: parent
        anchors.margins: 28
        visible: panel.visible

        // Arriba a la izquierda: escritorio con el que entrar
        Pastilla {
            id: pastillaSesion
            anchors.left: parent.left
            anchors.top: parent.top
            abierta: ui.menu === "sesiones"
            onClicked: ui.menu = abierta ? "" : "sesiones"
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ui.sesion ? ui.sesion.glifo : ""
                color: ui.acento
                font.family: ui.mono
                font.pixelSize: 18
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ui.sesion ? ui.sesion.nombre : "Escritorio"
                color: ui.texto
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0140}"
                color: ui.tenue
                font.family: ui.mono
                font.pixelSize: 16
                rotation: pastillaSesion.abierta ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 150 } }
            }
        }
        Menu {
            anchors.left: pastillaSesion.left
            anchors.top: pastillaSesion.bottom
            anchors.topMargin: 8
            abierto: ui.menu === "sesiones"
            titulo: "Escritorio"
            Repeater {
                model: sessionModel
                Fila {
                    actual: index === ui.indiceSesion
                    glifo: ui.glifoSesion(model.name + " " + model.file)
                    texto: model.name
                    detalle: model.comment || ""
                    onClicked: {
                        ui.indiceSesion = index;
                        ui.menu = "";
                        ui.enfocar();
                    }
                }
            }
        }

        // Arriba a la derecha: reiniciar y apagar
        Pastilla {
            anchors.right: parent.right
            anchors.top: parent.top
            relleno: 4
            BotonEsquina {
                texto: "Reiniciar"
                icono: "system-reboot"
                visible: sddm.canReboot
                onClicked: sddm.reboot()
            }
            BotonEsquina {
                texto: "Apagar"
                icono: "system-shutdown"
                visible: sddm.canPowerOff
                onClicked: sddm.powerOff()
            }
        }

        // Abajo a la izquierda: usuario (la lista se abre hacia arriba)
        Pastilla {
            id: pastillaUsuario
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            abierta: ui.menu === "usuarios"
            onClicked: ui.menu = abierta ? "" : "usuarios"
            Cara {
                anchors.verticalCenter: parent.verticalCenter
                icono: ui.manual || !ui.usuario ? "" : ui.usuario.icono
                inicial: ui.nombreReal.charAt(0).toUpperCase()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ui.nombreReal
                color: ui.texto
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0143}"
                color: ui.tenue
                font.family: ui.mono
                font.pixelSize: 16
                rotation: pastillaUsuario.abierta ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 150 } }
            }
        }
        Menu {
            anchors.left: pastillaUsuario.left
            anchors.bottom: pastillaUsuario.top
            anchors.bottomMargin: 8
            abierto: ui.menu === "usuarios"
            titulo: "Usuarios"
            Repeater {
                model: userModel
                Fila {
                    actual: !ui.manual && index === ui.indiceUsuario
                    texto: model.realName || model.name
                    detalle: model.name
                    usuario: true
                    cara: model.icon ? model.icon.toString() : ""
                    onClicked: {
                        ui.manual = false;
                        ui.indiceUsuario = index;
                        campo.text = "";
                        ui.menu = "";
                        campo.forceActiveFocus();
                    }
                }
            }
            // Otro usuario: se escribe el nombre aquí mismo
            Fila {
                actual: ui.manual
                glifo: "\u{F0014}"
                texto: ui.manual ? "" : "Otro usuario…"
                onClicked: {
                    ui.manual = true;
                    campo.text = "";
                    campoUsuario.forceActiveFocus();
                }
                TextInput {
                    id: campoUsuario
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 58
                    anchors.rightMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ui.manual
                    color: ui.texto
                    font.pixelSize: 14
                    selectionColor: ui.acento
                    selectedTextColor: ui.sobreAcento
                    onAccepted: { ui.menu = ""; campo.forceActiveFocus(); }
                    Keys.onEscapePressed: { ui.manual = false; text = ""; ui.menu = ""; campo.forceActiveFocus(); }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.text === ""
                        text: "Escribe el usuario"
                        color: ui.tenue
                        font.pixelSize: 14
                    }
                }
            }
        }

        // Abajo a la derecha: distribución del teclado y equipo
        Pastilla {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            interactiva: keyboard.layouts.length > 1
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F030C}"
                color: ui.acento
                font.family: ui.mono
                font.pixelSize: 17
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const l = keyboard.layouts[keyboard.currentLayout];
                    return (l ? l.shortName.toUpperCase() : "US") + " · " + sddm.hostName;
                }
                color: ui.texto
                font.pixelSize: 13
            }
        }
    }

    component Pastilla: Rectangle {
        id: pastilla
        default property alias contenido: filaPastilla.data
        property bool abierta: false
        property bool interactiva: true
        property int relleno: 18
        signal clicked()
        width: filaPastilla.implicitWidth + 2 * relleno
        height: 46
        radius: 23
        color: Qt.hsla(ui.matiz, 0.3, 0.08, abierta || (interactiva && zonaPastilla.containsMouse) ? 0.75 : 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, abierta ? 0.16 : 0.08)
        MouseArea {
            id: zonaPastilla
            anchors.fill: parent
            enabled: pastilla.interactiva
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pastilla.clicked()
        }
        Row {
            id: filaPastilla
            anchors.centerIn: parent
            spacing: 10
        }
    }

    component BotonEsquina: Rectangle {
        id: botonEsquina
        property string texto
        property string icono
        signal clicked()
        width: filaBoton.implicitWidth + 28
        height: 38
        radius: 19
        color: Qt.rgba(1, 1, 1, zonaBoton.containsMouse ? 0.12 : 0)
        Row {
            id: filaBoton
            anchors.centerIn: parent
            spacing: 8
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                source: botonEsquina.icono
                color: zonaBoton.containsMouse ? ui.acento : ui.texto
                isMask: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: botonEsquina.texto
                color: ui.texto
                font.pixelSize: 13
            }
        }
        MouseArea {
            id: zonaBoton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: botonEsquina.clicked()
        }
    }

    component Menu: Rectangle {
        id: menu
        default property alias contenido: columnaMenu.data
        property bool abierto: false
        property string titulo
        width: 300
        height: columnaMenu.implicitHeight + 20
        radius: 20
        color: Qt.hsla(ui.matiz, 0.3, 0.09, 0.94)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        visible: opacity > 0
        opacity: abierto ? 1 : 0
        scale: abierto ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }   // que el clic no cierre el menú
        Column {
            id: columnaMenu
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 4
            Text {
                leftPadding: 8
                bottomPadding: 2
                text: menu.titulo
                color: ui.tenue
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    component Fila: Rectangle {
        id: fila
        property bool actual: false
        property string glifo
        property string texto
        property string detalle
        property bool usuario: false   // fila de usuario: avatar (o inicial) en vez del glifo
        property string cara
        signal clicked()
        width: parent ? parent.width : 280
        height: 50
        radius: 14
        color: actual ? Qt.rgba(ui.acento.r, ui.acento.g, ui.acento.b, 0.22)
                      : Qt.rgba(1, 1, 1, zonaFila.containsMouse ? 0.08 : 0)
        MouseArea {
            id: zonaFila
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fila.clicked()
        }
        Item {
            id: huecoIcono
            x: 12
            width: 34; height: 34
            anchors.verticalCenter: parent.verticalCenter
            Cara {
                anchors.centerIn: parent
                visible: fila.usuario
                icono: fila.cara
                inicial: fila.texto.charAt(0).toUpperCase()
                tamano: 34
            }
            Text {
                anchors.centerIn: parent
                visible: !fila.usuario
                text: fila.glifo
                color: fila.actual ? ui.acento : ui.texto
                font.family: ui.mono
                font.pixelSize: 20
            }
        }
        Column {
            anchors.left: huecoIcono.right
            anchors.leftMargin: 12
            anchors.right: marca.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: fila.texto
                color: ui.texto
                font.pixelSize: 14
                font.weight: fila.actual ? Font.DemiBold : Font.Normal
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: fila.detalle !== "" && fila.detalle !== fila.texto
                text: fila.detalle
                color: ui.tenue
                font.family: ui.mono
                font.pixelSize: 11
            }
        }
        Text {
            id: marca
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: fila.actual ? "\u{F012C}" : ""
            color: ui.acento
            font.family: ui.mono
            font.pixelSize: 16
        }
    }

    // Avatar redondo; sin foto, la inicial sobre el acento
    component Cara: Rectangle {
        id: caraRedonda
        property string icono
        property string inicial
        property int tamano: 28
        width: tamano; height: tamano
        radius: tamano / 2
        color: Qt.hsla(ui.matiz, 0.4, 0.42, 1)
        Image {
            id: foto
            anchors.fill: parent
            source: ui.esCara(caraRedonda.icono) ? caraRedonda.icono : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        Rectangle { id: circuloFoto; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect {
            anchors.fill: parent
            source: foto
            visible: foto.status === Image.Ready
            maskEnabled: true
            maskSource: circuloFoto
        }
        Text {
            anchors.centerIn: parent
            visible: foto.status !== Image.Ready
            text: caraRedonda.inicial
            color: "white"
            font.pixelSize: caraRedonda.tamano * 0.45
            font.weight: Font.Bold
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
