#!/usr/bin/env python3
"""Administrador de tareas para la tira de CPU/GPU/RAM.

  procesos.py listar        imprime en JSON los procesos del usuario agrupados por programa
  procesos.py matar PID...  SIGTERM y, si a los 2 s siguen vivos, SIGKILL

El uso de CPU y de GPU es una diferencia entre dos llamadas, así que el estado
anterior se guarda en ~/.cache/panelsistema/. La primera llamada sale a cero.
"""
import glob
import json
import os
import signal
import sys
import time


CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "panelsistema")
ESTADO = os.path.join(CACHE, "estado.json")
ESCRITORIOS = os.path.join(CACHE, "escritorios.json")
NUCLEOS = os.cpu_count() or 1
YO = os.getuid()

# Cerrar cualquiera de estos se lleva por delante la sesión o el sonido.
CRITICOS = {
    "plasmashell", "kwin_wayland", "kwin_x11", "Xwayland", "ksmserver", "kded6",
    "systemd", "dbus-daemon", "dbus-broker", "pipewire", "wireplumber",
    "pipewire-pulse", "startplasma-wayland", "plasma_session", "sddm",
}
# Lanzadores genéricos: el nombre útil es el del script que ejecutan.
INTERPRETES = {"python", "python3", "bash", "sh", "dash", "zsh", "fish", "node", "perl", "ruby", "java"}


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


# ---------- Memoria privada (lo que cuenta Windows como "Memoria") ----------

def memoria_privada(pid, rss):
    try:
        with open(f"/proc/{pid}/smaps_rollup") as f:
            privada = 0
            for linea in f:
                if linea.startswith(("Private_Clean:", "Private_Dirty:")):
                    privada += int(linea.split()[1]) * 1024
            return privada
    except OSError:
        return rss


# ---------- Listado ----------

TICKS = os.sysconf("SC_CLK_TCK")


def leer_proc(pid):
    """Lo mínimo de /proc/PID, o None si no es del usuario o es un hilo del kernel."""
    base = f"/proc/{pid}"
    try:
        if os.stat(base).st_uid != YO:
            return None
        with open(base + "/cmdline", "rb") as f:
            cmd = [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
        if not cmd:
            return None
        with open(base + "/stat") as f:
            stat = f.read()
    except OSError:
        return None
    comm = stat[stat.index("(") + 1:stat.rindex(")")]
    campos = stat[stat.rindex(")") + 2:].split()
    try:
        exe = os.readlink(base + "/exe")
    except OSError:
        exe = ""
    return {
        "comm": comm,
        "cmd": cmd,
        "exe": exe.removesuffix(" (deleted)"),
        "cpu": (int(campos[11]) + int(campos[12])) / TICKS,
        "inicio": campos[19],
        "rss": int(campos[21]) * os.sysconf("SC_PAGE_SIZE"),
    }


def nombre_proceso(info):
    exe = info["exe"]
    base = os.path.basename(exe) if exe else info["comm"]
    if base.rstrip("0123456789.") in INTERPRETES:
        for arg in info["cmd"][1:]:
            if not arg.startswith("-"):
                return os.path.basename(arg)
    return base or info["comm"]


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
    lapso = ahora - t_antes if t_antes else 0
    # Una medida de hace minutos (la ventana estuvo cerrada) daría una media
    # que no dice nada: mejor esperar a la siguiente.
    if lapso > 10:
        lapso = 0

    mapa = mapa_escritorios()
    grupos = {}
    cpu_ahora, gpu_ahora = {}, {}
    propio = os.getpid()

    for entrada in os.listdir("/proc"):
        if not entrada.isdigit():
            continue
        pid = int(entrada)
        if pid == propio:
            continue
        info = leer_proc(pid)
        if info is None:
            continue
        clave_pid = f"{pid}:{info['inicio']}"

        # CPU: % de toda la máquina, como la columna de Windows
        cpu_ahora[clave_pid] = info["cpu"]
        cpu = 0.0
        if lapso > 0 and clave_pid in cpu_antes:
            cpu = max(0.0, (info["cpu"] - cpu_antes[clave_pid]) / lapso / NUCLEOS * 100)

        # GPU: el motor más ocupado del proceso (Windows hace lo mismo)
        gpu = 0.0
        vram = 0
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

        ram = memoria_privada(pid, info["rss"])

        comm = info["comm"]
        nombre = nombre_proceso(info)
        exe_base = os.path.basename(info["exe"])
        interprete = exe_base.rstrip("0123456789.") in INTERPRETES
        app = buscar_app(mapa, [nombre] if interprete else [exe_base, nombre, comm])
        clave = (app["nombre"] if app else nombre).lower()

        g = grupos.setdefault(clave, {
            "nombre": app["nombre"] if app else nombre,
            "icono": app["icono"] if app else "",
            "app": bool(app and app.get("visible")),
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
            "orden": " ".join(info["cmd"])[:160],
            "cpu": round(cpu, 1),
            "gpu": round(gpu, 1),
            "ram": ram,
        })

    os.makedirs(CACHE, exist_ok=True)
    tmp = ESTADO + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"t": ahora, "cpu": cpu_ahora, "gpu": gpu_ahora}, f)
    os.replace(tmp, ESTADO)

    salida = []
    for g in grupos.values():
        g["hijos"].sort(key=lambda h: -h["ram"])
        g["cpu"] = round(g["cpu"], 1)
        g["gpu"] = round(g["gpu"], 1)
        g["pids"] = [h["pid"] for h in g["hijos"]]
        salida.append(g)

    with open("/proc/meminfo") as f:
        mem = {l.split(":")[0]: int(l.split()[1]) * 1024 for l in f}
    print(json.dumps({
        "listo": lapso > 0,
        "grupos": salida,
        "ramUsada": mem["MemTotal"] - mem["MemAvailable"],
        "ramTotal": mem["MemTotal"],
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
