#!/usr/bin/env bash
# Datos del equipo para la pantalla de bloqueo, en una línea de JSON.
leer_cpu() { awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8, $5+$6}' /proc/stat; }
read -r t1 o1 < <(leer_cpu); sleep 0.4; read -r t2 o2 < <(leer_cpu)
cpu=$(( (t2 - t1) > 0 ? 100 - 100 * (o2 - o1) / (t2 - t1) : 0 ))

temp=0
for h in /sys/class/hwmon/hwmon*; do
    [[ $(cat "$h/name" 2>/dev/null) == k10temp || $(cat "$h/name" 2>/dev/null) == coretemp ]] || continue
    temp=$(( $(cat "$h/temp1_input") / 1000 )); break
done

ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print int(100*(t-a)/t)}' /proc/meminfo)
disco=$(df --output=pcent / | tail -1 | tr -dc 0-9)
bat=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
carga=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
seg=$(awk '{print int($1)}' /proc/uptime)
activo="$(( seg / 3600 ))h $(( seg % 3600 / 60 ))m"

printf '{"cpu":%d,"temp":%d,"ram":%d,"disco":%d,"bat":%d,"carga":"%s","activo":"%s","equipo":"%s","nucleo":"%s"}\n' \
    "$cpu" "$temp" "$ram" "${disco:-0}" "${bat:-0}" "$carga" "$activo" "$(cat /etc/hostname 2>/dev/null)" "$(uname -r | cut -d- -f1)"
