#!/usr/bin/env bash
# Pone el inicio de sesión cristal-cachy (SDDM) en lugar de Plasma Login Manager.
# Uso:  bash ~/.local/share/login-cristal/instalar.sh
#   - vuelve a generar el tema desde la pantalla de bloqueo
#   - pide la contraseña (sudo) para instalar SDDM, el tema y activarlo
# Para volver atrás:  bash ~/.local/share/login-cristal/instalar.sh --deshacer
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
TEMA=/usr/share/sddm/themes/cristal-cachy
YO=$(id -un)

if [[ ${1:-} == --deshacer ]]; then
    sudo systemctl disable sddm
    sudo systemctl enable -f plasmalogin
    systemctl --user disable --now login-cristal.path login-cristal.service 2>/dev/null || true
    echo "Listo: al reiniciar vuelve Plasma Login Manager (SDDM y el tema siguen instalados)."
    exit 0
fi

python3 "$AQUI/generar.py"

echo "==> SDDM"
pacman -Q sddm >/dev/null 2>&1 || sudo pacman -S --needed sddm

echo "==> Tema en $TEMA"
sudo install -d "$TEMA"
sudo cp -r "$AQUI/tema/cristal-cachy/." "$TEMA/"
sudo rm -rf "$TEMA/datos"
# datos/: lo escribe $YO (sincronizar.sh) y el greeter (grupo sddm) al elegir color
sudo install -d -o "$YO" -g sddm -m 2775 "$TEMA/datos"

echo "==> Configuración de SDDM"
sudo install -d /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-cristal-cachy.conf >/dev/null <<CONF
[Theme]
Current=cristal-cachy
CursorTheme=breeze_cursors

[General]
# Tema de iconos de KDE e idioma en el greeter (sin esto no salen los iconos del tiempo)
GreeterEnvironment=QT_QPA_PLATFORMTHEME=kde,LANG=es_MX.UTF-8

[Users]
RememberLastUser=true
RememberLastSession=true
CONF

echo "==> Sincronización del fondo y colores"
install -Dm644 "$AQUI/systemd/login-cristal.service" ~/.config/systemd/user/login-cristal.service
install -Dm644 "$AQUI/systemd/login-cristal.path" ~/.config/systemd/user/login-cristal.path
systemctl --user daemon-reload
systemctl --user enable --now login-cristal.path
systemctl --user enable login-cristal.service
"$AQUI/sincronizar.sh"

echo "==> Cambiar de Plasma Login Manager a SDDM"
sudo systemctl disable plasmalogin
sudo systemctl enable -f sddm

cat <<FIN

Listo. Al reiniciar saldrá el nuevo inicio de sesión.
Si algo falla y no puedes entrar: Ctrl+Alt+F3, entra con tu usuario y ejecuta
    bash $AQUI/instalar.sh --deshacer
y reinicia.
FIN
