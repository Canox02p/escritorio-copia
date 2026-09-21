#!/usr/bin/env bash
# Detalles de la batería en json (lo que no da el motor powermanagement).
set -u
dev=$(upower -e | grep -m1 BAT) || exit 1
upower -i "$dev" | python3 -c '
import sys, json, re
d = {}
for linea in sys.stdin:
    if ":" not in linea: continue
    k, v = linea.split(":", 1)
    d[k.strip()] = v.strip()
def num(clave, por_defecto=0.0):
    m = re.search(r"-?[\d.]+", d.get(clave, ""))
    return float(m.group()) if m else por_defecto
lleno, diseno = num("energy-full"), num("energy-full-design")
print(json.dumps({
    "ciclos":   int(num("charge-cycles")),
    "voltaje":  round(num("voltage"), 2),
    "vatios":   round(num("energy-rate"), 1),
    "salud":    round(100 * lleno / diseno) if diseno else 0,
    "energia":  round(num("energy"), 1),
    "capacidad": round(diseno, 1),
    "estado":   d.get("state", ""),
    "restante": d.get("time to empty", "") or d.get("time to full", ""),
    "modelo":   d.get("model", ""),
}))
'
