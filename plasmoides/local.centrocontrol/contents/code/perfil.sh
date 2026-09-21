#!/usr/bin/env bash
# Perfil de energía de PowerDevil (el mismo que cambia Meta+B).
#   leer    -> imprime el perfil actual
#   poner X -> lo cambia y vuelve a imprimirlo
#   vigilar -> se queda esperando a que cambie desde fuera, lo imprime y sale
set -u

destino=(--session --dest org.kde.Solid.PowerManagement
         --object-path /org/kde/Solid/PowerManagement/Actions/PowerProfile)
iface=org.kde.Solid.PowerManagement.Actions.PowerProfile

leer() {
    gdbus call "${destino[@]}" --method "$iface".currentProfile 2>/dev/null \
        | sed -n "s/^('\(.*\)',)\$/\1/p"
}

case "${1:-leer}" in
    leer)
        leer
        ;;
    poner)
        gdbus call "${destino[@]}" --method "$iface".setProfile "${2:-balanced}" >/dev/null 2>&1
        ahora=$(leer)
        # El mismo aviso en pantalla que saca PowerDevil con Meta+B. Solo aquí:
        # si el cambio viene de fuera, ese aviso ya lo ha puesto PowerDevil.
        gdbus call --session --dest org.kde.plasmashell \
            --object-path /org/kde/osdService \
            --method org.kde.osdService.powerProfileChanged "$ahora" >/dev/null 2>&1
        printf '%s\n' "$ahora"
        ;;
    vigilar)
        # Si plasmashell muere, su gdbus se queda huérfano: barrer los de antes.
        for pid in $(pgrep -x gdbus); do
            linea=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || continue
            case "$linea" in
                *Actions/PowerProfile*)
                    padre=$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null)
                    [ "$padre" = "1" ] && kill "$pid" 2>/dev/null
                    ;;
            esac
        done

        # Sustitución de proceso (no coproc): así $! es el PID real de gdbus
        # y el kill se lo lleva sin dejar procesos sueltos.
        exec 3< <(stdbuf -oL gdbus monitor "${destino[@]}" 2>/dev/null)
        vigia=$!
        trap 'kill "$vigia" 2>/dev/null' EXIT INT TERM HUP
        while IFS= read -r linea <&3; do
            case "$linea" in *currentProfileChanged*) break ;; esac
        done
        kill "$vigia" 2>/dev/null
        exec 3<&-
        leer
        ;;
esac
