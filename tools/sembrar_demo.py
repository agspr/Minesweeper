"""Siembra un estado de progreso creíble en el simulador, para capturas.

NO toca el código de la app ni la base de datos real: escribe directamente las
preferencias del contenedor del simulador (NSUserDefaults, claves con prefijo
`flutter.` porque así las guarda shared_preferences en iOS). Reversible del
todo: borrar la app del simulador lo deshace.

**Con el simulador APAGADO.** Con el aparato encendido `cfprefsd` cachea las
preferencias y machaca el fichero al arrancar; `simctl spawn ... defaults
write` tampoco sirve, escribe en el dominio del sistema y no en el contenedor
de la app. Apagar → sembrar → arrancar → abrir.

    python3 tools/sembrar_demo.py <udid> es      # o en

Lo que deja:
- Sesión de invitado (`auth.guest`), sin anuncios (`iap.adsRemoved`: el estado
  real de quien compró «Quitar anuncios») y el idioma pedido.
- Racha viva de 12 días que acaba AYER, para que la diaria de hoy esté por
  jugar en el menú; mejor racha anterior de 19; una derrota dentro de la racha
  (en Minesweeper perder por tres minas la conserva) y dos días a medias.
- La diaria de HOY a medias y la práctica en DIFÍCIL a medias. Ninguna casilla
  está inventada: se parte de la casilla segura del tablero, se abre en
  cascada como en la app y se avanza solo con deducciones FORZADAS (si una
  pista ya tiene todas sus minas, el resto se abre; si sus ocultas son tantas
  como su número, son minas). Es una posición a la que se llega jugando, con
  cero minas detonadas — el contador marca 0 de verdad.
"""
import datetime, json, math, os, plistlib, subprocess, sys

BUNDLE = "com.sendallc.minesweeper"
APP = os.path.join(os.path.dirname(__file__), "..", "app")

if len(sys.argv) < 3 or sys.argv[2] not in ("es", "en"):
    sys.exit("uso: sembrar_demo.py <udid> es|en")
UDID, IDIOMA = sys.argv[1], sys.argv[2]
# El simulador usa el reloj del Mac: «hoy» es el de aquí.
HOY = datetime.date.today()

# ── las reglas de la app (scoring.dart, difficulty.dart) ──────────────────
BASE = {"easy": 50, "medium": 100, "hard": 150}
MEDIDAS = {"easy": (8, 8), "medium": (9, 12), "hard": (10, 14)}  # (cols, filas)


def redondear(x):
    # Dart `.round()` parte los medios hacia arriba; el `round` de Python los
    # manda al par (22.5 → 22). Con la penalización del 15 % salen medios.
    return math.floor(x + 0.5)


def dificultad(d):
    # difficulty.dart: L-X-V fácil, M-J medio, S-D difícil (weekday(): lunes=0).
    return ["easy", "medium", "easy", "medium", "easy", "hard", "hard"][d.weekday()]


# ── la historia ───────────────────────────────────────────────────────────
dias = {}


def poner(fecha, completed=True, lost=False, mistakes=0, percent=100, seconds=150):
    dif = dificultad(fecha)
    base = BASE[dif]
    if completed:
        pts = base - redondear(base * 0.15 * min(mistakes, 3))
    elif lost:
        pts = redondear(base * 0.15)
    else:
        tramo = next(f for m, f in [(75, .40), (50, .30), (25, .20), (1, .10)] if percent >= m)
        pts = redondear(base * tramo)
    r = {"points": pts, "completed": completed, "mistakes": mistakes,
         "percent": percent, "difficulty": dif, "seconds": seconds}
    if lost:
        r["lost"] = True
    dias[fecha.isoformat()] = r


AYER = HOY - datetime.timedelta(days=1)
# Racha viva: 12 días hasta ayer. Los tiempos van con la dificultad de cada día.
TIEMPO = {"easy": [96, 121, 88, 140, 105], "medium": [212, 265, 238, 301],
          "hard": [452, 517, 488, 610]}
fallos = [0, 1, 0, 0, 2, 0, None, 1, 0, 0, 1, 0]  # None = derrota (3 minas)
for i in range(12):
    f = AYER - datetime.timedelta(days=11 - i)
    t = TIEMPO[dificultad(f)][i % len(TIEMPO[dificultad(f)])]
    if fallos[i] is None:
        poner(f, completed=False, lost=True, mistakes=3, percent=64, seconds=233)
    else:
        poner(f, mistakes=fallos[i], seconds=t)

# Hueco de 3 días (ahí se rompió la racha anterior), con dos a medias.
poner(AYER - datetime.timedelta(days=12), completed=False, percent=58, seconds=140)
poner(AYER - datetime.timedelta(days=14), completed=False, percent=81, seconds=260)

# La mejor racha: 19 seguidos, antes del hueco.
for i in range(19):
    f = AYER - datetime.timedelta(days=15 + i)
    t = TIEMPO[dificultad(f)][(i + 2) % len(TIEMPO[dificultad(f)])]
    poner(f, mistakes=[0, 1, 0, 2, 0, 0, 1, 0, 0, 3, 0, 1, 0, 0, 2, 0, 1, 0, 0][i], seconds=t)

total = sum(d["points"] for d in dias.values())


# ── un tablero a medias, jugado con lógica ────────────────────────────────
def a_medias(solucion, inicio, dif, objetivo):
    """Avanza desde `inicio` con deducciones forzadas hasta abrir `objetivo` de
    las casillas seguras. Devuelve (entries, notes, jugadas)."""
    cols, filas = MEDIDAS[dif]
    sol = [int(c) for c in solucion]
    n = len(sol)
    assert n == cols * filas, (n, cols, filas)
    vec = []
    for c in range(n):
        r, k = divmod(c, cols)
        vec.append([rr * cols + kk for rr in range(r - 1, r + 2) for kk in range(k - 1, k + 2)
                    if 0 <= rr < filas and 0 <= kk < cols and (rr, kk) != (r, k)])
    abierta, bandera = [False] * n, [False] * n
    seguras = sum(1 for v in sol if v != 9)
    jugadas = 0

    def abrir(c):
        # Como la app: una pista 0 abre en cascada a sus vecinas.
        assert sol[c] != 9, f"la deducción abrió una mina en {c}"
        pila = [c]
        while pila:
            x = pila.pop()
            if abierta[x] or bandera[x]:
                continue
            abierta[x] = True
            if sol[x] - 1 == 0:
                pila.extend(v for v in vec[x] if not abierta[v])

    def abiertas():
        return sum(abierta)

    abrir(inicio)
    jugadas += 1
    avanzó = True
    while abiertas() < objetivo * seguras and avanzó:
        avanzó = False
        for c in range(n):
            if not abierta[c] or sol[c] == 9:
                continue
            pista = sol[c] - 1
            ocultas = [v for v in vec[c] if not abierta[v]]
            marcadas = [v for v in ocultas if bandera[v]]
            libres = [v for v in ocultas if not bandera[v]]
            if not libres:
                continue
            if len(marcadas) == pista:
                for v in libres:
                    abrir(v)
                jugadas += 1
                avanzó = True
            elif len(ocultas) == pista:
                for v in libres:
                    assert sol[v] == 9, f"bandera en casilla segura {v}"
                    bandera[v] = True
                    jugadas += 1
                avanzó = True
            if abiertas() >= objetivo * seguras:
                break
    entries = "".join(str(sol[c]) if abierta[c] else "." for c in range(n))
    notes = ",".join("1" if bandera[c] else "0" for c in range(n))
    return entries, notes, jugadas, abiertas() / seguras, sum(bandera)


def banco(fecha):
    with open(os.path.join(APP, "assets", "bank", f"{fecha.year}.json")) as f:
        return json.load(f)[fecha.isoformat()]


hoy = banco(HOY)
d_entries, d_notes, d_jugadas, d_frac, d_flags = a_medias(
    hoy["solution"], hoy["start"], hoy["difficulty"], 0.55)

# La práctica en difícil: un tablero difícil del propio banco (sale del mismo
# generador que la práctica), el del último domingo.
domingo = HOY - datetime.timedelta(days=(HOY.weekday() + 1) % 7 or 7)
dificil = banco(domingo)
assert dificil["difficulty"] == "hard", dificil["difficulty"]
p_entries, p_notes, p_jugadas, p_frac, p_flags = a_medias(
    dificil["solution"], dificil["start"], "hard", 0.48)

# ── las claves ────────────────────────────────────────────────────────────
prefs = {
    "flutter.auth.guest": True,
    "flutter.iap.adsRemoved": True,
    "flutter.settings.locale": IDIOMA,
    # Sin esto, con datos sembrados la app se cree una instalación previa y
    # abre «Novedades» encima del menú.
    "flutter.novedades.version": "1.0.0",
    "flutter.progress.streak": 12,
    "flutter.progress.bestStreak": 19,
    "flutter.progress.totalPoints": total,
    "flutter.progress.lastPlayedDay": AYER.isoformat(),
    "flutter.game.nona.today": json.dumps({
        "day": HOY.isoformat(), "entries": d_entries, "notes": d_notes,
        "mistakes": 0, "seconds": 71, "jugadas": d_jugadas,
        "completa": False, "perdida": False,
    }),
    "flutter.game.nona.practice.difficulty": "hard",
    "flutter.game.nona.practice.mode": "senda",
    "flutter.game.nona.practice": json.dumps({
        "givens": "." * len(dificil["solution"]), "solution": dificil["solution"],
        "start": dificil["start"], "entries": p_entries, "notes": p_notes,
        "mistakes": 0, "hints": 0, "seconds": 214, "counted": True,
    }),
    "flutter.game.nona.practice.stats": json.dumps({
        "easy": {"j": 23, "c": 21, "b": 62},     # 1:02
        "medium": {"j": 12, "c": 10, "b": 148},  # 2:28
        "hard": {"j": 7, "c": 5, "b": 326},      # 5:26
    }),
}
for dia, r in dias.items():
    prefs[f"flutter.progress.day.{dia}"] = json.dumps(r)

resumen = (f"racha 12 · mejor 19 · {total} puntos · {len(dias)} días · "
           f"hoy {hoy['difficulty']} {d_frac:.0%} abierto, {d_flags} banderas · "
           f"práctica difícil {p_frac:.0%}, {p_flags} banderas · idioma {IDIOMA}")

# ── escribir en el contenedor del simulador ───────────────────────────────
estado = subprocess.run(["xcrun", "simctl", "list", "devices"], capture_output=True, text=True).stdout
if UDID in estado and f"{UDID}) (Booted)" in estado:
    sys.exit("El simulador está ENCENDIDO: apágalo (xcrun simctl shutdown) y repite.")
# `simctl get_app_container` solo contesta con el aparato ENCENDIDO, y aquí
# tiene que estar apagado: el contenedor se busca en disco por su propia ficha.
def contenedor():
    raiz = os.path.expanduser(
        f"~/Library/Developer/CoreSimulator/Devices/{UDID}/data/Containers/Data/Application")
    for guid in os.listdir(raiz) if os.path.isdir(raiz) else []:
        ficha = os.path.join(raiz, guid, ".com.apple.mobile_container_manager.metadata.plist")
        try:
            with open(ficha, "rb") as f:
                if plistlib.load(f).get("MCMMetadataIdentifier") == BUNDLE:
                    return os.path.join(raiz, guid)
        except (OSError, plistlib.InvalidFileException):
            continue
    return None


cont = contenedor()
if cont is None:
    print("La app no está instalada en ese simulador. Instálala y repite.")
    print(f"El guion sería: {resumen}")
    sys.exit(2)
plist = os.path.join(cont, "Library", "Preferences", f"{BUNDLE}.plist")
actual = {}
if os.path.exists(plist):
    with open(plist, "rb") as f:
        actual = plistlib.load(f)
actual.update(prefs)
os.makedirs(os.path.dirname(plist), exist_ok=True)
with open(plist, "wb") as f:
    plistlib.dump(actual, f)
print(f"Sembrado en {plist}")
print(f"  {resumen}")
