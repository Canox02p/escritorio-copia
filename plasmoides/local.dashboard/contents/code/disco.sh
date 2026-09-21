#!/usr/bin/env bash
# Uso del disco de la raíz, en json.
df -B1 --output=source,size,used,pcent / | tail -1 | awk '{
  gsub("%","",$4);
  printf "{\"origen\":\"%s\",\"total\":%s,\"usado\":%s,\"porcentaje\":%s}\n", $1, $2, $3, $4
}'
