#!/usr/bin/env python3
"""
Genera el tema de SDDM (tema/cristal-cachy) a partir de la pantalla de bloqueo
local.bloqueo, para que el inicio de sesión sea exactamente igual.

Copia LockScreenUi.qml y cambia solo lo que el login hace distinto:
autenticación con sddm.login, datos leídos de datos/ (el greeter no puede
entrar en la carpeta personal), usuario/sesión elegibles y las esquinas con
escritorio (Plasma/Hyprland), usuarios y energía.

Ejecutar de nuevo tras cambiar la pantalla de bloqueo y luego instalar.sh.
Si una pieza del bloqueo cambió tanto que no se encuentra, se para y dice cuál.
"""
import pathlib
import shutil
import sys

AQUI = pathlib.Path(__file__).resolve().parent
BLOQUEO = pathlib.Path.home() / ".local/share/plasma/shells/local.bloqueo/contents/lockscreen"
TEMA = AQUI / "tema/cristal-cachy"

s = (BLOQUEO / "LockScreenUi.qml").read_text()


def cambiar(viejo, nuevo, veces=1):
    global s
    n = s.count(viejo)
    if n != veces:
        sys.exit(f"generar.py: esperaba {veces} vez/veces y hay {n}:\n{viejo[:300]}")
    s = s.replace(viejo, nuevo)


def bloque(inicio, fin, nuevo):
    """Sustituye desde la línea que contiene `inicio` hasta la primera que contiene `fin` (incluida)."""
    global s
    a = s.find(inicio)
    if a < 0:
        sys.exit(f"generar.py: no encuentro el inicio: {inicio}")
    a = s.rfind("\n", 0, a) + 1
    b = s.find(fin, a)
    if b < 0:
        sys.exit(f"generar.py: no encuentro el final: {fin}")
    b = s.find("\n", b + len(fin) - 1) + 1
    s = s[:a] + nuevo + s[b:]


# ── Cabecera e imports ────────────────────────────────────────────────
bloque("/*", "*/", '''/*
    Inicio de sesión (tema de SDDM) GENERADO desde la pantalla de bloqueo
    local.bloqueo por ~/.local/share/login-cristal/generar.py. No editar a mano:
    cambiar LockScreenUi.qml o generar.py y volver a generar.

    El greeter corre como el usuario «sddm» y no puede leer la carpeta personal;
    sincronizar.sh deja en datos/ el fondo (fondo.jpg), su paleta (fondo.json),
    los colores elegidos (colores) y el tiempo (clima.json). Si aquí se elige
    otro color se escribe datos/colores y sincronizar.sh lo devuelve al bloqueo.
*/
''')
cambiar("import org.kde.plasma.private.sessions\n", "")
cambiar("import org.kde.plasma.private.keyboardindicator as KeyboardIndicator\n", "")
cambiar("import org.kde.plasma.private.mpris as Mpris\n", "")
cambiar("Item {\n    id: ui\n", "Item {\n    id: ui\n    width: 1920\n    height: 1080\n")

# ── Estado propio del login ───────────────────────────────────────────
bloque("    readonly property string carpeta:", "        authenticator.respond(campo.text);\n    }", '''    readonly property string carpeta: Qt.resolvedUrl(".").toString().replace("file://", "")
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
        return n.includes("hypr") ? "\\uf359" : n.includes("plasma") ? "\\uf373" : "\\u{F0379}";
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
''')

bloque("    // ── Autenticación", "            authenticator.startAuthenticating();\n        }\n    }", '''    // ── Autenticación ────────────────────────────────────────────────
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
''')

# ── Datos: todo sale de datos/ ────────────────────────────────────────
cambiar('''"cat \\"$HOME/.cache/dashboard/clima.json\\""''', '''"cat '" + ui.datos + "clima.json'"''')
bloque("    // Fondo del escritorio y colores guardados", "        Component.onCompleted: connectSource(\"bash '\" + ui.carpeta + \"fondo.sh'\")\n    }", '''    // Paleta del fondo y colores guardados: una sola vez al abrir
    P5Support.DataSource {
        id: lectorFondo
        engine: "executable"
        onNewData: (nombre, datos) => {
            disconnectSource(nombre);
            const lineas = (datos["stdout"] || "").split("\\n");
            let paleta = [];
            try { paleta = JSON.parse(lineas[0]).paleta || []; } catch (e) {}
            ui.fondo = { imagen: ui.datos + "fondo.jpg", paleta: paleta };
            if (/^#[0-9a-fA-F]{6}$/.test(lineas[2] || "")) ui.propio = lineas[2];
            if (lineas[1] === "auto" || /^#[0-9a-fA-F]{6}$/.test(lineas[1] || "")) ui.eleccion = lineas[1];
        }
        Component.onCompleted: connectSource("cd '" + ui.datos + "' && head -1 fondo.json; sed -n '1,2p' colores")
    }''')
cambiar('''+ " > \\"$HOME/.config/bloqueo-colores\\"");''', '''+ " > '" + ui.datos + "colores'");''')

bloque("    Instantiator {\n        model: Mpris", "        authenticator.startAuthenticating();\n        campo.forceActiveFocus();\n    }", '''    Instantiator {
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
            readonly property string corto: model.name.replace(/ \\(.*\\)$/, "")
            readonly property string glifo: ui.glifoSesion(model.name + " " + model.file)
        }
    }

    Component.onCompleted: ui.enfocar()
''')

# ── Fondo de reserva: el de theme.conf ────────────────────────────────
cambiar('''    // El del escritorio (copia reducida de fondo.sh); si aún no está, el del bloqueo''',
        '''    // El del escritorio (copiado por sincronizar.sh); si no está, el de theme.conf
    Image {
        id: fondoReserva
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }''')
cambiar('''        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    readonly property Item capaFondo''', '''        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
    }
    readonly property Item capaFondo''')
cambiar('''(typeof wallpaper !== "undefined" ? wallpaper : null)''',
        '''(fondoReserva.status === Image.Ready ? fondoReserva : null)''')
cambiar('''    MouseArea {
        anchors.fill: parent
        onPressed: campo.forceActiveFocus()
    }''', '''    MouseArea {
        anchors.fill: parent
        onPressed: { ui.menu = ""; ui.enfocar(); }
    }''')
cambiar('''    NumberAnimation on opacity { to: 1; duration: 500; easing.type: Easing.OutCubic; running: true }''',
        '''    NumberAnimation on opacity { to: 1; duration: 500; easing.type: Easing.OutCubic; running: true }
    NumberAnimation { id: salida; target: ui; property: "opacity"; to: 0; duration: 300 }''')
# Con varias pantallas, el panel y las esquinas solo en la principal
cambiar('''        id: panel
''', '''        id: panel
        visible: typeof primaryScreen === "undefined" || primaryScreen
''')

# ── Ficha: usuario elegido y escritorio elegido ───────────────────────
cambiar('''["USER", kscreenlocker_userName],''', '''["USER", ui.nombreUsuario || "?"],''')
cambiar('''["WM  ", "KWin"],''', '''["WM  ", ui.sesion ? ui.sesion.corto : "?"],''')

# ── Hexágono: avatar del usuario; pulsarlo abre la lista ─────────────
cambiar('''                        source: ui.musica && ui.musica.caratula ? ui.musica.caratula
                              : (kscreenlocker_userImage ? "file://" + kscreenlocker_userImage : "")''',
        '''                        source: ui.usuario && ui.usuario.conCara && !ui.manual ? ui.usuario.icono : ""''')
bloque('''                        source: ui.musica && ui.musica.sonando ? "media-playback-pause" : "media-playback-start"''',
       '''                        onClicked: if (ui.musica) ui.musica.reproductor.PlayPause()''', '''                        visible: false
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: zonaHexa.containsMouse
                        text: "\\u{F0019}"   // cambiar de usuario
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
''')

# ── Contraseña ────────────────────────────────────────────────────────
cambiar('''border.color: authenticator.graceLocked ?''', '''border.color: ui.mensaje === "Contraseña incorrecta" ?''')
cambiar('''                        enabled: !authenticator.graceLocked''', '''                        enabled: !ui.entrando''')
cambiar('''                        text: PasswordSync.password
''', "")
cambiar('''                        onAccepted: ui.desbloquear()
                        Keys.onEscapePressed: root.clearPassword()''', '''                        onAccepted: ui.entrar()
                        Keys.onEscapePressed: { text = ""; ui.menu = ""; }''')
cambiar('''text: authenticator.graceLocked ? "Espera un momento…" : "Contraseña"''',
        '''text: ui.entrando ? "Entrando…" : "Contraseña"''')
cambiar('''onClicked: ui.sinClave ? Qt.quit() : ui.desbloquear()''', '''onClicked: ui.entrar()''')
cambiar('''if (capsLockState.locked) partes.push("Bloq Mayús activado");
                        if (root.notification) partes.push(root.notification);''',
        '''if (keyboard.capsLock) partes.push("Bloq Mayús activado");
                        if (ui.mensaje) partes.push(ui.mensaje);''')

# ── Tarjeta de sesión: energía de SDDM y la lista de usuarios ─────────
cambiar('''text: "Sesión de " + kscreenlocker_userName''', '''text: "Sesión de " + ui.nombreReal''')
cambiar('''visible: sessionManagement.canSuspend
                                onClicked: sessionManagement.suspend()''', '''visible: sddm.canSuspend
                                onClicked: sddm.suspend()''')
cambiar('''visible: sessionManagement.canHibernate
                                onClicked: sessionManagement.hibernate()''', '''visible: sddm.canHibernate
                                onClicked: sddm.hibernate()''')
cambiar('''visible: sessionManagement.canSwitchUser
                                onClicked: sessionManagement.switchUser()''', '''onClicked: ui.menu = ui.menu === "usuarios" ? "" : "usuarios"''')

# ── Esquinas ──────────────────────────────────────────────────────────
ESQUINAS = (AQUI / "esquinas.qml").read_text()
cambiar('''    // ── Piezas pequeñas ──────────────────────────────────────────────
''', ESQUINAS + '''
    // ── Piezas pequeñas ──────────────────────────────────────────────
''')

for resto in ("root.", "authenticator", "PasswordSync", "kscreenlocker_", "sessionManagement", "capsLockState", "wallpaper"):
    if resto in s:
        linea = next(l for l in s.splitlines() if resto in l)
        sys.exit(f"generar.py: queda una referencia del bloqueo ({resto}): {linea.strip()}")

TEMA.mkdir(parents=True, exist_ok=True)
(TEMA / "datos").mkdir(exist_ok=True)
(TEMA / "Main.qml").write_text(s)
for f in ("Medidor.qml", "Tarjeta.qml", "estado.sh", "calavera.png"):
    shutil.copy2(BLOQUEO / f, TEMA / f)
print("Tema generado en", TEMA)
