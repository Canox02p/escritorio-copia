#!/usr/bin/env bash
# Datos que no cambian: modelo de CPU/GPU y arranque.
cpu=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)
gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //; s/ (rev.*//')
arranque=$(awk '{print int($1)}' /proc/uptime)
python3 - "$cpu" "$gpu" "$arranque" <<'PY'
import json, sys
print(json.dumps({"cpu": sys.argv[1], "gpu": sys.argv[2], "arranque": int(sys.argv[3])}))
PY
