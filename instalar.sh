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
for orden in magick ffmpegthumbnailer curl upower python3 qdbus6 kwriteconfig6 plasmawindowed qml6 ffmpeg; do
    command -v "$orden" >/dev/null 2>&1 || falta+=("$orden")
done
python3 -c "import numpy" 2>/dev/null || falta+=("python-numpy")
fc-list 2>/dev/null | grep -qi "JetBrainsMono" || falta+=("ttf-jetbrains-mono-nerd")
if [ ${#falta[@]} -gt 0 ]; then
    echo "    FALTAN: ${falta[*]}"
    echo "    En Arch/CachyOS:  sudo pacman -S imagemagick ffmpegthumbnailer ffmpeg curl upower python-numpy ttf-jetbrains-mono-nerd layer-shell-qt qt6-declarative"
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

echo "==> Pantalla de bloqueo propia"
if [ -d "$AQUI/bloqueo/local.bloqueo" ]; then
    mkdir -p "$HOME/.local/share/plasma/shells" "$HOME/.config/systemd/user/plasma-kwin_wayland.service.d"
    rm -rf "$HOME/.local/share/plasma/shells/local.bloqueo"
    cp -r "$AQUI/bloqueo/local.bloqueo" "$HOME/.local/share/plasma/shells/"
    cp "$AQUI/bloqueo/kwin-bloqueo.conf" "$HOME/.config/systemd/user/plasma-kwin_wayland.service.d/bloqueo.conf"
    echo "    local.bloqueo (se activa al volver a iniciar sesión)"
fi

echo "==> Reinicio forzado"
if [ -f "$AQUI/apagado/forzar-apagado.sh" ]; then
    mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
    cp "$AQUI/apagado/forzar-apagado.sh" "$HOME/.local/bin/"
    cp "$AQUI/apagado/forzar-apagado.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload && systemctl --user enable --now forzar-apagado.service
    echo "    forzar-apagado"
fi

echo "==> Audio Bluetooth automático"
if [ -f "$AQUI/audio/bt-audio-autoswitch" ]; then
    mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
    cp "$AQUI/audio/bt-audio-autoswitch" "$HOME/.local/bin/"
    cp "$AQUI/audio/bt-audio-autoswitch.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload && systemctl --user enable --now bt-audio-autoswitch.service
    echo "    bt-audio-autoswitch"
fi

echo "==> Inicio de sesión (se copia; se activa aparte con sudo)"
if [ -d "$AQUI/login" ]; then
    rm -rf "$HOME/.local/share/login-cristal"
    cp -r "$AQUI/login" "$HOME/.local/share/login-cristal"
    echo "    login-cristal copiado. Para activarlo:  bash ~/.local/share/login-cristal/instalar.sh"
fi

echo "==> Efecto del cubo (fondo difuminado)"
if [ -d "$AQUI/efectos/cube" ]; then
    mkdir -p "$HOME/.local/share/kwin/effects"
    rm -rf "$HOME/.local/share/kwin/effects/cube"
    cp -r "$AQUI/efectos/cube" "$HOME/.local/share/kwin/effects/"
    echo "    cube"
fi

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
        # atajos-propios.ini es una copia de consulta y kwinoutputconfig.json
        # describe las pantallas del equipo de origen: ninguno se aplica.
        case "$n" in atajos-propios.ini|kwinoutputconfig.json) continue ;; esac
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

if [ -f "$AQUI/temas-de-terceros.txt" ]; then
    echo "==> Temas de terceros que tendrás que instalar a mano:"
    sed '/^#/d;/^$/d' "$AQUI/temas-de-terceros.txt" | sed 's/^/    /'
fi

if [ -f "$AQUI/fondos.txt" ]; then
    echo "==> Fondos: las imágenes no viajan aquí. Las rutas que usaba están en"
    echo "    fondos.txt; cópialas a mano si quieres el mismo fondo."
fi

echo
echo "Listo. Ahora reinicia el shell:   kquitapp6 plasmashell && kstart plasmashell"
echo "La pantalla de bloqueo se activa al volver a iniciar sesión."
[ -d "$HOME/.local/share/login-cristal" ] && echo "Login (pide sudo):               bash ~/.local/share/login-cristal/instalar.sh"
$TODO && echo "Y aplica el estilo:              plasma-apply-desktoptheme cristal"
