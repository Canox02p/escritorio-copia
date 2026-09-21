#!/usr/bin/env python3
"""Servidor del visualizador de audio del Panel del sistema.

Captura lo que suena por la salida predeterminada (su monitor), calcula las
barras con una FFT y las envía como JSON por WebSocket a 127.0.0.1:PUERTO.
Se cierra solo cuando lleva un rato sin clientes conectados.
"""
import asyncio
import base64
import hashlib
import json
import subprocess

import numpy as np

PUERTO = 47863
BARRAS = 48
TASA = 44100
VENTANA = 2048
SALTO = TASA // 60              # 60 por segundo, lo mismo que refresca la pantalla
ESPERA_SIN_CLIENTES = 8         # segundos
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

clientes = set()
proceso = None


def limites_bandas():
    # Bandas espaciadas logarítmicamente, como las oye el oído
    frecuencias = np.geomspace(50, 14000, BARRAS + 1)
    idx = np.round(frecuencias * VENTANA / TASA).astype(int)
    for i in range(1, len(idx)):
        if idx[i] <= idx[i - 1]:
            idx[i] = idx[i - 1] + 1
    return idx


def marco_texto(texto):
    datos = texto.encode()
    n = len(datos)
    cabecera = bytes([0x81, n]) if n < 126 else bytes([0x81, 126]) + n.to_bytes(2, "big")
    return cabecera + datos


def salida_predeterminada():
    try:
        return subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True, timeout=2).stdout.strip()
    except Exception:
        return ""


async def atender(lector, escritor):
    try:
        peticion = await asyncio.wait_for(lector.readuntil(b"\r\n\r\n"), 5)
    except Exception:
        escritor.close()
        return

    clave = None
    for linea in peticion.decode(errors="ignore").split("\r\n"):
        if linea.lower().startswith("sec-websocket-key:"):
            clave = linea.split(":", 1)[1].strip()
    if not clave:
        escritor.close()
        return

    acepta = base64.b64encode(hashlib.sha1((clave + GUID).encode()).digest()).decode()
    escritor.write(("HTTP/1.1 101 Switching Protocols\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n"
                    "Sec-WebSocket-Accept: " + acepta + "\r\n\r\n").encode())
    await escritor.drain()
    clientes.add(escritor)

    try:
        while True:
            datos = await lector.read(1024)
            if not datos or datos[0] & 0x0F == 0x8:   # fin de conexión o marco de cierre
                break
    except Exception:
        pass
    finally:
        clientes.discard(escritor)
        escritor.close()


async def capturar():
    global proceso
    idx = limites_bandas()
    ventana = np.hanning(VENTANA).astype(np.float32)
    realce = np.linspace(1.0, 2.5, BARRAS)   # los agudos traen menos energía
    buffer = np.zeros(VENTANA, dtype=np.float32)
    previo = np.zeros(BARRAS, dtype=np.float32)
    techo = 3.0
    inicios = idx[:-1]
    quietas = False

    while True:
        proceso = await asyncio.create_subprocess_exec(
            "parec", "--device=@DEFAULT_MONITOR@", "--format=s16le", f"--rate={TASA}", "--channels=1",
            "--latency-msec=20", "--client-name=Panel del sistema", "--stream-name=Visualizador",
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        try:
            while True:
                crudo = await proceso.stdout.readexactly(SALTO * 2)
                if not clientes:
                    continue
                muestras = np.frombuffer(crudo, dtype="<i2").astype(np.float32) / 32768.0
                # Desplazar en el sitio: np.roll creaba un array nuevo cada vez
                buffer[:-SALTO] = buffer[SALTO:]
                buffer[-SALTO:] = muestras

                espectro = np.abs(np.fft.rfft(buffer * ventana))
                bandas = np.maximum.reduceat(espectro, inicios)
                np.log1p(bandas * realce, out=bandas)

                # Ganancia automática: el techo sigue al máximo y baja despacio
                techo = max(techo * 0.99833, float(bandas.max()), 3.0)
                valores = np.clip(bandas / techo, 0, 1) ** 1.6

                # Suben rápido y caen suave (constantes ajustadas a 60 por segundo
                # para que el ritmo en el tiempo sea el mismo que a 50)
                previo = np.where(valores > previo,
                                  previo + (valores - previo) * 0.633,
                                  np.maximum(valores, previo * 0.882)).astype(np.float32)

                # En silencio, una vez caídas las barras, no se manda nada:
                # el panel no tiene que redibujar barras quietas
                if previo.max() < 0.002:
                    if quietas:
                        continue
                    previo[:] = 0
                    quietas = True
                else:
                    quietas = False

                # Milésimas enteras: JSON más corto y sin pasar por float de Python
                mensaje = marco_texto("[" + ",".join(map(str, np.rint(previo * 1000).astype(int).tolist())) + "]")
                for escritor in list(clientes):
                    if escritor.transport.is_closing() or escritor.transport.get_write_buffer_size() > 65536:
                        clientes.discard(escritor)
                        escritor.close()
                    else:
                        escritor.write(mensaje)
        except asyncio.IncompleteReadError:
            await asyncio.sleep(0.5)   # parec terminó (p. ej. cambió la salida): se reinicia
        finally:
            if proceso.returncode is None:
                proceso.kill()
                await proceso.wait()


async def vigilar():
    sin_clientes = 0
    salida = salida_predeterminada()
    segundos = 0
    while sin_clientes < ESPERA_SIN_CLIENTES:
        await asyncio.sleep(1)
        segundos += 1
        sin_clientes = 0 if clientes else sin_clientes + 1
        # Si cambias de salida (audífonos, bluetooth…), se vuelve a enganchar a la nueva
        if segundos % 3 == 0:
            actual = salida_predeterminada()
            if actual and actual != salida:
                salida = actual
                if proceso and proceso.returncode is None:
                    proceso.kill()


async def principal():
    try:
        servidor = await asyncio.start_server(atender, "127.0.0.1", PUERTO)
    except OSError:
        return   # ya hay otro en marcha
    captura = asyncio.create_task(capturar())
    await vigilar()
    captura.cancel()
    try:
        await captura
    except asyncio.CancelledError:
        pass
    servidor.close()


if __name__ == "__main__":
    asyncio.run(principal())
