#!/usr/bin/env bash
# Fondo actual del escritorio para la pantalla de bloqueo, en una línea de JSON:
#   {"imagen":"/ruta/a/copia.jpg","paleta":["#rrggbb", ...],"eleccion":"auto","propio":"#rrggbb"}
# La copia se reduce a 1920 px (carga al instante) y, si el fondo es un vídeo,
# es un fotograma suyo. Todo se guarda en caché por ruta + fecha del original.
set -u
cache="$HOME/.cache/bloqueo"
mkdir -p "$cache"
applets="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

# Primer escritorio con fondo: el fichero que muestra su complemento activo
original=$(awk '
    match($0, /^\[Containments\]\[[0-9]+\]/) { id = substr($0, 1, RLENGTH) }
    $0 == id { seccion = "raiz"; next }
    /^\[/ { seccion = $0; next }
    seccion == "raiz" && /^wallpaperplugin=/ { sub(/^[^=]*=/, ""); plugin[id] = $0; orden[++n] = id }
    /^(Image|LastVideo)=/ { v = $0; sub(/^[^=]*=/, "", v); fichero[seccion] = v }
    END {
        for (i = 1; i <= n; i++) {
            f = fichero[orden[i] "[Wallpaper][" plugin[orden[i]] "][General]"]
            if (f != "") { print f; exit }
        }
    }' "$applets")
original=${original#file://}
# Fondos que son paquetes (carpeta con contents/images): la imagen más grande
[[ -d $original ]] && original=$(ls -S "$original"/contents/images/* 2>/dev/null | head -1)
[[ -f $original ]] || original=$(kreadconfig6 --file kscreenlockerrc \
    --group Greeter --group Wallpaper --group org.kde.image --group General --key Image)
original=${original#file://}
[[ -f $original ]] || { echo '{}'; exit 0; }

# Color elegido en la propia pantalla de bloqueo (lo escribe LockScreenUi.qml)
ajustes="$HOME/.config/bloqueo-colores"
eleccion=$(sed -n 1p "$ajustes" 2>/dev/null); propio=$(sed -n 2p "$ajustes" 2>/dev/null)
# Solo valores válidos: el fichero puede venir del inicio de sesión (grupo sddm)
[[ $eleccion == auto || $eleccion =~ ^#[0-9a-fA-F]{6}$ ]] || eleccion=auto
[[ $propio =~ ^#[0-9a-fA-F]{6}$ ]] || propio=
responder() { sed "s/}\$/,\"eleccion\":\"${eleccion:-auto}\",\"propio\":\"${propio}\"}/" "$1"; exit 0; }

clave=$(printf '%s %s' "$original" "$(stat -c %Y "$original")" | md5sum | cut -c1-12)
copia="$cache/fondo-$clave.jpg"
datos="$cache/fondo-$clave.json"
[[ -s $datos ]] && responder "$datos"

rm -f "$cache"/fondo-*
case "${original,,}" in
    *.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v)
        ffmpegthumbnailer -i "$original" -o "$copia" -s 1920 -t 20% -q 9 2>/dev/null ;;
    *)
        magick "$original[0]" -resize '1920x1920>' -quality 90 "$copia" 2>/dev/null ;;
esac
[[ -s $copia ]] || { echo '{}'; exit 0; }

# Doce tonos dominantes, del más abundante al menos (QML elige y aviva)
paleta=$(magick "$copia" -resize 96x96 -colors 12 -format %c histogram:info:- 2>/dev/null \
    | sort -rn | grep -o '#[0-9A-Fa-f]\{6\}' | sed 's/.*/"&"/' | paste -sd,)

printf '{"imagen":"%s","paleta":[%s]}\n' "$copia" "$paleta" > "$datos"
responder "$datos"
