#!/usr/bin/env bash
# Abre (o cierra, si ya está abierto) la pantalla de atajos de teclado.
set -u
UI="$(cd "$(dirname "${BASH_SOURCE[0]}")/../ui" && pwd)"
PID="${XDG_RUNTIME_DIR:-/tmp}/atajos-teclado.pid"

# Mismo truco que el selector de fondos: fichero de PID, no pgrep (pgrep se
# confunde con el propio comando que lanza esto).
if [[ -s $PID ]] && kill -0 "$(<"$PID")" 2>/dev/null; then
    kill "$(<"$PID")" 2>/dev/null
    rm -f "$PID"
    exit 0
fi

setsid qml6 "$UI/PantallaAtajos.qml" >/dev/null 2>&1 &
echo $! > "$PID"
