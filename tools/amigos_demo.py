#!/usr/bin/env python3
"""Cuentas de pega para la captura de Social. SIEMBRA Y BORRA.

Escribe en la base de datos REAL con credenciales de administrador, así que
lleva su limpieza incorporada desde el primer día: `--borrar` deshace todo lo
que `--sembrar` puso, y nada más. Autorizado por André el 27-8-2026 para las
capturas de tienda, con el compromiso explícito de borrarlas después.

Qué cuesta y por qué importa: cada cuenta ocupa un @usuario del espacio de
nombres COMPARTIDO de la familia, que para los clientes es inmutable. Con
credenciales de administrador sí se liberan — por eso el borrado existe y por
eso los handles llevan el prefijo `zz_demo_`: si algo falla y quedan, se ven a
la legua y se limpian con una consulta.

    python3 tools/amigos_demo.py --sembrar <uid-de-la-cuenta-del-simulador>
    python3 tools/amigos_demo.py --borrar  <uid-de-la-cuenta-del-simulador>
"""
import json, subprocess, sys, urllib.request, datetime

PROJ = "cinco-fe5cc"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJ}/databases/(default)/documents"
PREFIJO = "zz_demo_"

# Nombres neutros e inventados: NUNCA gente real de la lista de André — sus
# amigos son personas y no pueden acabar en una ficha de tienda.
AMIGOS = [
    # (uid falso,        @usuario,          nombre,    avatar,     país, puntos, racha)
    (f"{PREFIJO}ana",   f"{PREFIJO}ana",   "Ana",     "montana",  "PR", 3120, 21),
    (f"{PREFIJO}luis",  f"{PREFIJO}luis",  "Luis",    "guitarra", "PR", 2540, 14),
    (f"{PREFIJO}marta", f"{PREFIJO}marta", "Marta",   "ola",      "US", 1890, 9),
]

def token():
    return subprocess.run(['gcloud','auth','print-access-token'],
                          capture_output=True, text=True).stdout.strip().split('\n')[-1]

def pedir(metodo, ruta, cuerpo=None):
    req = urllib.request.Request(f"{BASE}/{ruta}", method=metodo,
        headers={"Authorization": f"Bearer {token()}", "Content-Type":"application/json"},
        data=json.dumps(cuerpo).encode() if cuerpo else None)
    try:
        with urllib.request.urlopen(req) as r: return json.load(r)
    except urllib.error.HTTPError as e:
        return {"error": e.code, "detalle": e.read().decode()[:200]}

def S(v): return {"stringValue": v}
def I(v): return {"integerValue": str(v)}

def par(a, b):
    """Id canónico de la amistad: los dos uids ordenados, unidos por '_'."""
    x, y = sorted([a, b]);  return f"{x}_{y}"

def sembrar(mio):
    hoy = datetime.date.today()
    lunes = hoy - datetime.timedelta(days=hoy.weekday())
    for uid, handle, nombre, avatar, pais, puntos, racha in AMIGOS:
        # El perfil, y su @usuario reclamado (para que el espacio de nombres
        # quede coherente: un perfil con handle que nadie tiene sería mentira).
        pedir("PATCH", f"users/{uid}", {"fields": {
            "username": S(handle), "displayName": S(nombre),
            "avatar": S(avatar), "country": S(pais),
        }})
        pedir("PATCH", f"usernames/{handle}", {"fields": {"uid": S(uid)}})
        # El RESUMEN por juego: normalmente lo escribe el servidor desde los
        # días crudos, pero aquí no hay partidas que recalcular — son cuentas
        # de atrezo. Se escribe con administrador, que se salta las reglas.
        pedir("PATCH", f"users/{uid}/apps/nona", {"fields": {
            "totalPoints": I(puntos), "streak": I(racha), "bestStreak": I(racha + 4),
            "weekPoints": I(puntos // 12), "weekId": S(lunes.isoformat()),
            "monthPoints": I(puntos // 4), "monthId": S(hoy.strftime("%Y-%m")),
            "lastPlayedDay": S(hoy.isoformat()),
        }})
        # La amistad ACTIVA: sin esto no salen en la clasificación, que solo
        # mira amigos activos.
        pedir("PATCH", f"friendships/{par(mio, uid)}", {"fields": {
            "users": {"arrayValue": {"values": [S(x) for x in sorted([mio, uid])]}},
            "status": S("active"), "requestedBy": S(mio),
        }})
        print(f"  sembrado @{handle} · {puntos} pts · racha {racha}")

def borrar(mio):
    for uid, handle, *_ in AMIGOS:
        pedir("DELETE", f"users/{uid}/apps/nona")
        pedir("DELETE", f"users/{uid}")
        pedir("DELETE", f"usernames/{handle}")
        pedir("DELETE", f"friendships/{par(mio, uid)}")
        print(f"  borrado @{handle}")

if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("--sembrar","--borrar"):
        print(__doc__); sys.exit(1)
    accion, mio = sys.argv[1], sys.argv[2]
    print(f"{'Sembrando' if accion=='--sembrar' else 'Borrando'} 3 cuentas de pega para {mio[:8]}…")
    (sembrar if accion=="--sembrar" else borrar)(mio)
    print("Hecho." + (" NO OLVIDES --borrar tras las capturas." if accion=="--sembrar" else ""))
