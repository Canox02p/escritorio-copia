#!/usr/bin/env bash
# Deja en datos/ del tema de SDDM lo que el inicio de sesión necesita y no puede
# leer por su cuenta (el greeter corre como «sddm», sin acceso a esta carpeta
# personal): fondo actual del escritorio, su paleta, los colores elegidos y el
# tiempo. Lo lanza el servicio de usuario login-cristal (al entrar y cuando
# cambian el fondo, los colores o el tiempo).
#
# Los colores van en los dos sentidos: gana el fichero más reciente, así da
# igual si se eligieron en el bloqueo o en el inicio de sesión.
set -u
destino=${1:-/usr/share/sddm/themes/cristal-cachy/datos}
[[ -d $destino && -w $destino ]] || { echo "sin permiso en $destino (¿falta instalar.sh?)" >&2; exit 1; }

colores="$HOME/.config/bloqueo-colores"
clima="$HOME/.cache/dashboard/clima.json"
fondo_sh="$HOME/.local/share/plasma/shells/local.bloqueo/contents/lockscreen/fondo.sh"

# Escribe stdin en datos/<nombre> solo si cambió (legible y editable por el grupo sddm)
poner() {
    local tmp
    tmp=$(mktemp "$destino/.tmp.XXXXXX") || return
    cat > "$tmp"
    if cmp -s "$tmp" "$destino/$1"; then rm -f "$tmp"; return; fi
    chmod 664 "$tmp" && mv -f "$tmp" "$destino/$1"
}

# 1. Colores elegidos en el login → al bloqueo
#    (solo si son colores válidos: ese fichero lo puede escribir el grupo sddm)
if [[ -s $destino/colores && ( ! -e $colores || $destino/colores -nt $colores ) ]]; then
    { read -r e; read -r p; } < "$destino/colores"
    if [[ ( $e == auto || $e =~ ^#[0-9a-fA-F]{6}$ ) && ( -z $p || $p =~ ^#[0-9a-fA-F]{6}$ ) ]]; then
        printf '%s\n%s\n' "$e" "$p" > "$colores"
        touch -r "$destino/colores" "$colores"
    fi
fi

# 2. Fondo y paleta (fondo.sh ya los calcula y guarda en caché)
json=$(bash "$fondo_sh" 2>/dev/null)
imagen=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("imagen",""))' "$json" 2>/dev/null)
if [[ -s $imagen ]]; then
    poner fondo.jpg < "$imagen"
    python3 -c 'import json,sys; print(json.dumps({"paleta": json.loads(sys.argv[1]).get("paleta", [])}))' "$json" | poner fondo.json
fi

# 3. Colores del bloqueo → al login
if [[ -s $colores ]]; then poner colores < "$colores"; else printf 'auto\n\n' | poner colores; fi
touch -r "$colores" "$destino/colores" 2>/dev/null   # misma fecha: que no rebote

# 4. El tiempo del Tablero
[[ -s $clima ]] && poner clima.json < "$clima"
exit 0
