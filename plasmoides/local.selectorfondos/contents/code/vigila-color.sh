#!/usr/bin/env bash
# Espera a que cambie el acento y sale; Paleta.qml recarga la paleta y se vuelve
# a conectar. Dos disparadores:
#   - la señal de desbloqueo (el color se elige en la pantalla de bloqueo, así
#     que al volver al escritorio ya tiene que estar puesto: eso es instantáneo)
#   - un cambio en ~/.config/bloqueo-colores o en el fondo del escritorio, que se
#     miran cada 5 s al vencer el `read` (en modo "auto" el acento sale del fondo)
#
# Las tres trampas del patrón, ya pagadas en escucha.sh: `stdbuf -oL` o gdbus se
# queda con el búfer de bloque; nada de `gdbus | grep`, que deja la tubería
# colgada; y sustitución de proceso en vez de `coproc`, para que $! sea el PID
# real de gdbus y el `kill` se lo lleve de verdad.
set -u

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dashboard"
mkdir -p "$CACHE"
# Nombre del widget, para no pisar el vigía de los otros tres
raiz=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
nombre=$(basename "$raiz")

ajustes="$HOME/.config/bloqueo-colores"
applets="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
firma() { cat "$ajustes" 2>/dev/null; stat -c %Y "$applets" 2>/dev/null; }

# Monitor huérfano de un arranque anterior: cuando plasmashell se va se lleva
# este script, pero el gdbus hijo sobrevive sin nadie que lo mate. Se comprueba
# la línea de comandos antes de matar, porque los PID se reciclan.
pidfile="$CACHE/vigia-color-$nombre.pid"
if [[ -r $pidfile ]]; then
    viejo=$(<"$pidfile")
    if [[ $viejo =~ ^[0-9]+$ ]] && grep -qz 'org.kde.screensaver' "/proc/$viejo/cmdline" 2>/dev/null; then
        kill "$viejo" 2>/dev/null
    fi
fi

exec 3< <(stdbuf -oL gdbus monitor --session \
            --dest org.kde.screensaver \
            --object-path /ScreenSaver 2>/dev/null)
MONITOR=$!
echo "$MONITOR" > "$pidfile"
trap '[ -n "${MONITOR:-}" ] && kill "$MONITOR" 2>/dev/null' EXIT INT TERM HUP

antes=$(firma)
while :; do
    IFS= read -r -t 5 linea <&3; estado=$?
    if (( estado == 0 )); then
        # Bloqueo o desbloqueo: se vuelve a mirar el color (al desbloquear es
        # cuando puede venir uno nuevo, y mirar de más no cuesta nada)
        case "$linea" in *ActiveChanged*) break ;; esac
    elif (( estado > 128 )); then
        [[ $(firma) != "$antes" ]] && break
    else
        # Se fue gdbus (sesión sin salvapantallas, por ejemplo): seguimos solo
        # con el sondeo, para no quedarnos reconectando en bucle cerrado.
        exec 3<&-
        kill "$MONITOR" 2>/dev/null; MONITOR=""
        while sleep 5; do
            [[ $(firma) != "$antes" ]] && break
        done
        break
    fi
done

[ -n "${MONITOR:-}" ] && { exec 3<&-; kill "$MONITOR" 2>/dev/null; wait "$MONITOR" 2>/dev/null; }
rm -f "$pidfile"
echo cambio
exit 0
