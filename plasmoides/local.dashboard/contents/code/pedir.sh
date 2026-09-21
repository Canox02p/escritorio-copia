#!/usr/bin/env bash
# Dispara el atajo del portapapeles igual que haría pulsar Meta+V.
# Sirve para probar la cadena sin tocar el teclado.

exec gdbus call --session \
    --dest org.kde.kglobalaccel \
    --object-path /component/tablerodash \
    --method org.kde.kglobalaccel.Component.invokeShortcut "portapapeles"
