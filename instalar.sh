#!/usr/bin/env bash
# Instala este escritorio en un equipo con KDE Plasma 6.
#
#   ./instalar.sh            widgets + estilo (no toca tus paneles)
#   ./instalar.sh --todo     además restaura paneles, atajos y ajustes
#
# Antes de tocar nada hace una copia de lo que ya tengas.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TODO=false
[ "${1:-}" = "--todo" ] && TODO=true

PLASMOIDES="$HOME/.local/share/plasma/plasmoids"
ESTILOS="$HOME/.local/share/plasma/desktoptheme"
COPIA="$HOME/respaldo-antes-de-instalar-$(date +%Y%m%d-%H%M)"

echo "==> Comprobando lo que hace falta"
falta=()
for orden in magick ffmpegthumbnailer curl upower python3 qdbus6 kwriteconfig6 plasmawindowed; do
    command -v "$orden" >/dev/null 2>&1 || falta+=("$orden")
done
python3 -c "import numpy" 2>/dev/null || falta+=("python-numpy")
fc-list 2>/dev/null | grep -qi "JetBrainsMono" || falta+=("ttf-jetbrains-mono-nerd")
if [ ${#falta[@]} -gt 0 ]; then
    echo "    FALTAN: ${falta[*]}"
    echo "    En Arch/CachyOS:  sudo pacman -S imagemagick ffmpegthumbnailer curl upower python-numpy ttf-jetbrains-mono-nerd"
    echo
    read -rp "    ¿Sigo de todas formas? [s/N] " r
    [[ ${r,,} == s* ]] || exit 1
else
    echo "    todo presente"
fi

echo "==> Copiando widgets propios"
mkdir -p "$PLASMOIDES"
for w in "$AQUI"/plasmoides/*; do
    n=$(basename "$w")
    [ -d "$PLASMOIDES/$n" ] && { mkdir -p "$COPIA/plasmoides"; cp -r "$PLASMOIDES/$n" "$COPIA/plasmoides/"; }
    rm -rf "${PLASMOIDES:?}/$n"
    cp -r "$w" "$PLASMOIDES/"
    echo "    $n"
done

echo "==> Copiando el estilo de Plasma"
mkdir -p "$ESTILOS"
for e in "$AQUI"/estilo/*; do
    [ -d "$e" ] || continue
    cp -r "$e" "$ESTILOS/"
    echo "    $(basename "$e")"
done

if $TODO; then
    echo "==> Restaurando paneles, atajos y ajustes"
    echo "    (se guarda lo actual en $COPIA)"
    mkdir -p "$COPIA/config" "$HOME/.config"
    for f in "$AQUI"/config/*; do
        n=$(basename "$f")
        case "$n" in atajos-propios.ini) continue ;; esac
        [ -f "$HOME/.config/$n" ] && cp "$HOME/.config/$n" "$COPIA/config/"
        sed "s|__HOME__|$HOME|g" "$f" > "$HOME/.config/$n"
        echo "    $n"
    done
else
    echo "==> Paneles y ajustes: NO tocados (usa --todo si los quieres)"
fi

echo "==> Widgets de terceros que tendrás que instalar a mano:"
sed '/^#/d' "$AQUI/widgets-de-terceros.txt" | sed 's/^/    /'
echo "    (clic derecho en un panel > Añadir widgets > Obtener nuevos widgets)"

echo
echo "Listo. Ahora reinicia el shell:   kquitapp6 plasmashell && kstart plasmashell"
$TODO && echo "Y aplica el estilo:              plasma-apply-desktoptheme cristal"
