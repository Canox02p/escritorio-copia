# Respaldo de mi escritorio (KDE Plasma 6 · CachyOS)

Todo lo que hace falta para dejar otro equipo con este mismo escritorio: los
widgets hechos a medida, el estilo de Plasma y la configuración de los paneles.

## Qué hay aquí

| Carpeta / archivo | Qué es |
|---|---|
| `plasmoides/` | Los widgets propios (ver la tabla de abajo) |
| `estilo/cristal/` | Estilo de Plasma propio: igual que el de serie pero con los **diálogos al 45%**, que es lo que da el efecto de cristal esmerilado a las ventanas de los widgets |
| `config/` | Copia de los ajustes: paneles, atajos, reglas de ventanas, esquema de color |
| `widgets-de-terceros.txt` | Los widgets que **no** son míos y hay que bajar de la tienda |
| `instalar.sh` | Deja todo esto en un equipo nuevo |
| `respaldar.sh` | Vuelve a volcar aquí el escritorio actual (ejecutar tras cada cambio) |

### Los widgets propios

| Widget | Dónde vive | Qué hace |
|---|---|---|
| `local.dashboard` | Barra central de arriba | En la barra: **hora**, título de la canción con desplazamiento y un **visualizador que responde al sonido**. Al pulsar la hora abre **Inicio**; al pulsar la canción, **Música**. Dentro: Inicio (reloj, calendario, tiempo, avisos, música), Música, Sistema, Tiempo y **Portapapeles** (historial de Klipper, se abre también con **Meta+V**) |
| `local.centrocontrol` | Arriba a la derecha | Volumen, Bluetooth, red, brillo de pantalla y teclado, batería y sesión. En la barra enseña internet, volumen, batería y apagado |
| `local.avisos` | Borde derecho (se asoma al acercar el ratón a media altura) | Notificaciones con el dinosaurio cuando no hay nada, accesos rápidos (silencio, micrófono, no molestar, ajustes) y botones para vaciar avisos y abrir los fondos |
| `local.panelsistema` | Arriba a la izquierda | Tira con CPU, GPU, RAM y temperatura; cada dato abre un administrador de tareas (procesos con CPU, GPU y memoria, y botón para finalizarlos) |
| `local.selectorfondos` | Se abre desde el botón *Fondos* del centro de avisos | Cambia el fondo de pantalla: imágenes **y vídeos** |
| `local.escritorios` | Barra lateral | Los números de escritorio, con la misma tipografía que el resto |
| `local.relojcentral`, `local.visualizador` | Sin usar ahora mismo | Se quedan por si hacen falta |

## Requisitos

Paquetes (Arch / CachyOS):

```sh
sudo pacman -S imagemagick ffmpegthumbnailer curl upower python-numpy \
               ttf-jetbrains-mono-nerd
```

Y de KDE, que normalmente ya vienen: `plasma-desktop`, `plasma-workspace`,
`plasma-pa` (audio), `plasma-nm` (redes), `bluedevil` (Bluetooth),
`powerdevil` (brillo y batería), `ksystemstats` (sensores de CPU/GPU).

Los widgets de terceros se bajan desde *Añadir widgets → Obtener nuevos
widgets*; están listados en `widgets-de-terceros.txt`. El importante es
**Panel Colorizer**: es el que deja los **paneles** translúcidos.

## Instalar en otro equipo

```sh
./instalar.sh          # solo widgets y estilo, respeta tus paneles
./instalar.sh --todo   # además restaura paneles, atajos y ajustes
```

Después:

```sh
kquitapp6 plasmashell && kstart plasmashell
plasma-apply-desktoptheme cristal
```

Antes de sobrescribir nada, el instalador guarda lo que tenías en
`~/respaldo-antes-de-instalar-<fecha>/`.

## Actualizar este respaldo

Cada vez que cambies algo del escritorio:

```sh
./respaldar.sh
git add -A && git commit -m "lo que cambiaste"
```

## Cosas que dependen de este equipo

Si algo no cuadra en otra máquina, mira aquí primero:

- **Los paneles llevan números** (28 lateral, 53 arriba derecha, 70 arriba
  centro, 98 arriba izquierda, 101 borde derecho). Al restaurar con `--todo`
  se copian tal cual; si el otro equipo tiene otra resolución o varias
  pantallas puede que haya que recolocarlos a mano.
- **Escala de pantalla**: aquí está al 110%. Los tamaños de las ventanas de
  los widgets están pensados para eso.
- **El fondo de vídeo** (`~/Vídeos/fondo-1080p.mp4`) no se copia por
  tamaño. Es una copia **sin pista de audio** y **a la resolución de la
  pantalla** (1920x1080, 60 fps) del original 4K: con audio, el escritorio se
  roba la salida de sonido; en 4K gasta el doble de decodificador y copia 4
  veces más memoria por fotograma para verse igual. Para prepararlo:
  `ffmpeg -i original.mp4 -an -vf scale=1920:1080:flags=lanczos -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -r 60 -movflags +faststart fondo-1080p.mp4`
- **Fondos de pantalla**: el selector busca en `~/Imágenes/wallpapers`
  (cualquier imagen o vídeo, también en subcarpetas), además de `~/Vídeos`,
  `~/Imágenes` y los fondos del sistema.
- **El tiempo** se saca de wttr.in por IP: no hay que configurar ciudad.
- **Meta+V** abre el portapapeles. El atajo vive en `kglobalshortcutsrc`
  bajo `[tablerodash]`; está aparte en `config/atajos-propios.ini`.

## Deshacer

- Volver al estilo de Plasma de serie: `plasma-apply-desktoptheme default`
- Quitar un widget: clic derecho en el panel → *Entrar en modo de edición*.
- Los paneles translúcidos dependen del Panel Colorizer: si lo quitas de un
  panel, ese panel vuelve a ser opaco.
