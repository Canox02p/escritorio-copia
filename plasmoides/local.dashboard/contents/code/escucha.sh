#!/usr/bin/env bash
# Espera a que se pulse el atajo del portapapeles (Meta+V) y le dice al tablero
# qué sección abrir. Lo arranca main.qml como DataSource, que vuelve a
# conectarse tras cada aviso.
#
# El atajo NO cuelga de una aplicación .desktop: kglobalaccel no consigue
# lanzar una desde ~/.local/share/applications (KService no la resuelve), así
# que se registró un componente propio "tablerodash" y aquí se escucha su señal.
#
# Tres detalles que costaron encontrarse:
#  - stdbuf: al escribir a una tubería gdbus pasa a búfer de bloque y no se
#    vería la línea hasta acumular 4 KB.
#  - nada de `gdbus | grep`: cuando grep sale, gdbus ya no vuelve a escribir,
#    así que nunca recibe SIGPIPE y se queda colgado para siempre.
#  - la sustitución de proceso deja en $! el PID REAL de gdbus (stdbuf hace
#    exec), que es lo que permite matarlo. Con `coproc` el PID es el del
#    subshell y gdbus sobrevive: cada pulsación dejaba dos procesos sueltos.
#
# El -t de read es la red de seguridad por si plasmashell se va: al expirar
# sale sin imprimir nada y el QML se reconecta.

SECCION_PORTAPAPELES=4

# Vuelve a dar de alta la acción en cada arranque de plasmashell. La tecla en
# sí vive en ~/.config/kglobalshortcutsrc ([tablerodash] portapapeles=Meta+V),
# así que esto no la pisa: solo asegura que kglobalaccel la tenga activa
# aunque nadie la haya reclamado tras reiniciar la sesión.
gdbus call --session --dest org.kde.kglobalaccel \
    --object-path /kglobalaccel \
    --method org.kde.KGlobalAccel.doRegister \
    "['tablerodash','portapapeles','Tablero','Abrir el portapapeles']" >/dev/null 2>&1

# Barre monitores huérfanos de arranques anteriores: cuando plasmashell se va,
# se lleva este script por delante y el gdbus hijo sobrevive sin nadie que lo
# mate. Sin esto se acumulan decenas de procesos.
pkill -f 'gdbus monitor --session --dest org.kde.kglobalaccel --object-path /component/tablerodash' 2>/dev/null

exec 3< <(stdbuf -oL gdbus monitor --session \
            --dest org.kde.kglobalaccel \
            --object-path /component/tablerodash 2>/dev/null)
MONITOR=$!
trap 'kill "$MONITOR" 2>/dev/null' EXIT INT TERM HUP

seccion=""
while IFS= read -r -t 3600 linea <&3; do
    case "$linea" in
        *globalShortcutPressed*portapapeles*) seccion=$SECCION_PORTAPAPELES; break ;;
    esac
done

exec 3<&-
kill "$MONITOR" 2>/dev/null
wait "$MONITOR" 2>/dev/null

[ -n "$seccion" ] && echo "$seccion"
exit 0
