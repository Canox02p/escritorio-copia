#!/usr/bin/env bash
# Lista los fondos disponibles (imágenes y videos) y prepara miniaturas y colores en caché.
# Salida separada por tabuladores:
#   actual <ruta del fondo actual>
#   item   <imagen|video> <ruta> <miniatura> <colores> <nombre>
set -u
shopt -s nullglob nocaseglob

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/selector-fondos"
mkdir -p "$CACHE"
exec 9>"$CACHE/.lock"
flock 9

# Imprime "miniatura<TAB>colores" para un archivo, generándolos si no existen.
preparar() {
    local tipo=$1 ruta=$2 clave thumb col
    clave=$(printf '%s|%s' "$ruta" "$(stat -c %Y "$ruta")" | md5sum | cut -c1-32)
    thumb="$CACHE/$clave.jpg"
    col="$CACHE/$clave.col"
    if [[ ! -s $thumb ]]; then
        if [[ $tipo == video ]]; then
            ffmpegthumbnailer -i "$ruta" -o "$thumb" -s 480 -t 15% -q 8 &>/dev/null
        else
            magick "${ruta}[0]" -auto-orient -thumbnail '480x320^' -gravity center -extent 480x320 -quality 85 "$thumb" &>/dev/null
        fi
    fi
    [[ -s $thumb ]] || return 1
    if [[ ! -s $col ]]; then
        # Los 5 colores principales con su frecuencia: "cuenta:#RRGGBB,..."
        magick "$thumb" -resize 64x64 -colors 5 -depth 8 -format %c histogram:info: 2>/dev/null |
            awk '{ n = $1; sub(":", "", n); for (i = 2; i <= NF; i++) if ($i ~ /^#[0-9A-Fa-f]{6}/) { print n ":" substr($i, 1, 7); break } }' |
            paste -sd, > "$col"
    fi
    printf '%s\t%s' "$thumb" "$(<"$col")"
}

emitir() {
    local datos
    datos=$(preparar "$1" "$2") || return
    # La fecha va al final para no mover las columnas que ya lee el widget.
    printf 'item\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$datos" "$3" "$(stat -c %Y "$2")"
}

# Fondo actual (imagen o video)
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var d = desktops()[0];
var plugin = d.wallpaperPlugin;
d.currentConfigGroup = ["Wallpaper", plugin, "General"];
print("actual\t" + (plugin == "org.kde.image" ? d.readConfig("Image") : d.readConfig("LastVideo")));
' 2>/dev/null | sed 's|^actual\tfile://|actual\t|'
echo

# Carpeta propia para fondos: lo que sea que meta ahí, incluso en subcarpetas
while IFS= read -r -d "" f; do
    n=${f##*/}
    case ${f,,} in
        *.mp4|*.webm|*.mkv|*.mov|*.avi|*.m4v)      emitir video  "$f" "${n%.*}" ;;
        *.jpg|*.jpeg|*.png|*.webp|*.avif|*.bmp|*.gif|*.jxl|*.tif|*.tiff)
                                                   emitir imagen "$f" "${n%.*}" ;;
    esac
done < <(find "$HOME/Imágenes/wallpapers" "$HOME/Pictures/wallpapers" -type f -print0 2>/dev/null)

for dir in "$HOME/Vídeos" "$HOME/Videos"; do
    for f in "$dir"/*.{mp4,webm,mkv,mov}; do
        n=${f##*/}; emitir video "$f" "${n%.*}"
    done
done

for dir in "$HOME/Imágenes" "$HOME/Imágenes/Fondos" "$HOME/Pictures/Fondos"; do
    for f in "$dir"/*.{jpg,jpeg,png,webp}; do
        n=${f##*/}; emitir imagen "$f" "${n%.*}"
    done
done

for f in /usr/share/wallpapers/cachyos-wallpapers/*.{jpg,jpeg,png,webp}; do
    n=${f##*/}
    [[ $n == *splash* ]] && continue
    emitir imagen "$f" "${n%.*}"
done

# Paquetes de fondos de KDE: se usa la imagen de mayor resolución de cada uno
for dir in /usr/share/wallpapers/*/contents/images; do
    f=$(ls -1 "$dir" | sort -V | tail -n1)
    [[ -n $f ]] || continue
    nombre=${dir%/contents/images}
    emitir imagen "$dir/$f" "${nombre##*/}"
done
