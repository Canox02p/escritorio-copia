#!/usr/bin/env bash
# Vuelca el escritorio actual en esta carpeta. Ejecútalo después de cualquier
# cambio (mover un panel, tocar un widget, etc.) y luego sube los cambios a git.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"

PLASMOIDES="$HOME/.local/share/plasma/plasmoids"
ESTILOS="$HOME/.local/share/plasma/desktoptheme"

echo "==> Widgets propios"
rm -rf "$AQUI/plasmoides"; mkdir -p "$AQUI/plasmoides"
for w in "$PLASMOIDES"/local.*; do
    [ -d "$w" ] || continue
    cp -r "$w" "$AQUI/plasmoides/"
    echo "    $(basename "$w")"
done

echo "==> Estilo de Plasma propio"
rm -rf "$AQUI/estilo"; mkdir -p "$AQUI/estilo"
[ -d "$ESTILOS/cristal" ] && cp -r "$ESTILOS/cristal" "$AQUI/estilo/" && echo "    cristal"

echo "==> Configuración"
mkdir -p "$AQUI/config"
for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc plasmarc kwinrulesrc \
         kglobalshortcutsrc kdeglobals kwinrc; do
    [ -f "$HOME/.config/$f" ] && cp "$HOME/.config/$f" "$AQUI/config/" && echo "    $f"
done

echo "==> Quitando datos privados (se sube a git)"
# Los nombres de los archivos del escritorio no se guardan, y la carpeta
# personal se cambia por __HOME__ (instalar.sh la vuelve a poner).
for f in "$AQUI"/config/*; do
    sed -i -e '/^\(positions\|changedPositions\|itemsOnDisabledScreens\)=/d' \
           -e "s|$HOME|__HOME__|g" "$f"
done

echo "==> Atajos propios (por si hay que reponerlos a mano)"
if grep -q '^\[tablerodash\]' "$HOME/.config/kglobalshortcutsrc" 2>/dev/null; then
    sed -n '/^\[tablerodash\]/,/^$/p' "$HOME/.config/kglobalshortcutsrc" > "$AQUI/config/atajos-propios.ini"
    echo "    tablerodash (Meta+V)"
fi

echo "==> Lista de widgets de terceros que hacen falta"
{
    echo "# Widgets de terceros instalados (se bajan de 'Obtener nuevos widgets')"
    for w in "$PLASMOIDES"/*; do
        n=$(basename "$w")
        case "$n" in local.*) continue ;; esac
        echo "$n"
    done
} > "$AQUI/widgets-de-terceros.txt"

echo
echo "Listo. Respaldo actualizado en $AQUI"
date '+Última actualización: %d/%m/%Y %H:%M' > "$AQUI/ULTIMO-RESPALDO.txt"
