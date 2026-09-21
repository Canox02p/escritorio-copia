#!/usr/bin/env bash
# Abre (o cierra, si ya está abierto) el selector de fondos a pantalla completa.
set -u
UI="$(cd "$(dirname "${BASH_SOURCE[0]}")/../ui" && pwd)"
PID="${XDG_RUNTIME_DIR:-/tmp}/selector-fondos.pid"

# Si ya hay uno abierto, el botón lo cierra (no se usa pgrep: se confunde con
# el propio comando que lo lanza).
if [[ -s $PID ]] && kill -0 "$(<"$PID")" 2>/dev/null; then
    kill "$(<"$PID")" 2>/dev/null
    rm -f "$PID"
    exit 0
fi

setsid qml6 "$UI/Pantalla.qml" >/dev/null 2>&1 &
echo $! > "$PID"
