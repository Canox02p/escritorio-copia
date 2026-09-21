#!/usr/bin/env bash
# Bytes totales recibidos y enviados desde el arranque, sin contar lo local.
awk 'NR>2 {
    iface=$1; sub(":","",iface);
    if (iface != "lo") { rx += $2; tx += $10 }
} END { printf "{\"rx\":%d,\"tx\":%d}\n", rx, tx }' /proc/net/dev
