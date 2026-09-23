#!/usr/bin/env python3
"""Administrador de tareas para la tira de CPU/GPU/RAM.

  procesos.py listar        imprime en JSON todos los procesos agrupados por programa
  procesos.py matar PID...  SIGTERM y, si a los 2 s siguen vivos, SIGKILL

Se listan los procesos de todo el sistema (los propios, los de root y los de
otros usuarios, más los hilos del núcleo), porque si no las cuentas no cuadran
con lo que marca la tira: una máquina virtual o un servicio de root pueden
llevarse media CPU sin salir en la lista. Lo que no es del usuario va a la
sección SISTEMA y no se puede finalizar desde aquí.

Lo que ningún proceso explica (interrupciones, procesos que nacen y mueren
entre dos lecturas, caché de disco) se agrupa en una fila "Resto del sistema",
para que la suma de la lista cuadre con los totales de arriba.

El uso de CPU y de GPU es una diferencia entre dos llamadas, así que el estado
anterior se guarda en ~/.cache/panelsistema/. La primera llamada sale a cero.
"""
import glob
import json
import os
import pwd
import signal
import sys
import time


CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "panelsistema")
ESTADO = os.path.join(CACHE, "estado.json")
ESCRITORIOS = os.path.join(CACHE, "escritorios.json")
NUCLEOS = os.cpu_count() or 1
YO = os.getuid()

# Secciones de la lista
APLICACIONES, SEGUNDO_PLANO, SISTEMA = 0, 1, 2

# Cerrar cualquiera de estos se lleva por delante la sesión o el sonido.
CRITICOS = {
    "plasmashell", "kwin_wayland", "kwin_x11", "Xwayland", "ksmserver", "kded6",
    "systemd", "dbus-daemon", "dbus-broker", "pipewire", "wireplumber",
    "pipewire-pulse", "startplasma-wayland", "plasma_session", "sddm",
}
# Lanzadores genéricos: el nombre útil es el del script que ejecutan.
INTERPRETES = {"python", "python3", "bash", "sh", "dash", "zsh", "fish", "node", "perl", "ruby", "java"}

PF_KTHREAD = 0x00200000
# En cuántos ciclos se reparte la relectura de la memoria de cada proceso
TANDAS = 3


# ---------- Nombres e iconos a partir de los .desktop ----------

def dirs_aplicaciones():
    datos = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    base = [os.path.expanduser("~/.local/share")] + datos + [
        os.path.expanduser("~/.local/share/flatpak/exports/share"),
        "/var/lib/flatpak/exports/share",
    ]
    return [os.path.join(d, "applications") for d in base if os.path.isdir(os.path.join(d, "applications"))]


def leer_desktop(ruta):
    campos = {}
    en_entrada = False
    try:
        with open(ruta, encoding="utf-8", errors="replace") as f:
            for linea in f:
                linea = linea.strip()
                if linea.startswith("["):
                    if en_entrada:
                        break
                    en_entrada = linea == "[Desktop Entry]"
                    continue
                if en_entrada and "=" in linea:
                    k, v = linea.split("=", 1)
                    campos.setdefault(k.strip(), v.strip())
    except OSError:
        pass
    return campos


def mapa_escritorios():
    """Clave (binario, clase de ventana o id del .desktop) -> {nombre, icono}."""
    dirs = dirs_aplicaciones()
    sello = [[d, os.stat(d).st_mtime] for d in dirs]
    try:
        with open(ESCRITORIOS) as f:
            guardado = json.load(f)
        if guardado.get("sello") == sello:
            return guardado["mapa"]
    except (OSError, ValueError, KeyError):
        pass

    mapa = {}
    # Se recorren al revés para que ~/.local gane sobre /usr
    for d in reversed(dirs):
        for ruta in glob.glob(os.path.join(d, "**/*.desktop"), recursive=True):
            c = leer_desktop(ruta)
            if c.get("Type", "Application") != "Application" or not c.get("Name"):
                continue
            nombre = c.get("Name[es]") or c.get("Name")
            oculta = c.get("NoDisplay", "").lower() == "true" or c.get("Hidden", "").lower() == "true"
            entrada = {"nombre": nombre, "icono": c.get("Icon", ""), "visible": not oculta}
            ident = os.path.basename(ruta)[:-8].lower()
            claves = {ident, ident.split(".")[-1]}
            if c.get("StartupWMClass"):
                claves.add(c["StartupWMClass"].lower())
            exec_ = c.get("Exec", "").split()
            # Saltar "env VAR=x", "flatpak run --opciones id"
            while exec_ and (exec_[0] == "env" or "=" in exec_[0]):
                exec_.pop(0)
            if exec_:
                if os.path.basename(exec_[0]) == "flatpak":
                    resto = [t for t in exec_[2:] if not t.startswith("-") and not t.startswith("@")]
                    if resto:
                        claves.add(resto[0].lower())
                # "bash -c …" no dice qué programa es: no se apunta
                elif os.path.basename(exec_[0]).rstrip("0123456789.") not in INTERPRETES:
                    binario = exec_[0]
                    claves.add(os.path.basename(binario).lower())
                    real = os.path.realpath(binario if "/" in binario else _which(binario) or binario)
                    claves.add(os.path.basename(real).lower())
            if oculta:
                # Sirve para dar nombre, pero no pisa a una entrada visible
                for k in claves:
                    mapa.setdefault(k, entrada)
            else:
                for k in claves:
                    mapa[k] = entrada

    os.makedirs(CACHE, exist_ok=True)
    with open(ESCRITORIOS, "w") as f:
        json.dump({"sello": sello, "mapa": mapa}, f)
    return mapa


def _which(prog):
    for d in os.environ.get("PATH", "").split(":"):
        r = os.path.join(d, prog)
        if os.access(r, os.X_OK):
            return r
    return None


def buscar_app(mapa, candidatos):
    for c in candidatos:
        if not c:
            continue
        c = c.lower()
        if c in mapa:
            return mapa[c]
        # brave -> brave-browser, code -> code-oss…
        for sufijo in ("-browser", "-stable", "-bin", "-oss", "-desktop"):
            if c + sufijo in mapa:
                return mapa[c + sufijo]
    return None


_usuarios = {}


def nombre_usuario(uid):
    if uid not in _usuarios:
        try:
            _usuarios[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            _usuarios[uid] = str(uid)
    return _usuarios[uid]


# ---------- GPU por proceso (amdgpu/i915/xe publican fdinfo) ----------

def tiempos_gpu(pid):
    """ns de motor por cliente DRM; varios fd pueden ser el mismo cliente."""
    clientes = {}
    try:
        fds = os.listdir(f"/proc/{pid}/fdinfo")
    except OSError:
        return clientes
    for fd in fds:
        try:
            with open(f"/proc/{pid}/fdinfo/{fd}") as f:
                texto = f.read()
        except OSError:
            continue
        if "drm-client-id" not in texto:
            continue
        cid = None
        motores = {}
        vram = 0
        for linea in texto.splitlines():
            if linea.startswith("drm-client-id:"):
                cid = linea.split(":", 1)[1].strip()
            elif linea.startswith("drm-engine-") and not linea.startswith("drm-engine-capacity"):
                k, v = linea.split(":", 1)
                motores[k[11:]] = int(v.split()[0])
            elif linea.startswith("drm-memory-vram:"):
                vram = int(linea.split(":", 1)[1].split()[0]) * 1024
        if cid is not None:
            clientes[cid] = {"motores": motores, "vram": vram}
    return clientes


def gpu_del_sistema():
    """Uso y VRAM de la tarjeta, para saber cuánto no explica ningún proceso."""
    uso, vram = 0.0, 0
    for dev in sorted(glob.glob("/sys/class/drm/card*/device")):
        try:
            with open(dev + "/gpu_busy_percent") as f:
                uso = max(uso, float(f.read().strip()))
        except (OSError, ValueError):
            continue
        try:
            with open(dev + "/mem_info_vram_used") as f:
                vram = max(vram, int(f.read().strip()))
        except (OSError, ValueError):
            pass
    return uso, vram


# ---------- Memoria privada (lo que cuenta Windows como "Memoria") ----------

def memoria_privada(pid, rss):
    """(bytes, exacto). smaps_rollup es la medida buena, pero el núcleo tiene
    que recorrer todo el mapa de memoria: es con diferencia lo más caro de la
    lectura, así que quien llama la reparte entre varios ciclos."""
    try:
        with open(f"/proc/{pid}/smaps_rollup") as f:
            privada = 0
            for linea in f:
                if linea.startswith(("Private_Clean:", "Private_Dirty:")):
                    privada += int(linea.split()[1]) * 1024
            return privada, True
    except OSError:
        # Los de otros usuarios no dejan leer smaps_rollup: queda el RSS
        return rss, False


# ---------- Listado ----------

TICKS = os.sysconf("SC_CLK_TCK")
PAGINA = os.sysconf("SC_PAGE_SIZE")


def leer_proc(pid):
    """Lo mínimo de /proc/PID, o None si ya no está."""
    base = f"/proc/{pid}"
    try:
        uid = os.stat(base).st_uid
        with open(base + "/stat") as f:
            stat = f.read()
        with open(base + "/cmdline", "rb") as f:
            cmd = [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
    except OSError:
        return None
    comm = stat[stat.index("(") + 1:stat.rindex(")")]
    campos = stat[stat.rindex(")") + 2:].split()
    kernel = bool(int(campos[6]) & PF_KTHREAD)
    if not cmd and not kernel:
        return None                     # zombie o murió mientras se leía
    try:
        exe = os.readlink(base + "/exe")
    except OSError:
        exe = ""
    return {
        "comm": comm,
        "cmd": cmd,
        "exe": exe.removesuffix(" (deleted)"),
        "uid": uid,
        "kernel": kernel,
        "cpu": (int(campos[11]) + int(campos[12])) / TICKS,
        "inicio": campos[19],
        "rss": int(campos[21]) * PAGINA,
    }


def nombre_proceso(info):
    if info["kernel"]:
        return info["comm"]
    exe = info["exe"]
    base = os.path.basename(exe) if exe else info["comm"]
    if base.rstrip("0123456789.") in INTERPRETES:
        for arg in info["cmd"][1:]:
            if not arg.startswith("-"):
                return os.path.basename(arg)
    return base or info["comm"]


def cpu_del_sistema():
    """user nice system idle iowait irq softirq steal, en ticks."""
    try:
        with open("/proc/stat") as f:
            return [int(x) for x in f.readline().split()[1:9]]
    except (OSError, ValueError):
        return []


def desglosar_resto(stat_antes, stat_ahora, resto_cpu, resto_ram, resto_gpu, mem):
    """De qué está hecho el hueco entre la lista y los totales.

    Los trozos de CPU salen de /proc/stat y los de memoria de /proc/meminfo, o
    sea que son medidos, no repartidos a ojo; sólo la última línea de cada
    columna es el remanente, y por eso cada parte se recorta a lo que queda.
    """
    hijos = []
    ident = [0]

    def parte(nombre, nota, cpu=0.0, gpu=0.0, ram=0):
        ident[0] -= 1
        hijos.append({
            "pid": ident[0],          # no son procesos: id negativo para la lista
            "nombre": nombre,
            "nota": nota,
            "orden": nota,
            "usuario": "",
            "mio": False,
            "cpu": round(cpu, 1),
            "gpu": round(gpu, 1),
            "ram": ram,
        })

    # ---- CPU: interrupciones, espera de disco y lo que se escapó ----
    queda = resto_cpu
    if len(stat_antes) == len(stat_ahora) == 8:
        d = [y - x for x, y in zip(stat_antes, stat_ahora)]
        total = sum(d)
        if total > 0:
            for nombre, nota, ticks in (
                ("Interrupciones", "Atender al hardware: irq + softirq", d[5] + d[6]),
                ("Espera de disco", "Parada esperando al disco (iowait)", d[4]),
                ("Robada por el anfitrión", "Se lo llevó el anfitrión (steal)", d[7]),
            ):
                v = min(100.0 * ticks / total, queda)
                if v > 0.05:
                    parte(nombre, nota, cpu=v)
                    queda -= v
    if queda > 0.05:
        parte("Programas que ya no están",
              "Duran menos que una lectura de esta lista",
              cpu=queda)

    # ---- Memoria: lo que no es privado de ningún proceso ----
    queda = resto_ram
    for nombre, nota, valor in (
        ("Estructuras del núcleo", "Tablas de páginas, pilas y slab",
         mem.get("SUnreclaim", 0) + mem.get("PageTables", 0) + mem.get("KernelStack", 0)),
        ("Memoria compartida", "tmpfs y memoria compartida (Shmem)",
         mem.get("Shmem", 0)),
    ):
        v = min(valor, queda)
        if v > 8 * 1024 * 1024:
            parte(nombre, nota, ram=v)
            queda -= v
    if queda > 8 * 1024 * 1024:
        parte("Bibliotecas y caché en uso",
              "Código compartido y caché en uso",
              ram=queda)

    # ---- GPU ----
    if resto_gpu > 0.5:
        parte("Otros clientes de la tarjeta",
              "Trabajo que no declara ningún proceso",
              gpu=resto_gpu)

    return hijos


def listar():
    ahora = time.monotonic()
    try:
        with open(ESTADO) as f:
            antes = json.load(f)
    except (OSError, ValueError):
        antes = {}
    t_antes = antes.get("t", 0)
    cpu_antes = antes.get("cpu", {})
    gpu_antes = antes.get("gpu", {})
    stat_antes = antes.get("stat", [])
    ram_antes = antes.get("ram", {})
    ciclo = (antes.get("ciclo", 0) + 1) % TANDAS
    lapso = ahora - t_antes if t_antes else 0
    # Una medida de hace minutos (la ventana estuvo cerrada) daría una media
    # que no dice nada: mejor esperar a la siguiente.
    if lapso > 10:
        lapso = 0

    stat_ahora = cpu_del_sistema()
    # El mismo cálculo que el sensor de la tira: todo lo que no es reposo
    cpu_sistema = 0.0
    if lapso > 0 and len(stat_antes) == len(stat_ahora) == 8:
        d = [y - x for x, y in zip(stat_antes, stat_ahora)]
        total = sum(d)
        if total > 0:
            cpu_sistema = max(0.0, min(100.0, 100.0 * (total - d[3]) / total))

    mapa = mapa_escritorios()
    grupos = {}
    cpu_ahora, gpu_ahora, ram_ahora = {}, {}, {}
    propio = os.getpid()
    suma_cpu = 0.0

    for entrada in os.listdir("/proc"):
        if not entrada.isdigit():
            continue
        pid = int(entrada)
        if pid == propio:
            continue
        info = leer_proc(pid)
        if info is None:
            continue
        mio = info["uid"] == YO and not info["kernel"]
        clave_pid = f"{pid}:{info['inicio']}"

        # CPU: % de toda la máquina, como la columna de Windows
        cpu_ahora[clave_pid] = info["cpu"]
        cpu = 0.0
        if lapso > 0 and clave_pid in cpu_antes:
            cpu = max(0.0, (info["cpu"] - cpu_antes[clave_pid]) / lapso / NUCLEOS * 100)
        suma_cpu += cpu

        # GPU: el motor más ocupado del proceso (Windows hace lo mismo).
        # Los hilos del núcleo no abren clientes DRM: ni se mira.
        gpu = 0.0
        vram = 0
        if not info["kernel"]:
            for cid, dato in tiempos_gpu(pid).items():
                vram += dato["vram"]
                clave_g = f"{clave_pid}:{cid}"
                gpu_ahora[clave_g] = dato["motores"]
                previo = gpu_antes.get(clave_g)
                if previo and lapso > 0:
                    for motor, ns in dato["motores"].items():
                        d = ns - previo.get(motor, ns)
                        gpu = max(gpu, d / (lapso * 1e9) * 100)
        gpu = min(gpu, 100.0)

        # La memoria se remide por tandas: cada ciclo le toca a un tercio de
        # los procesos y los demás reaprovechan lo de la vuelta anterior.
        ram = 0
        if not info["kernel"]:
            previo_ram = ram_antes.get(clave_pid)
            if previo_ram is None or pid % TANDAS == ciclo or lapso == 0:
                ram, exacto = memoria_privada(pid, info["rss"])
                if exacto:
                    ram_ahora[clave_pid] = ram
            else:
                ram = previo_ram
                ram_ahora[clave_pid] = previo_ram

        comm = info["comm"]
        nombre = nombre_proceso(info)
        exe_base = os.path.basename(info["exe"])
        interprete = exe_base.rstrip("0123456789.") in INTERPRETES
        app = None
        if mio:
            app = buscar_app(mapa, [nombre] if interprete else [exe_base, nombre, comm])

        if not mio:
            seccion = SISTEMA
        elif app and app.get("visible"):
            seccion = APLICACIONES
        else:
            seccion = SEGUNDO_PLANO

        if info["kernel"]:
            # kworker, irq, ksoftirqd… son cientos: todos bajo una sola fila,
            # que se despliega si de verdad se quiere ver el detalle
            titulo = "Núcleo del sistema"
            icono = "cpu-symbolic"
        else:
            titulo = app["nombre"] if app else nombre
            icono = app["icono"] if app else ""

        clave = f"{seccion}:{titulo.lower()}"
        g = grupos.setdefault(clave, {
            "nombre": titulo,
            "icono": icono,
            "seccion": seccion,
            "mio": mio,
            "critico": False,
            "cpu": 0.0, "gpu": 0.0, "ram": 0, "vram": 0,
            "hijos": [],
        })
        g["cpu"] += cpu
        g["gpu"] = min(100.0, g["gpu"] + gpu)
        g["ram"] += ram
        g["vram"] += vram
        g["critico"] = g["critico"] or comm in CRITICOS or exe_base in CRITICOS
        g["hijos"].append({
            "pid": pid,
            "nombre": nombre,
            "orden": ("[núcleo]" if info["kernel"]
                      else " ".join(info["cmd"])[:160]),
            "usuario": nombre_usuario(info["uid"]),
            "mio": mio,
            "cpu": round(cpu, 1),
            "gpu": round(gpu, 1),
            "ram": ram,
        })

    os.makedirs(CACHE, exist_ok=True)
    tmp = ESTADO + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"t": ahora, "cpu": cpu_ahora, "gpu": gpu_ahora,
                   "stat": stat_ahora, "ram": ram_ahora, "ciclo": ciclo}, f)
    os.replace(tmp, ESTADO)

    with open("/proc/meminfo") as f:
        mem = {l.split(":")[0]: int(l.split()[1]) * 1024 for l in f}
    ram_usada = mem["MemTotal"] - mem["MemAvailable"]
    gpu_sistema, vram_sistema = gpu_del_sistema()

    salida = []
    suma_gpu = 0.0
    suma_ram = 0
    suma_vram = 0
    for g in grupos.values():
        g["hijos"].sort(key=lambda h: -h["ram"])
        suma_gpu = max(suma_gpu, g["gpu"])   # la GPU no se reparte: no se suma
        suma_ram += g["ram"]
        suma_vram += g["vram"]
        g["cpu"] = round(g["cpu"], 1)
        g["gpu"] = round(g["gpu"], 1)
        g["pids"] = [h["pid"] for h in g["hijos"] if h["mio"]]
        salida.append(g)

    # Lo que no explica ningún proceso: interrupciones y espera de disco, los
    # que nacen y mueren entre dos lecturas, la caché y los búferes del núcleo.
    resto_cpu = max(0.0, cpu_sistema - suma_cpu)
    resto_ram = max(0, ram_usada - suma_ram)
    resto_gpu = max(0.0, gpu_sistema - suma_gpu)
    if lapso > 0 and (resto_cpu > 0.4 or resto_ram > 64 * 1024 * 1024 or resto_gpu > 1):
        hijos = desglosar_resto(stat_antes, stat_ahora, resto_cpu, resto_ram,
                                resto_gpu, mem)
        salida.append({
            "nombre": "Resto del sistema",
            "icono": "system-run-symbolic",
            "seccion": SISTEMA,
            "mio": False,
            "critico": False,
            "resto": True,
            "cpu": round(resto_cpu, 1),
            "gpu": round(resto_gpu, 1),
            "ram": resto_ram,
            "vram": max(0, vram_sistema - suma_vram),
            "hijos": hijos,
            "pids": [],
        })

    print(json.dumps({
        "listo": lapso > 0,
        "grupos": salida,
        "cpuSistema": round(cpu_sistema, 1),
        "gpuSistema": round(gpu_sistema, 1),
        "ramUsada": ram_usada,
        "ramTotal": mem["MemTotal"],
        "vramUsada": vram_sistema,
    }, ensure_ascii=False, separators=(",", ":")))


def matar(pids):
    import psutil

    procs = []
    for pid in pids:
        try:
            p = psutil.Process(int(pid))
            if p.uids().real != YO:
                continue
            p.send_signal(signal.SIGTERM)
            procs.append(p)
        except (psutil.Error, ValueError):
            pass
    _, vivos = psutil.wait_procs(procs, timeout=2)
    for p in vivos:
        try:
            p.kill()
        except psutil.Error:
            pass
    print(json.dumps({"cerrados": len(procs), "forzados": len(vivos)}))


if __name__ == "__main__":
    orden = sys.argv[1] if len(sys.argv) > 1 else "listar"
    if orden == "matar":
        matar(sys.argv[2:])
    else:
        listar()
