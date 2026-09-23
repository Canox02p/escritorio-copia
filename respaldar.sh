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
# La caché de Python se regenera sola y ensucia el historial
find "$AQUI/plasmoides" -name __pycache__ -type d -prune -exec rm -rf {} +

echo "==> Estilo de Plasma propio"
rm -rf "$AQUI/estilo"; mkdir -p "$AQUI/estilo"
[ -d "$ESTILOS/cristal" ] && cp -r "$ESTILOS/cristal" "$AQUI/estilo/" && echo "    cristal"

echo "==> Pantalla de bloqueo propia"
rm -rf "$AQUI/bloqueo"; mkdir -p "$AQUI/bloqueo"
if [ -d "$HOME/.local/share/plasma/shells/local.bloqueo" ]; then
    cp -r "$HOME/.local/share/plasma/shells/local.bloqueo" "$AQUI/bloqueo/"
    cp "$HOME/.config/systemd/user/plasma-kwin_wayland.service.d/bloqueo.conf" "$AQUI/bloqueo/kwin-bloqueo.conf"
    echo "    local.bloqueo"
fi

echo "==> Inicio de sesión (tema SDDM cristal-cachy)"
rm -rf "$AQUI/login"
if [ -d "$HOME/.local/share/login-cristal" ]; then
    cp -r "$HOME/.local/share/login-cristal" "$AQUI/login"
    rm -f "$AQUI/login/tema/cristal-cachy/datos/"*
    echo "    login-cristal (instalar con login/instalar.sh tras copiarlo a ~/.local/share/login-cristal)"
fi

echo "==> Reinicio forzado"
rm -rf "$AQUI/apagado"; mkdir -p "$AQUI/apagado"
if [ -f "$HOME/.local/bin/forzar-apagado.sh" ]; then
    cp "$HOME/.local/bin/forzar-apagado.sh" "$HOME/.config/systemd/user/forzar-apagado.service" "$AQUI/apagado/"
    echo "    forzar-apagado"
fi

echo "==> Audio Bluetooth automático"
rm -rf "$AQUI/audio"; mkdir -p "$AQUI/audio"
if [ -f "$HOME/.local/bin/bt-audio-autoswitch" ]; then
    cp "$HOME/.local/bin/bt-audio-autoswitch" "$HOME/.config/systemd/user/bt-audio-autoswitch.service" "$AQUI/audio/"
    echo "    bt-audio-autoswitch"
fi

echo "==> Efecto del cubo (fondo difuminado)"
rm -rf "$AQUI/efectos"; mkdir -p "$AQUI/efectos"
if [ -d "$HOME/.local/share/kwin/effects/cube" ]; then
    cp -r "$HOME/.local/share/kwin/effects/cube" "$AQUI/efectos/" && echo "    cube"
fi

echo "==> Configuración"
mkdir -p "$AQUI/config"
# kwinoutputconfig.json es de las pantallas de ESTE equipo: se guarda como
# referencia, pero instalar.sh no lo aplica.
for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc plasmarc kwinrulesrc \
         kglobalshortcutsrc kdeglobals kwinrc kscreenlockerrc bloqueo-colores \
         kcminputrc ksmserverrc plasmanotifyrc powermanagementprofilesrc \
         gtkrc gtkrc-2.0 kwinoutputconfig.json; do
    [ -f "$HOME/.config/$f" ] && cp "$HOME/.config/$f" "$AQUI/config/" && echo "    $f"
done

echo "==> Quitando datos privados (se sube a git)"
# Los nombres de los archivos del escritorio no se guardan, y la carpeta
# personal se cambia por __HOME__ (instalar.sh la vuelve a poner).
# Los identificadores EDID señalan a estas pantallas concretas y no hacen
# falta para nada: la disposición se guarda sólo de consulta.
for f in "$AQUI"/config/*; do
    sed -i -e '/^\(positions\|changedPositions\|itemsOnDisabledScreens\)=/d' \
           -e '/"edid\(Hash\|Identifier\)":/d' \
           -e "s|$HOME|__HOME__|g" "$f"
done

echo "==> Quitando metadatos de las imágenes (fechas, GPS, cámara...)"
find "$AQUI" -path "$AQUI/.git" -prune -o -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print |
while read -r img; do
    magick "$img" -strip -define png:exclude-chunks=date,time "$img" && echo "    ${img#$AQUI/}"
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

echo "==> Lista de temas de terceros que hacen falta"
{
    echo "# Temas instalados a mano (no se suben: ocupan mucho y se descargan)"
    echo "# Se bajan de Preferencias del sistema > Apariencia > Obtener nuevos…"
    for d in "$HOME/.local/share/icons" "$HOME/.local/share/plasma/desktoptheme" \
             "$HOME/.local/share/plasma/look-and-feel" "$HOME/.local/share/aurorae/themes" \
             "$HOME/.local/share/color-schemes" "$HOME/.local/share/wallpapers"; do
        [ -d "$d" ] || continue
        echo
        echo "## ${d#$HOME/.local/share/}"
        for t in "$d"/*; do
            n=$(basename "$t")
            # 'cristal' es nuestro y hicolor lo generan los propios programas
            case "$n" in cristal|hicolor) continue ;; esac
            echo "$n"
        done
    done
} > "$AQUI/temas-de-terceros.txt"
echo "    temas-de-terceros.txt"

echo "==> Fondos en uso (las imágenes no se suben)"
{
    echo "# Fondos que usa este escritorio. Las imágenes no van en el repositorio:"
    echo "# son descargas, pesan y no son creación propia. Cópialas aparte."
    grep -hE "^Image=" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null |
        sed 's|^Image=file://||' | sort -u
    for d in "$HOME/Imágenes/wallpapers" "$HOME/Imágenes/fondos"; do
        [ -d "$d" ] || continue
        echo
        echo "## $d  ($(du -sh "$d" | cut -f1))"
        ls "$d"
    done
} > "$AQUI/fondos.txt"
sed -i "s|$HOME|__HOME__|g" "$AQUI/fondos.txt"   # aquí también sobra la ruta personal
echo "    fondos.txt"

echo
echo "Listo. Respaldo actualizado en $AQUI"
date '+Última actualización: %d/%m/%Y %H:%M' > "$AQUI/ULTIMO-RESPALDO.txt"
