#!/usr/bin/env bash
# Lleva el acento al esquema de color de Plasma, para que lo cojan las ventanas,
# las barras de título, el menú de inicio, las notificaciones y las apps de KDE.
#
# El tema de escritorio activo ("cristal") no trae fichero `colors` propio, así
# que sigue al esquema del sistema: con esto los popups de Plasma también se tiñen.
#
# Se parte de `noctalia.colors` como plantilla y se sustituyen sólo los tonos de
# la familia del acento (el lavanda original), de modo que fondos, grises y los
# colores con significado —error, aviso, correcto— se quedan como están.
#
# Lo llama colores.sh. Como hay ocho widgets llamándolo a la vez al iniciar
# sesión, va con `flock` y una marca: si el acento no ha cambiado, sale al
# instante y no se vuelve a aplicar el esquema.
#
# Para deshacerlo: plasma-apply-colorscheme noctalia
set -u

acento=${1:-}
[[ $acento =~ ^#[0-9a-fA-F]{6}$ ]] || exit 0

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dashboard"
mkdir -p "$CACHE"
plantilla="$HOME/.local/share/color-schemes/noctalia.colors"
destino="$HOME/.local/share/color-schemes/AcentoBloqueo.colors"
marca="$CACHE/tema-sistema.marca"
[[ -f $plantilla ]] || exit 0

exec 9>"$CACHE/tema-sistema.lock"
flock -n 9 || exit 0                      # otro widget está en ello
[[ -f $marca && $(<"$marca") == "$acento" && -f $destino ]] && exit 0

PLANTILLA="$plantilla" DESTINO="$destino" ACENTO="$acento" python3 -c '
import colorsys, os, re

def hsl(hx):
    r, g, b = (int(hx[i:i+2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, s, l

def rgb(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "%d,%d,%d" % tuple(round(v * 255) for v in (r, g, b))

h, s, l = hsl(os.environ["ACENTO"])

# 1) Cada tono lavanda de la plantilla se cambia por el equivalente del acento,
#    conservando su claridad para no romper los contrastes que ya funcionaban.
cambios = {
    "189,194,255": rgb(h, s, l),                                     # el acento: foco, hover, activo
    "224,224,255": rgb(h, max(s * 0.8, 0.35), min(0.92, l + 0.10)),  # su versión clara
    "197,196,221": rgb(h, s * 0.55, min(0.90, l + 0.06)),            # enlaces
    "225,224,249": rgb(h, s * 0.45, min(0.93, l + 0.12)),            # visitados
    "38,43,97":    rgb(h, min(s, 0.55), 0.20),                       # texto sobre el acento
    "61,66,121":   rgb(h, min(s, 0.45), 0.30),                       # fondo de la barra de título activa
}

texto = open(os.environ["PLANTILLA"]).read()
for viejo, nuevo in cambios.items():
    texto = texto.replace(viejo, nuevo)

# 2) Los grises (fondos y textos) se tiñen con el tono del acento sin cambiarles
#    la claridad. De aquí sale el fondo de los paneles: el panel lo pinta el SVG
#    de Breeze, que se recolorea solo con el esquema (el tema "cristal" solo
#    sustituye el fondo de los diálogos). También el menú de inicio, las
#    notificaciones, los popups y las ventanas.
#    Solo en los grupos de color; los ColorEffects se quedan como están.
#    Los fondos oscuros, además de tono, suben un poco de claridad: a l=0.08 ni
#    con saturación 1 se nota nada, y el panel va al 45 % sobre el desenfoque.
FONDO, TEXTO, SUBIDA = 0.45, 0.10, 0.045

def tenir(m):
    r, g, b = (int(v) / 255 for v in m.group(2).split(","))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    if ss >= 0.25:          # ya tiene color propio (acento, error, aviso...)
        return m.group(0)
    if ll >= 0.5:
        return m.group(1) + rgb(h, TEXTO, ll)
    if ll < 0.02:           # los negros puros se quedan negros
        return m.group(0)
    return m.group(1) + rgb(h, FONDO, ll + SUBIDA)

salida, grupo = [], ""
for linea in texto.splitlines(True):
    if linea.startswith("["):
        grupo = linea.strip()
    elif grupo.startswith("[Colors:") or grupo == "[WM]":
        linea = re.sub(r"^(\w+=)(\d+,\d+,\d+)$", tenir, linea.rstrip("\n")) + "\n"
    salida.append(linea)
texto = "".join(salida)

texto = texto.replace("ColorScheme=Noctalia", "ColorScheme=AcentoBloqueo")
texto = texto.replace("Name=noctalia", "Name=Acento del bloqueo")
open(os.environ["DESTINO"], "w").write(texto)
' || exit 0

# plasma-apply-colorscheme no hace nada si el esquema ya es el activo, así que
# los cambios de color dentro del MISMO esquema no llegaban nunca a kdeglobals.
# Se borra antes el nombre para que se vea obligado a volcarlo entero; si la
# aplicación falla se repone, que un kdeglobals sin esquema se nota mucho.
anterior=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "" 2>/dev/null
if ! plasma-apply-colorscheme AcentoBloqueo >/dev/null 2>&1; then
    [ -n "$anterior" ] && kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$anterior" 2>/dev/null
    exit 0
fi
printf '%s' "$acento" > "$marca"
exit 0
