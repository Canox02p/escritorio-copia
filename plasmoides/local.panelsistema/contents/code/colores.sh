#!/usr/bin/env bash
# Paleta del escritorio, derivada del MISMO acento que la pantalla de bloqueo.
#
# La fuente de la verdad es `fondo.sh` del paquete local.bloqueo: imprime la
# paleta del fondo actual y la elección guardada en ~/.config/bloqueo-colores
# (línea 1 "auto" o #rrggbb, línea 2 el color propio). Aquí se repite el mismo
# cálculo que hace LockScreenUi.qml (HSL, `avivar`, `tonoFondo`) para que el
# escritorio salga exactamente del color que se ve al desbloquear.
#
# Escribe ~/.cache/dashboard/paleta.json y lo imprime; Paleta.qml lo parsea.
set -u
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dashboard"
mkdir -p "$CACHE"

ruta=${1:-}
fondo_sh="$HOME/.local/share/plasma/shells/local.bloqueo/contents/lockscreen/fondo.sh"
datos=""
[[ -z $ruta && -f $fondo_sh ]] && datos=$(bash "$fondo_sh" 2>/dev/null)

# ── Respaldo: sin la pantalla de bloqueo instalada (o con un fondo dado a mano),
#    se saca la paleta aquí mismo, con el mismo formato que fondo.sh ──────────
if [[ $datos != *'"paleta"'* ]]; then
    if [[ -z $ruta ]]; then
        ruta=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var d = desktops()[0];
var plugin = d.wallpaperPlugin;
d.currentConfigGroup = ["Wallpaper", plugin, "General"];
print((plugin == "org.kde.image" ? d.readConfig("Image") : d.readConfig("LastVideo")));
' 2>/dev/null | sed 's|^file://||')
    fi
    [[ -n $ruta && -e $ruta ]] || exit 1

    marco="$CACHE/marco.jpg"
    case ${ruta,,} in
        *.mp4|*.webm|*.mkv|*.mov) ffmpegthumbnailer -i "$ruta" -o "$marco" -s 480 -t 35% -q 8 &>/dev/null ;;
        *) magick "${ruta}[0]" -resize 480x480 "$marco" &>/dev/null ;;
    esac
    [[ -s $marco ]] || exit 1

    paleta=$(magick "$marco" -resize 96x96 -colors 12 -format %c histogram:info:- 2>/dev/null \
        | sort -rn | grep -o '#[0-9A-Fa-f]\{6\}' | sed 's/.*/"&"/' | paste -sd,)

    ajustes="$HOME/.config/bloqueo-colores"
    eleccion=$(sed -n 1p "$ajustes" 2>/dev/null); propio=$(sed -n 2p "$ajustes" 2>/dev/null)
    [[ $eleccion == auto || $eleccion =~ ^#[0-9a-fA-F]{6}$ ]] || eleccion=auto
    [[ $propio =~ ^#[0-9a-fA-F]{6}$ ]] || propio=
    datos=$(printf '{"paleta":[%s],"eleccion":"%s","propio":"%s"}' "$paleta" "$eleccion" "$propio")
fi

salida=$(DATOS="$datos" CACHE="$CACHE" python3 -c '
import colorsys, json, os

d = json.loads(os.environ["DATOS"] or "{}")

def hsl(hx):
    r, g, b = (int(hx[i:i+2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, s, l

def rgb(h, s, l):
    return colorsys.hls_to_rgb(h, l, s)

def hx(h, s, l, a=None):
    r, g, b = rgb(h, s, l)
    c = "#%02x%02x%02x" % tuple(round(v * 255) for v in (r, g, b))
    return c if a is None else "#%02x%s" % (round(a * 255), c[1:])

# ── El acento, igual que en LockScreenUi.qml ────────────────────────────────
def avivar(h, s, l):
    # Un gris se deja gris; lo demás se sube a color vivo y claro.
    return h, (s if s < 0.06 else max(s, 0.5)), min(0.82, max(0.7, l))

def tono_fondo(paleta):
    # El tono más vivo del fondo, primando los que más abundan (van ordenados).
    mejor, top = None, -1
    for i, c in enumerate(paleta):
        try: h, s, l = hsl(c)
        except Exception: continue
        p = s * (1 if 0.15 < l < 0.9 else 0.3) / (1 + 0.15 * i)
        if p > top: top, mejor = p, (h, s, l)
    return avivar(*mejor) if mejor else hsl("#b4befe")

eleccion = d.get("eleccion") or "auto"
propio   = d.get("propio") or ""
if eleccion == "auto":
    h, s, l = tono_fondo(d.get("paleta") or [])
else:
    h, s, l = hsl(eleccion)      # color elegido a mano: tal cual, sin avivar

def tinte(base, a):
    # Qt.tint(base, acento con alfa a): mezcla lineal hacia el acento.
    br, bg, bb = (int(base[i:i+2], 16) / 255 for i in (1, 3, 5))
    ar, ag, ab = rgb(h, s, l)
    m = [b * (1 - a) + c * a for b, c in ((br, ar), (bg, ag), (bb, ab))]
    return "#%02x%02x%02x" % tuple(round(v * 255) for v in m)

# Cristal esmerilado teñido. El bloqueo se permite velos flojos (0.12 el texto)
# porque allí hay mucha superficie a todo color; aquí casi todo se pinta con
# `texto`, así que con un 12 % el escritorio seguía viéndose blanco. Se sube el
# tinte de toda la paleta para que el color se note de verdad.
sc = min(s, 0.55)
paleta = {
  "acento":  hx(h, s, l),
  "suave":   hx(h, s * 0.75, max(0.0, l - 0.10)),
  "fondo":   hx(h, min(s, 0.35), 0.05, 0.42),
  "tarjeta": hx(h, sc * 0.8, 0.90, 0.11),
  "hueco":   hx(h, sc * 0.9, 0.91, 0.13),
  "borde":   hx(h, sc,       0.92, 0.20),
  "texto":   tinte("#eceef6", 0.22),
  "tenue":   tinte("#9ba0b4", 0.50),
  "reloj":   tinte("#e4e7f2", 0.55),   # los relojes grandes, como en el bloqueo
}
salida = json.dumps(paleta, indent=1)
open(os.path.join(os.environ["CACHE"], "paleta.json"), "w").write(salida)
print(salida)
')
[[ -n $salida ]] || exit 1
printf '%s\n' "$salida"

# El mismo acento al esquema de color de Plasma: ventanas, barras de título,
# menú de inicio, notificaciones y apps de KDE. Va en segundo plano y con la
# salida cerrada para no hacer esperar a quien nos llamó.
acento=$(printf '%s' "$salida" | sed -n 's/.*"acento": *"\(#[0-9a-fA-F]\{6\}\)".*/\1/p')
aqui=$(dirname "$(readlink -f "$0")")
if [[ -n $acento && -f $aqui/tema-sistema.sh ]]; then
    setsid bash "$aqui/tema-sistema.sh" "$acento" >/dev/null 2>&1 &
fi
exit 0
