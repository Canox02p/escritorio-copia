#!/bin/bash
# Reinicio/apagado "a lo Windows": KDE pregunta una sola vez (la cuenta atrás de
# 30 s del diálogo) y, si tras confirmar alguna ventana frena el cierre, a los
# ESPERA segundos se fuerza con systemctl sin mirar lo que digan las apps.
# Escucha las llamadas a org.kde.Shutdown, así vale para cualquier botón:
# centro de control, menú, Ctrl+Alt+Supr o pantalla de bloqueo.

ESPERA=${ESPERA:-10}
pendiente=""

forzar() {
    local accion=$1
    notify-send -a "Sesión" -i system-shutdown -u critical \
        "Cerrando aplicaciones" \
        "Si algo no se cierra, se forzará en $ESPERA segundos." 2>/dev/null
    sleep "$ESPERA"
    # Si el cierre normal ya terminó, a estas alturas el servicio estaría muerto.
    systemctl "$accion"
}

# Cerrar sesión a secas no se fuerza, pero si una app lo frena, plasma-shutdown
# se queda colgado ocupando org.kde.Shutdown y desde entonces ningún botón de
# sesión responde (el diálogo sale y se cierra solo). Se le quita a los 60 s.
desatascar() {
    sleep 60
    pkill -x plasma-shutdown
}

busctl --user monitor --json=short \
    --match "type='method_call',interface='org.kde.Shutdown',member='logoutAndReboot'" \
    --match "type='method_call',interface='org.kde.Shutdown',member='logoutAndShutdown'" \
    --match "type='method_call',interface='org.kde.Shutdown',member='logout'" |
while read -r linea; do
    case $linea in
        *'"member":"logoutAndReboot"'*)   accion=reboot ;;
        *'"member":"logoutAndShutdown"'*) accion=poweroff ;;
        *'"member":"logout"'*)            desatascar & continue ;;
        *) continue ;;
    esac
    [ -n "$pendiente" ] && kill -0 "$pendiente" 2>/dev/null && continue
    forzar "$accion" &
    pendiente=$!
done
