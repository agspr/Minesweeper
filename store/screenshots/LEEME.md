# Capturas de tienda de Minesweeper — 23/24-11-2026

**20 capturas, subidas a las dos tiendas el 24-11-2026** (App Store: es-MX y
en-US; Play: es-419 y en-US, las de iPhone como teléfono y las de iPad como
tablet de 10"). Sustituyen a las de Nona, que seguían aquí desde la conversión.

| | iPhone 6.9" (1320×2868) | iPad 13" (2064×2752) |
|---|---|---|
| **en** | 6 | 4 |
| **es** | 6 | 4 |

Tamaños verificados por cabecera PNG: coinciden **exactos** con lo que exige
Apple para 6.9" y 13".

## Qué enseña cada una

| Fichero | Qué enseña |
|---|---|
| `01-menu` | Menú con las fichas BUSCA/MINAS (MINE/SWEEPER) y la **racha de 12 días**; la diaria de hoy, por jugar |
| `02-daily-board` | La diaria de hoy (fácil, lunes) a medias: 3 banderas, 7 minas por marcar, **ninguna detonada** |
| `03-hard-board` | Práctica en difícil (10×14) a medias: 6 banderas, 22 por marcar, ninguna detonada |
| `04-stats` | Las seis tarjetas de estadísticas + la tabla de práctica (en iPad, también los colores) |
| `05-practice-themes` | Tabla de práctica por nivel + los cuatro colores *(solo iPhone: en iPad ya salen en `04`)* |
| `06-social` | Clasificación «Total» con tres amigos de pega: tú, 2.º con 2737 *(solo iPhone, 24-11-2026)* |

## Cómo se hicieron, para poder repetirlas

- **Progreso sembrado** con `tools/sembrar_demo.py <udid> es|en`, **con el
  simulador APAGADO** (con el aparato encendido `cfprefsd` machaca el plist al
  arrancar). El script encuentra el contenedor de la app en disco por su ficha,
  porque `simctl get_app_container` solo contesta con el aparato encendido.
- **Las casillas no están inventadas.** Los dos tableros salen del banco de la
  app (`assets/bank/2026.json`: la diaria de hoy y la del último domingo) y se
  avanzan desde la casilla segura con **deducciones forzadas** únicamente. Es
  una posición a la que se llega jugando, sin una sola mina detonada: por eso
  las tres vidas salen intactas.
- **Sin banner de anuncios**: `iap.adsRemoved` sembrado — el estado real de
  quien compró «Quitar anuncios». Sesión de invitado (`auth.guest`) y
  «Novedades» marcadas como vistas para que nada tape el menú.
- **Un idioma por pasada, sin resembrar**: Más → Idioma → ES/EN. Los números son
  los mismos en los dos.
- Simuladores **iPhone 18 Pro Max** e **iPad Pro 13-inch (M5)**, iOS 27.2, barra
  de estado fija con `simctl status_bar ... override --time 9:41`.
- **En el iPad, Ajustes → Multitarea y gestos → Apps a pantalla completa.** En
  «Apps en ventanas» (lo que trae el simulador) iPadOS pone el nombre de la app
  en la barra de estado y un tirador de redimensionar en la esquina, y salen en
  la captura. Y la app se abre desde el inicio, no desde Ajustes, o aparece
  «◀ Ajustes» arriba a la izquierda.
- **Un simulador cada vez.** Con poco disco, dos simuladores encendidos llevan la
  memoria al swap y el disco se vacía solo; el primer arranque del iPad baja
  además ~1,5 GB de recursos del sistema.

## Lo que NO hay, y por qué

- **Social en iPad.** El simulador de iPad se borró el 24-11-2026 para hacer
  sitio a la build 16; la de Social se hizo solo en iPhone.

## Cómo se hizo `06-social` (24-11-2026), para poder repetirla

1. Sembrar el simulador (`sembrar_demo.py`, apagado) y abrir la app.
2. **André inicia sesión con una cuenta de PRUEBAS**, nunca la suya: al entrar,
   la app sube los 33 días sembrados a esa cuenta, y la limpieza los borra.
3. Antes de sembrar amigos, comprobar que `usernames/ana_rivera` (y los otros
   dos) **no existen**: `amigos_demo.py` los escribe sin mirar y `--borrar` los
   borra — con el handle de alguien real, se lo quitaría.
4. `amigos_demo.py --sembrar <uid>`, captura en «Total» (en «Semana» la cuenta
   sale última con 50 puntos), Más → Idioma → EN, otra captura.
5. **Cerrar sesión en la app y cerrarla ANTES de `--borrar`**: con la sesión
   abierta, la próxima vez que se abra volvería a subir los días sembrados.
6. `amigos_demo.py --borrar <uid>` y comprobar en Firestore que no queda nada
   (perfiles, handles, amistades, días y resumen de `apps/minesweeper`).
- **El selector de nivel de la práctica.** Su copia sigue siendo la de Nona
  («pistas», «técnicas como pares y tríos», «givens / pairs and triples») y en
  inglés el conmutador sale en español («Senda (3 vidas)» / «Clásico (1 vida)»).
  No se enseña en la tienda hasta arreglarlo.
