#!/usr/bin/env bash
# Escribe ~/.cache/dashboard/paleta.json con la paleta del fondo actual.
# Se pondera por saturación² para que un detalle vivo gane sobre un fondo casi gris.
set -u
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dashboard"
mkdir -p "$CACHE"

ruta=${1:-}
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

magick "$marco" -resize 96x96 -colors 24 -depth 8 -format %c histogram:info: |
awk '{ n=$1; sub(":","",n); for(i=2;i<=NF;i++) if($i ~ /^#[0-9A-Fa-f]{6}/){ print n, substr($i,2,6); break } }' |
python3 -c '
import sys, colorsys, json, os
mejor=None; top=-1
for linea in sys.stdin:
    n,hx = linea.split()
    r,g,b = (int(hx[i:i+2],16)/255 for i in (0,2,4))
    h,s,v = colorsys.rgb_to_hsv(r,g,b)
    p = int(n) * (s**2) * (v if v<0.9 else 0.5)
    if p > top: top, mejor = p, (h,s,v)
if mejor is None: mejor=(0.08,0.6,0.8)
h,s,v = mejor
s = max(s,0.55); v = max(v,0.72)
def hx(h,s,v):
    r,g,b = colorsys.hsv_to_rgb(h,s,v)
    return "#%02x%02x%02x" % (round(r*255),round(g*255),round(b*255))
def hxa(a,h,s_,v):
    r,g,b = colorsys.hsv_to_rgb(h,s_,v)
    return "#%02x%02x%02x%02x" % (round(a*255),round(r*255),round(g*255),round(b*255))
# Blanco y negro: del fondo solo se hereda un tinte mínimo para que no quede plano.
t = 0.05
paleta = {
  "acento":  hx(h,t,0.95),
  "suave":   hx(h,t,0.82),
  "fondo":   hxa(0.40,h,t*2,0.03),
  "tarjeta": hxa(0.10,h,0.0,1.0),
  "hueco":   hxa(0.12,h,0.0,1.0),
  "borde":   hxa(0.15,h,0.0,1.0),
  "texto":   hx(h,t*0.5,0.96),
  "tenue":   hx(h,t,0.62),
}
ruta = os.path.expanduser(os.environ.get("XDG_CACHE_HOME","~/.cache") + "/dashboard/paleta.json")
open(ruta,"w").write(json.dumps(paleta, indent=1))
print(json.dumps(paleta, indent=1))
'
