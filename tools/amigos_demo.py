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
# El espacio de ESTE juego en Firestore (`nonaGameId` en lib/nona_config.dart).
# El guion vino de Nona con `apps/nona` escrito a mano en cinco sitios: sembraba
# los amigos en la clasificación de Nona, y `--borrar` se llevaba los días de
# NONA de la cuenta del simulador — progreso real, si la cuenta es de verdad.
# Corregido el 24-11-2026, antes de usarlo por primera vez en Minesweeper.
JUEGO = "minesweeper"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJ}/databases/(default)/documents"
# Handles NATURALES a propósito. El primer intento usó un prefijo `zz_demo_`
# para poder barrer restos... y se veía en la fila del marcador: arruinaba la
# captura, que era el único motivo de todo esto. La seguridad de la limpieza no
# depende del prefijo — depende de que la lista de abajo sea la autoridad y de
# que `--borrar` la recorra entera, que está comprobado.
PREFIJO = ""

# Nombres neutros e inventados: NUNCA gente real de la lista de André — sus
# amigos son personas y no pueden acabar en una ficha de tienda.
# Tres países hispanohablantes distintos (decisión de André): la clasificación
# enseña de un vistazo que el juego es de toda Hispanoamérica y no solo de Puerto
# Rico. Los apellidos acompañan al país para que la fila no chirríe.
AMIGOS = [
    # (uid falso,             @usuario,       nombre,          avatar,     país, puntos, racha)
    ("demo_uid_ana",   "ana_rivera",   "Ana Rivera",    "montana",  "MX", 3120, 21),
    ("demo_uid_luis",  "luis_mendez",  "Luis Méndez",   "guitarra", "CO", 2540, 14),
    ("demo_uid_marta", "marta_ortiz",  "Marta Ortiz",   "ola",      "AR", 1890, 9),
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
        pedir("PATCH", f"users/{uid}/apps/{JUEGO}", {"fields": {
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
        pedir("DELETE", f"users/{uid}/apps/{JUEGO}")
        pedir("DELETE", f"users/{uid}")
        pedir("DELETE", f"usernames/{handle}")
        pedir("DELETE", f"friendships/{par(mio, uid)}")
        print(f"  borrado @{handle}")

    # El PROGRESO de pega que la app subió sola.
    #
    # Esto no estaba en la primera versión y era un hueco de verdad: el guion
    # hermano (`sembrar_demo.py`) siembra días en las preferencias del
    # simulador, y al iniciar sesión `ProgressSync` los sube a la nube como
    # progreso legítimo — que es exactamente su trabajo. Así que la cuenta se
    # quedaba con 33 días inventados dentro aunque los amigos desaparecieran.
    # Lo cazó el agente de ficha leyendo el log del iPad.
    dias = pedir("GET", f"users/{mio}/apps/{JUEGO}/days?pageSize=300")
    for doc in (dias or {}).get("documents", []):
        pedir("DELETE", "/".join(doc["name"].split("/documents/")[1:]))
    print(f"  borrados {len((dias or {}).get('documents', []))} días de pega")
    # Y el resumen que el servidor recalculó a partir de ellos: sin los días,
    # el número que quedaría no lo respalda nada.
    pedir("DELETE", f"users/{mio}/apps/{JUEGO}")
    print(f"  borrado el resumen de {JUEGO} de la cuenta de pruebas")

if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("--sembrar","--borrar"):
        print(__doc__); sys.exit(1)
    accion, mio = sys.argv[1], sys.argv[2]
    print(f"{'Sembrando' if accion=='--sembrar' else 'Borrando'} 3 cuentas de pega para {mio[:8]}…")
    (sembrar if accion=="--sembrar" else borrar)(mio)
    print("Hecho." + (" NO OLVIDES --borrar tras las capturas." if accion=="--sembrar" else ""))
