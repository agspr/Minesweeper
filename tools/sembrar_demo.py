"""Siembra un estado de progreso creíble en el simulador, para capturas.

NO toca el código de la app ni la base de datos real: escribe directamente las
preferencias del contenedor del simulador (NSUserDefaults, claves con prefijo
`flutter.` porque así las guarda shared_preferences en iOS). Reversible del
todo: borrar la app del simulador lo deshace.
"""
import json, subprocess, datetime, plistlib, os, sys

# El simulador de 6.9" de Nona. `xcrun simctl list devices` si cambia.
UDID = "BA2DE285-F444-4FCF-9240-0BA406EF3B80"
BUNDLE = "com.nonaapp.nona"
HOY = datetime.date(2026, 8, 27)

# ── el guion de la historia ────────────────────────────────────────────────
# Racha viva de 12 días (hoy incluido), una mejor racha ANTERIOR de 19 para que
# "Mejor racha" no sea igual a la actual, y dos días abandonados a medias para
# que "Terminados" < "Días jugados" y "Errores por día" tenga un número real.
BASE = {'easy': 50, 'medium': 100, 'hard': 150}
# día de la semana → dificultad (§3): fin de semana más duro
def dificultad(d):
    return ['medium','easy','medium','easy','hard','hard','medium'][d.weekday()]

dias = {}
def poner(fecha, completed=True, mistakes=0, percent=100, seconds=600):
    dif = dificultad(fecha)
    base = BASE[dif]
    if completed:
        pts = base - round(base * 0.10 * min(mistakes, 5))
    else:
        tramo = 0.40 if percent >= 75 else 0.30 if percent >= 50 else 0.20
        pts = round(base * tramo)
    dias[fecha.isoformat()] = {
        'points': pts, 'completed': completed, 'mistakes': mistakes,
        'percent': percent, 'difficulty': dif, 'seconds': seconds,
    }

# racha viva: 12 días hasta hoy
fallos_recientes = [0,1,0,2,0,0,3,1,0,0,2,1]
tiempos = [412, 505, 388, 640, 455, 720, 833, 391, 470, 512, 605, 448]
for i in range(12):
    f = HOY - datetime.timedelta(days=11-i)
    poner(f, completed=True, mistakes=fallos_recientes[i], seconds=tiempos[i])

# hueco de 3 días (la racha anterior se rompió aquí), con dos abandonados
poner(HOY - datetime.timedelta(days=12), completed=False, percent=62, seconds=210)
poner(HOY - datetime.timedelta(days=14), completed=False, percent=81, seconds=340)

# la mejor racha: 19 días seguidos, antes del hueco
for i in range(19):
    f = HOY - datetime.timedelta(days=15+i)
    poner(f, completed=True, mistakes=[0,2,1,0,0,3,1,0,2,0,1,0,0,4,1,0,2,1,0][i],
          seconds=[520,610,470,580,430,700,660,395,505,540,480,620,455,760,530,410,590,500,465][i])

total = sum(d['points'] for d in dias.values())
terminados = sum(1 for d in dias.values() if d['completed'])

# ── las claves ────────────────────────────────────────────────────────────
prefs = {
    'flutter.progress.streak': 12,
    'flutter.progress.bestStreak': 19,
    'flutter.progress.totalPoints': total,
    'flutter.progress.lastPlayedDay': HOY.isoformat(),
    'flutter.game.nona.practice.stats': json.dumps({
        'easy':   {'j': 14, 'c': 12, 'b': 232},   # 3:52
        'medium': {'j': 9,  'c': 7,  'b': 496},   # 8:16
        'hard':   {'j': 5,  'c': 3,  'b': 1147},  # 19:07
    }),
}
for día, r in dias.items():
    prefs[f'flutter.progress.day.{día}'] = json.dumps(r)

# ── escribir en el contenedor del simulador ───────────────────────────────
cont = subprocess.run(['xcrun','simctl','get_app_container',UDID,BUNDLE,'data'],
                      capture_output=True, text=True)
if cont.returncode != 0:
    print("La app no está instalada en el simulador todavía.")
    print("Instálala primero (flutter run / install) y vuelve a correr esto.")
    print(f"\nMientras tanto, el guion sembrado sería:")
    print(f"  racha 12 · mejor 19 · {total} puntos · {len(dias)} días jugados · {terminados} terminados")
    sys.exit(2)

plist = os.path.join(cont.stdout.strip(), 'Library','Preferences',f'{BUNDLE}.plist')
actual = {}
if os.path.exists(plist):
    with open(plist,'rb') as f: actual = plistlib.load(f)
actual.update(prefs)
os.makedirs(os.path.dirname(plist), exist_ok=True)
with open(plist,'wb') as f: plistlib.dump(actual, f)
print(f"Sembrado en {plist}")
print(f"  racha 12 · mejor 19 · {total} puntos · {len(dias)} días jugados · {terminados} terminados")
