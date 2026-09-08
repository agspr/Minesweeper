# Telemetría de Nona: dónde se miran los fallos, y la trampa de mirarlos

Tres sistemas, y no se confunden:

| Qué | Dónde | Se declara en |
|---|---|---|
| Fallos nativos y de Flutter | **Crashlytics** (proyecto Firebase `cinco-fe5cc`) | `app/lib/main.dart` |
| Fallos con traza legible, sesiones, rendimiento | **Sentry** (org `senda-6q`, proyecto `nona`) | `app/lib/sentry_config.dart:12` y `main.dart:171-176` |
| Eventos de uso | **Firebase Analytics → GA4** | catálogo del paquete compartido |

Los tres se declaran e inicializan desde el día uno **aunque no haya a quién
mirarlos**: el coste de no hacerlo no es una función que falte, es **silencio**.
Nona ya lo hizo mal una vez (los SDK estaban, `Analytics.init()` no se llamaba
nunca) y tardó en verse.

---

## LA TRAMPA: el proyecto `nona` de Sentry tiene eventos de tres apps

**Todo lo que veas en el proyecto `nona` de Sentry sin filtrar está inflado, y
mezclado con otros dos juegos.** No falla, no da error: devuelve un número más
grande. Es la misma forma de trampa que la de BigQuery en
`../CINCO/docs/ANALYTICS.md`, y por eso se documenta igual.

### Por qué

Dos juegos de la familia llevaron el DSN de Nona embebido, cada uno por su
cuenta, y los dos se arreglaron el mismo día:

| Juego | Llevó el DSN de Nona hasta | Arreglado por | Versión entonces |
|---|---|---|---|
| **Minigrama** (`com.sendallc.crucimini`) | 3-9-2026 12:04 | `74a4327` *"Sentry apunta al proyecto de Minigrama, no al de Nona"* | 1.0.16+17 |
| **Leo** (`com.sendallc.leo`) | 3-9-2026 13:53 | `37e4e8e` *"Leo reportaba a los proyectos de Nona y de CINCO"* | 1.0.10+12 |

Los dos commits cambiaron **las dos mitades a la vez**, que es lo correcto: el
`defaultValue` del DSN en `sentry_config.dart` (a dónde van los *eventos*) y el
`sentry: project:` del `pubspec.yaml` (a dónde van los *símbolos*). Una sola
mitad deja el sistema mintiendo de forma más difícil de ver.

Hoy los tres DSN son distintos y coherentes (comprobado el 8-9-2026):

```
Nona       Nona/app/lib/sentry_config.dart:12       …ingest.us.sentry.io/4511975097368576
Minigrama  Minigrama/app/lib/sentry_config.dart:18  …ingest.us.sentry.io/4512023264165888
Leo        Leo/app/lib/sentry_config.dart:24        …ingest.us.sentry.io/4512023265542149
```

El prefijo `o4511451179581440` es **la organización**, común a toda la familia:
que coincida no prueba nada. Lo que distingue el destino es el número final y la
clave pública. El paquete compartido `juegos_senda` **no** trae ningún DSN
embebido, así que no hay ninguna vía por la que una app herede el de otra en
ejecución: cada DSN se puso a mano en cada repositorio, y por eso se pudo copiar
mal a mano dos veces.

### Cómo se filtra

En la búsqueda de Sentry, sobre el proyecto `nona`:

```
release:com.nonaapp.nona@* environment:production
```

- **`release:`** funciona porque `main.dart:171-176` **no** fija
  `options.release`, así que el SDK la deriva del paquete:
  `<identificador>@<version>+<build>` — de ahí que la liberación de la 28 se
  llame `com.nonaapp.nona@1.0.1+28`. Los eventos ajenos vienen como
  `com.sendallc.crucimini@…` y `com.sendallc.leo@…`, y se caen solos con este
  filtro.
- **`environment:production`** porque `main.dart:174` pone `debug` en las builds
  de depuración **y las envía igual**: tus propias pruebas locales están ahí
  dentro.

### Lo que el filtro NO arregla

**Los eventos sucios no pararon el día del arreglo, y siguen llegando.** Lo que
manda eventos es la copia **instalada**, no el código de hoy:

- De Minigrama, **toda build anterior al 3-9 12:04**, no solo la +17. La ventana
  sucia es más ancha que un número de build, y además el `+17` existió a los dos
  lados del arreglo (la versión 1.0.16+17 vivió trece commits, del 1-9 al 3-9), o
  sea que "+17" no equivale a "sucia". El propio mensaje del commit que subió a
  la +18 dice que *"el 17 ya está gastado en pruebas internas"*: esas
  instalaciones seguirán mandando a Nona hasta que se actualicen.
- De Leo, **toda build ≤ +12**. Hoy va por 1.0.10+16.

Así que un pico de fallos "de Nona" fechado antes de que esas instalaciones se
actualicen puede no ser de Nona. Filtra siempre; y si un issue viejo mezcla
apps, mira las liberaciones que lo componen antes de sacar conclusiones.

### Lo que no se ha comprobado, y se dice en vez de suponerlo

Todo lo anterior está verificado **en disco**: ficheros, líneas y commits. Lo
que **no** se ha podido comprobar desde aquí es lo que pasa del lado de Sentry —
que los eventos ajenos aparezcan de verdad en el proyecto, cuántos son, o qué
issues concretos mezclan apps. El MCP de Sentry pide autorización OAuth y estas
sesiones no son interactivas: hay que hacerlo desde una con `/mcp`.

---

## La red que protege esto

| | Prueba que lo vigila |
|---|---|
| **Nona** | `app/test/telemetria_test.dart:63-82` — que el DSN tiene default real, y que el pubspec dice `project: nona`, `org: senda-6q`, `upload_debug_symbols: true` |
| **Minigrama** | `app/test/telemetria_test.dart:~101-125` — además comprueba que su DSN **no** contenga la clave ni el id de proyecto de Nona |
| **Leo** | **ninguna.** Trece ficheros en `app/test/` y ni uno de telemetría: su DSN correcto está protegido solo por un comentario |

Dos apuntes, y ninguno se toca desde aquí:

- **Leo no tiene red.** Es su repositorio, no este. Queda escrito para que quien
  lo lleve lo sepa: fue el segundo juego que reportó a Nona, y hoy nada impide
  que vuelva a pasar.
- **La prueba de Nona podría ser más estricta.** Hoy comprueba que el DSN
  contiene `ingest.us.sentry.io`; no comprueba que sea **el de Nona**. Si alguien
  pegara aquí el DSN de CINCO, la prueba seguiría verde. Una línea lo cierra:

  ```dart
  // El id de proyecto de Nona. Sin esto, un DSN de otro juego de la familia
  // pasa la prueba: todos terminan en ingest.us.sentry.io.
  expect(cfg, contains('/4511975097368576'));
  ```

## Los símbolos

Van con el build, no aparte: `dart run sentry_dart_plugin` después de compilar,
y el detalle está en `CONSTRUIR.md`, paso 3. Lo que importa recordar aquí es que
**nadie guarda el resultado de esa subida**, así que "los símbolos están
subidos" es siempre un autoinforme hasta que alguien mira Debug Files en la
consola. Por eso los `.symbols` de Dart se guardan también en
`~/Nona-releases/simbolos/`.
