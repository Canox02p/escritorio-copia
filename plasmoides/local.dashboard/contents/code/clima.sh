#!/usr/bin/env bash
# Tiempo actual y tres días, desde wttr.in (sin clave ni configuración).
set -u
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dashboard"
mkdir -p "$CACHE"
ARCHIVO="$CACHE/clima.json"

# Si la copia en caché tiene menos de 15 minutos, se reutiliza
if [[ -s $ARCHIVO ]] && [[ $(( $(date +%s) - $(stat -c %Y "$ARCHIVO") )) -lt 900 ]]; then
    cat "$ARCHIVO"; exit 0
fi

datos=$(curl -s -m 8 'https://wttr.in/?format=j1' 2>/dev/null) || true
[[ -z $datos ]] && { [[ -s $ARCHIVO ]] && cat "$ARCHIVO"; exit 0; }

printf '%s' "$datos" | python3 -c '
import sys, json
d = json.load(sys.stdin)
ahora = d["current_condition"][0]
zona = d.get("nearest_area", [{}])[0]

def texto(c):
    v = c.get("weatherDesc") or c.get("value")
    if isinstance(v, list) and v: return v[0]["value"]
    return str(v or "")

def icono(codigo, desc):
    c = int(codigo or 0)
    t = desc.lower()
    if c in (113,): return "weather-clear-symbolic"
    if c in (116,): return "weather-few-clouds-symbolic"
    if c in (119, 122): return "weather-clouds-symbolic"
    if c in (143, 248, 260): return "weather-fog-symbolic"
    if c in (200, 386, 389, 392, 395): return "weather-storm-symbolic"
    if c in (227, 230, 320, 323, 326, 329, 332, 335, 338, 368, 371): return "weather-snow-symbolic"
    if "rain" in t or "drizzle" in t or "shower" in t: return "weather-showers-symbolic"
    if "cloud" in t or "overcast" in t: return "weather-clouds-symbolic"
    return "weather-few-clouds-symbolic"

dias = []
for dia in d.get("weather", [])[:3]:
    medio = dia["hourly"][4] if len(dia["hourly"]) > 4 else dia["hourly"][0]
    dias.append({
        "fecha": dia["date"],
        "max": int(dia["maxtempC"]),
        "min": int(dia["mintempC"]),
        "desc": texto(medio),
        "icono": icono(medio.get("weatherCode"), texto(medio)),
    })

lugar = zona.get("areaName", [{}])[0].get("value", "")
region = zona.get("region", [{}])[0].get("value", "")
desc = texto(ahora)
print(json.dumps({
    "lugar": lugar or region,
    "temp": int(ahora["temp_C"]),
    "sensacion": int(ahora["FeelsLikeC"]),
    "desc": desc,
    "icono": icono(ahora.get("weatherCode"), desc),
    "humedad": int(ahora["humidity"]),
    "viento": int(ahora["windspeedKmph"]),
    "dias": dias,
}, ensure_ascii=False))
' > "$ARCHIVO.tmp" 2>/dev/null && mv "$ARCHIVO.tmp" "$ARCHIVO" && cat "$ARCHIVO"
