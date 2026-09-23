# Respaldo de mi escritorio (KDE Plasma 6 · CachyOS)

Todo lo que hace falta para dejar otro equipo con este mismo escritorio: los
widgets hechos a medida (las barras), el estilo de Plasma, la configuración de
los paneles, la **pantalla de bloqueo**, el **inicio de sesión (login)**, el
cubo de escritorios con fondo difuminado y los servicios pequeños (audio
Bluetooth y reinicio forzado).

## Qué hay aquí

| Carpeta / archivo | Qué es |
|---|---|
| `plasmoides/` | Los widgets propios (ver la tabla de abajo) |
| `estilo/cristal/` | Estilo de Plasma propio: igual que el de serie pero con los **diálogos al 45%**, que es lo que da el efecto de cristal esmerilado a las ventanas de los widgets |
| `bloqueo/` | Pantalla de bloqueo propia (`local.bloqueo`) y el ajuste de KWin que la activa |
| `login/` | Inicio de sesión: tema SDDM `cristal-cachy`, generado a partir de la pantalla de bloqueo |
| `efectos/cube/` | Cubo de escritorios de KWin con tu fondo difuminado detrás |
| `apagado/` | Reinicio/apagado forzado a los 10 s si una app lo frena (como en Windows) |
| `audio/` | Cambia el sonido solo al conectar unos audífonos Bluetooth |
| `config/` | Copia de los ajustes: paneles, atajos, reglas de ventanas, esquema de color, bloqueo (`kscreenlockerrc`), el color elegido en el bloqueo (`bloqueo-colores`), cursor (`kcminputrc`), avisos, energía, apariencia de GTK y la disposición de pantallas (`kwinoutputconfig.json`, sólo de consulta) |
| `widgets-de-terceros.txt` | Los widgets que **no** son míos y hay que bajar de la tienda |
| `temas-de-terceros.txt` | Iconos, temas de Plasma, decoraciones y esquemas de color que tampoco son míos: se bajan de *Obtener nuevos…* |
| `fondos.txt` | Qué fondos usa el escritorio y dónde están. Las imágenes y los vídeos no se suben: pesan y son descargas |
| `instalar.sh` | Deja todo esto en un equipo nuevo |
| `respaldar.sh` | Vuelve a volcar aquí el escritorio actual (ejecutar tras cada cambio) |

### Los widgets propios

| Widget | Dónde vive | Qué hace |
|---|---|---|
| `local.dashboard` | Barra central de arriba | En la barra: **hora**, título de la canción con desplazamiento y un **visualizador que responde al sonido**. Al pulsar la hora abre **Inicio**; al pulsar la canción, **Música**. Dentro: Inicio (reloj, calendario, tiempo, avisos, música), Música, Sistema, Tiempo y **Portapapeles** (historial de Klipper, se abre también con **Meta+V**) |
| `local.centrocontrol` | Arriba a la derecha | Volumen, Bluetooth, red, brillo de pantalla y teclado, batería y sesión. En la barra enseña internet, volumen, batería y apagado |
| `local.avisos` | Borde derecho (se asoma al acercar el ratón a media altura) | Notificaciones con el dinosaurio cuando no hay nada, accesos rápidos (silencio, micrófono, no molestar, ajustes) y botones para vaciar avisos y abrir los fondos |
| `local.panelsistema` | Arriba a la izquierda | Tira con CPU, GPU, RAM y temperatura; cada dato abre un administrador de tareas al estilo del de Windows. Lista **todo el sistema** (lo tuyo, lo de root y los hilos del núcleo), con filtro *TODO · APPS · FONDO · SISTEMA*, orden por cualquier columna en los dos sentidos y una fila *Resto del sistema*, desplegable, con lo que no carga ningún proceso, para que la lista cuadre con los totales |
| `local.selectorfondos` | Se abre desde el botón *Fondos* del centro de avisos | Cambia el fondo de pantalla: imágenes **y vídeos**. Se abre a pantalla completa (tira de tarjetas inclinadas) con `contents/code/abrir.sh` |
| `local.escritorios` | Barra lateral | Los números de escritorio, con la misma tipografía que el resto |
| `local.relojcentral`, `local.visualizador` | Sin usar ahora mismo | Se quedan por si hacen falta |

## Requisitos

Paquetes (Arch / CachyOS):

```sh
sudo pacman -S imagemagick ffmpegthumbnailer ffmpeg curl upower python-numpy \
               ttf-jetbrains-mono-nerd layer-shell-qt qt6-declarative
```

`layer-shell-qt` y `qml6` son para el selector de fondos a pantalla completa.
El login necesita además `sddm` (lo instala su propio instalador).

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

`instalar.sh` deja también en su sitio la pantalla de bloqueo, el cubo, el
reinicio forzado y el audio Bluetooth (estos dos se activan solos). El login
solo lo **copia**; hay que activarlo aparte, ver abajo.

## Pantalla de bloqueo

- Vive en `~/.local/share/plasma/shells/local.bloqueo/contents/lockscreen/`
  (`LockScreenUi.qml`, `Tarjeta.qml`, `Medidor.qml`, `estado.sh`, `fondo.sh`).
- Panel de cristal con tiempo, ficha del sistema, música, reloj, contraseña,
  CPU/RAM/disco, batería y botones de sesión. El fondo es **el mismo del
  escritorio** (`fondo.sh` lo lee del appletsrc; si es vídeo saca un fotograma)
  y el color de acento se elige en la propia pantalla (se guarda en
  `~/.config/bloqueo-colores`).
- Se activa con `bloqueo/kwin-bloqueo.conf`, que se copia a
  `~/.config/systemd/user/plasma-kwin_wayland.service.d/bloqueo.conf`
  (pone `PLASMA_DEFAULT_SHELL=local.bloqueo` **solo para KWin**). Hace efecto
  al volver a iniciar sesión. No poner esa variable en todo el sistema: el
  escritorio cambiaría de shell.
- Probarla sin bloquear:
  `timeout 9 /usr/lib/kscreenlocker_greet --testing --shell local.bloqueo`
- Quitarla: borrar ese `bloqueo.conf` y la carpeta `local.bloqueo`.

## Inicio de sesión (login)

- Es un tema de **SDDM** (`cristal-cachy`) hecho a partir de la pantalla de
  bloqueo, con usuarios, sesión (Plasma/Hyprland) y energía en las esquinas.
  Plasma Login Manager no se puede tematizar, por eso se usa SDDM.
- `instalar.sh` del respaldo lo copia a `~/.local/share/login-cristal/`.
  Para activarlo (pide la contraseña de sudo):

  ```sh
  bash ~/.local/share/login-cristal/instalar.sh
  ```

  Eso regenera el tema desde la pantalla de bloqueo (`generar.py`), instala
  SDDM si falta, copia el tema a `/usr/share/sddm/themes/cristal-cachy`, crea
  `/etc/sddm.conf.d/10-cristal-cachy.conf`, activa el servicio de usuario
  `login-cristal.path` (mantiene sincronizados fondo, colores y tiempo) y
  cambia de Plasma Login Manager a SDDM.
- **Si cambias la pantalla de bloqueo**, vuelve a ejecutar ese `instalar.sh`
  para que el login la copie. No edites `Main.qml` a mano: se regenera.
- Si algo sale mal y no puedes entrar: `Ctrl+Alt+F3`, entra con tu usuario y
  `bash ~/.local/share/login-cristal/instalar.sh --deshacer`, luego reinicia.

## Cubo de escritorios con fondo difuminado

- Copia del efecto *Cubo* de KWin en `~/.local/share/kwin/effects/cube/`
  (tiene preferencia sobre el del sistema). El único cambio está en
  `contents/ui/ScreenView.qml`: detrás del cubo se pinta el fondo del
  escritorio en vivo (sirve también con vídeo) con desenfoque.
- Aplicarlo sin cerrar sesión:
  `qdbus6 org.kde.KWin /Effects unloadEffect cube; qdbus6 org.kde.KWin /Effects loadEffect cube`
- Si una actualización de Plasma cambia el cubo, rehacer la copia desde
  `/usr/share/kwin/effects/cube` y repetir el cambio. Quitarlo: borrar la carpeta.

## Servicios pequeños

- **Reinicio forzado** (`apagado/`): `~/.local/bin/forzar-apagado.sh` +
  `forzar-apagado.service`. Si al reiniciar/apagar una app lo frena, a los
  10 s se fuerza. Si los botones de sesión dejan de responder:
  `pkill -x plasma-shutdown`.
- **Audio Bluetooth** (`audio/`): `~/.local/bin/bt-audio-autoswitch` +
  `bt-audio-autoswitch.service`. Al conectar unos audífonos Bluetooth el
  sonido se pasa a ellos solo.

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
- **La disposición de pantallas** (`config/kwinoutputconfig.json`) se guarda
  para poder consultarla, pero `instalar.sh --todo` **no la aplica**: describe
  los monitores de este portátil y en otro equipo dejaría la pantalla mal.
- **El tiempo** se saca de wttr.in por IP: no hay que configurar ciudad.
- **Meta+V** abre el portapapeles. El atajo vive en `kglobalshortcutsrc`
  bajo `[tablerodash]`; está aparte en `config/atajos-propios.ini`.

## Deshacer

- Volver al estilo de Plasma de serie: `plasma-apply-desktoptheme default`
- Quitar un widget: clic derecho en el panel → *Entrar en modo de edición*.
- Los paneles translúcidos dependen del Panel Colorizer: si lo quitas de un
  panel, ese panel vuelve a ser opaco.
