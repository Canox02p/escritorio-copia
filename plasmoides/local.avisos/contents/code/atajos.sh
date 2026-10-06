#!/usr/bin/env bash
# Saca los atajos de teclado del sistema de kglobalshortcutsrc.
# Salida TSV: componente <TAB> descripcion <TAB> teclas
# Las teclas vienen separadas por " | " si hay varias combinaciones.
set -u
F="${1:-$HOME/.config/kglobalshortcutsrc}"
[[ -r $F ]] || exit 0

# Dos pasadas: `_k_friendly_name` puede venir DESPUES de las entradas de su
# propia seccion, asi que primero se recogen todos los nombres legibles y solo
# al final se imprime.
awk '
    /^\[/ {
        seccion = substr($0, 2, length($0) - 2)
        actual = seccion
        if (!(actual in amigable)) amigable[actual] = actual
        next
    }
    /^_k_friendly_name=/ {
        valor = substr($0, index($0, "=") + 1)
        if (valor != "") amigable[actual] = valor
        next
    }
    /^$/ { next }
    /=/ {
        accion = substr($0, 1, index($0, "=") - 1)
        resto  = substr($0, index($0, "=") + 1)

        c1 = index(resto, ",")
        if (c1 == 0) next
        teclas = substr(resto, 1, c1 - 1)
        tras   = substr(resto, c1 + 1)
        c2 = index(tras, ",")
        descripcion = (c2 == 0) ? "" : substr(tras, c2 + 1)

        if (descripcion == "") descripcion = accion
        if (teclas == "none") teclas = ""
        # KConfig guarda el separador como "\t" LITERAL (barra + t), no un tabulador
        gsub(/\\t/, " | ", teclas)

        n++
        secDe[n] = actual
        desDe[n] = descripcion
        tecDe[n] = teclas
    }
    END {
        for (i = 1; i <= n; i++)
            printf "%s\t%s\t%s\n", amigable[secDe[i]], desDe[i], tecDe[i]
    }
' "$F"
