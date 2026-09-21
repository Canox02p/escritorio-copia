#!/usr/bin/env bash
# Aplica un fondo de escritorio: aplicar.sh imagen|video <ruta>
set -u
tipo=$1
ruta=$2

if [[ $tipo == video ]]; then
    url_js=$(printf 'file://%s' "$ruta" | sed 's/\\/\\\\/g; s/"/\\"/g')
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
var url = \"$url_js\";
var plugin = \"luisbocanegra.smart.video.wallpaper.reborn\";
desktops().forEach(function (d) {
    d.wallpaperPlugin = plugin;
    d.currentConfigGroup = [\"Wallpaper\", plugin, \"General\"];
    d.writeConfig(\"VideoUrls\", JSON.stringify([{ filename: url, enabled: true, duration: 0, customDuration: 0, playbackRate: 0, alternativePlaybackRate: 0, loop: true }]));
    d.writeConfig(\"LastVideo\", url);
    d.writeConfig(\"LastVideoPosition\", 0);
});"
else
    plasma-apply-wallpaperimage "$ruta"
fi
