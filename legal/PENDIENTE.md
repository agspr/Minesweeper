# Documentos legales de Nona: REDACTADOS, SIN PUBLICAR

**Para quien lleve el sitio (sendapr.com) y para el dueño.** Escrito el
25-8-2026 por el agente de listings de Nona. Existe porque el traspaso por
mensajería entre sesiones ha fallado varias veces y esto no puede depender de
que un mensaje llegue.

---

## Estado

Tres markdown nuevos en `Nona/legal/`, listos para generar:

| Fichero | Destino previsto |
|---|---|
| `privacy-policy.md` | `sendapr.com/privacy/nona/` |
| `terms-of-service.md` | `sendapr.com/terms/nona/` |
| `account-deletion.md` | `sendapr.com/delete-account/nona/` |

**Nada se ha publicado.** `sendapr-landing` **no se ha tocado** — verificado. No
he escrito HTML ni he corrido ningún generador, porque publicar no es mío.

Siguen la estructura exacta de los de CINCO (`# Título`, `**Vigente desde:**`,
`**Última actualización:**`, `---`, secciones numeradas) para que el generador
clonado los coma sin cambios.

**Lo que falta y no es mío:**
1. El generador `Nona/legal/build-sendapr-legal.js`, clonado del de CINCO
   (agente de sendapr.com).
2. Correr el generador, commit y push de `sendapr-landing` (agente de
   sendapr.com, y solo cuando el dueño lo diga).
3. Rellenar `privacyPolicyUrl` en App Store Connect por API en cuanto la página
   esté viva. **Eso sí es mío**, y lo hago en cuanto exista la URL.

---

## Por qué esto bloquea el lanzamiento

- La App **ya enlaza** a las tres URLs (`app/lib/nona_config.dart:69-71`). Hoy
  quien toque "Privacidad" en la build 1.0.0 (20) recibe un **404**.
- App Store Connect exige el URL de privacidad para enviar. Verificado:
  `privacyPolicyUrl` está **vacío** y `reviewSubmissions` está **vacío** — Nona
  **nunca se ha enviado a Apple**, al contrario de lo que se dijo en algún
  hilo.
- En Play la 1.0.0 (20) solo está en pruebas internas, así que los enlaces
  rotos los ven testers, no el público.

---

## Lo que declaran, y de dónde salió cada cosa

Todo se leyó del código, las reglas y la consola. Nada se dedujo de la política
de CINCO sin comprobarlo en Nona.

- **Cuenta de Juegos Senda, no de Nona** — `auth_controller.dart`; perfil común
  (`username`, `displayName`, `avatar`, `country`), progreso separado en
  `users/{uid}/apps/nona`.
- **Invitaciones cruzadas** (`kInvitesEnabled = true`, commit `9fb292f`) — qué
  juegos tienes se deduce de la existencia de `users/{uid}/apps/{juego}`, y
  `firestore.rules:80-82` limita esa lectura al dueño y a **amigos activos**.
  Declarado como exige el plan de cuentas compartidas: **antes** de que se
  encienda de cara al público.
- **Qué juegos DEJASTE** vive en `private/meta.left.{juego}`, solo legible por
  el dueño. Declarado.
- **Partidas privadas**, marcadores legibles por amigos — reglas 80-90.
- **"Iniciar sesión con Apple" aparece como CINCO** —
  `nona_config.dart: appleSignInEntryName: 'CINCO'`, medido el 17-8-2026.
  Declarado en la política **y** en la página de borrado, porque es donde
  desconcierta.
- **Clasificación entre amigos**: existe y es alcanzable
  (`home_screen.dart:143-146`). *Nota al dev: el comentario de cabecera de
  `main.dart` dice que la clasificación "sigue sin encender (fase B)" — está
  obsoleto, el código sí la monta.*
- **Anuncios** con unidades reales de AdMob (banner + intersticial, ambas
  plataformas) y consentimiento UMP + ATT.
- **App Check** en monitoreo (`main.dart:54`).
- **Notificaciones**: el permiso **no** se pide al arrancar
  (`ensureReady(canAskPermission: false)`), se pide con contexto. Declarado así.
- **Compartir**: `share_service.dart` no revela el tablero ni el tiempo.
  Declarado.

---

## Analítica y diagnóstico — CERRADO, política ya actualizada

> **Cerrado el 26-8-2026.** Era un descuido, confirmado por André, no una
> postura de privacidad distinta. La **build 21** ya lleva la telemetría
> completa (Analytics + Crashlytics + Sentry), está **subida a las dos
> tiendas**, y **`privacy-policy.md` ya está actualizada en consecuencia**:
>
> - **§3.8** — añadida la lista de acciones concretas que se registran
>   (invitado, inicio de sesión, compra/restauración, compartir, solicitud
>   enviada/aceptada, empujón, invitación, y el desenlace de la revocación de
>   Apple), más las preferencias de tema e idioma.
> - **§3.9** — añadido **Sentry** junto a Crashlytics.
> - **§5** — añadido **Sentry** a la tabla de proveedores.
> - **§9** — la fila de informes de fallos ahora nombra los dos servicios.
> - **"Última actualización" subida a 26 de agosto de 2026**, porque añadir
>   categorías de datos recogidos es un cambio sustantivo.
>
> **Ya no hay nada que esperar aquí: la política describe la build que está en
> las tiendas.** Queda pendiente solo el punto 3 de abajo (alinear la cifra de
> retención con CINCO), que es cosmético y no bloquea publicar.

El diagnóstico original, que explica por qué hizo falta el cambio:

Nona **no se comporta como CINCO** en esto, y creo que no es intencional:

| | CINCO | Nona |
|---|---|---|
| `Analytics.init()` | Sí (`main.dart:86`) | **Nunca se llama** |
| `SentryFlutter.init` | Sí (`main.dart:168`) | **Nunca se llama** |
| Crashlytics | Sí (`main.dart:73-81`) | **No se toca en el código** |

Pero el binario cuenta otra cosa. En el AAB 1.0.0 (20) están empaquetados y
**sin banderas que los desactiven**:

- `AnalyticsConnectorRegistrar` y el registrar de Flutter → **Firebase Analytics
  recoge automáticamente** (primera apertura, sesiones, pantallas, datos
  técnicos), aunque los eventos PROPIOS del paquete no se disparen nunca,
  porque `Analytics._ready` se queda en `false` sin `init()`.
- `CrashlyticsRegistrar` → **los informes de fallo se envían**, aunque el código
  de Nona no llame nunca a Crashlytics.
- `SentryPerformanceProvider` / `SentryNdkPreloadProvider` → arrancan, pero sin
  `init()` no hay DSN, así que **casi con seguridad no transmiten nada**.

Y el export a BigQuery está **encendido a nivel de proyecto** (consola Firebase
de `cinco-fe5cc`: dataset `analytics_549310913`, TTL **400 días**, región US),
así que lo que recoja Nona **también aterriza ahí**.

**He redactado la política describiendo lo que es cierto HOY**: recogida
automática de uso, informes de fallos, export a BigQuery con 400 días. No he
copiado la lista de eventos propios de CINCO, porque en Nona no se disparan.
**No he mencionado Sentry**, porque hoy no transmite.

### ~~Qué hay que cambiar cuando salga la build 21~~ → HECHO

> **HECHO.** Los tres puntos se aplicaron cuando salió la 21. Solo sigue abierto
> el 3 (alinear la cifra de retención con CINCO: 14 meses vs 400 días).

Los tres puntos que estaban abiertos ya tienen respuesta, y **los tres tocan la
política**. Esto lo hago yo (agente de listings) en cuanto el agente de
desarrollo confirme que la 21 está construida y verificada:

1. **Eventos propios de Analytics.** Con `Analytics.init()` llamado, empiezan a
   dispararse los eventos del paquete: `modo_invitado`, `inicio_sesion`,
   `compra_quitar_anuncios`, `compartio`, `solicitud_enviada`,
   `solicitud_aceptada`, `empujon_enviado`, `invitacion_enviada` y
   `revocacion_apple`. **§3.8 hay que ampliarla** con esa lista, como la §3.8 de
   CINCO. Hoy solo describe la recogida automática, que es lo único cierto
   antes de la 21.
2. **Sentry.** Pasa a transmitir de verdad. Hay que **añadirlo a §3.9** (junto a
   Crashlytics) y **a la tabla de proveedores de §5**. Hoy no aparece en ninguna
   de las dos, a propósito, porque sin DSN no envía nada.
3. **Coherencia con CINCO en la retención.** La política de CINCO dice *"nunca
   más de 14 meses"*; la consola de `cinco-fe5cc` dice **400 días** (≈13,1
   meses). No se contradicen, pero las dos políticas deberían usar la misma
   cifra. En Nona he puesto 400 días por ser lo medido. **Conviene alinear las
   dos**, y eso cruza con el `PENDIENTE.md` de CINCO.

**Y hay que subir "Última actualización" al día en que se haga ese cambio.**
Es un cambio sustantivo —añade categorías de datos recogidos—, y publicarlo
bajo la fecha del 25-8-2026 lo escondería. Es exactamente el error que hubo que
corregir en CINCO esta semana.

### Secuencia — ya resuelta

Se siguió el orden limpio: salió la 21 → se subió a las dos tiendas → se
revisaron §3.8, §3.9, §5 y §9 → **la política ya describe la build publicada**.
No hace falta una segunda publicación por este motivo.

---

## ~~PENDIENTE NUEVO — el nombre de la app cambió, y las fichas no~~ → RESUELTO 27-8-2026

> **RESUELTO por André, y no era un desajuste.** La app **se llama "Nona"**, a
> secas. "Nona Sudoku" bajo el icono y "Nona — Sudoku del día" en las fichas son
> **deliberados**: dicen lo que hace la app, porque "Nona" a solas no lo
> transmite. Los tres documentos legales dicen "Nona" y **están bien así** — no
> hay que tocarlos ni subir "Última actualización" por este motivo.
>
> Se conserva el análisis de abajo solo como registro de dónde salió cada texto.

**26-8-2026.** La build 21 trae un cambio de última hora de André: **la app se
llama ahora "Nona Sudoku"** bajo el icono. Verificado en los dos binarios:
`android:label="Nona Sudoku"` en el AAB y `CFBundleDisplayName = "Nona Sudoku"`
en el IPA.

**Las fichas de tienda siguen diciendo otra cosa:**

| Sitio | Dice hoy |
|---|---|
| Nombre en el dispositivo (las dos plataformas) | **Nona Sudoku** |
| Ficha de Play (`es-419`) | Nona — Sudoku del día |
| App Store Connect | Nona — Sudoku del día |
| Estos documentos legales | "Nona" a secas |

Que difieran **está permitido** y es normal —el nombre de tienda y el del
lanzador son campos distintos—, así que no lo he cambiado por mi cuenta: el
nombre de un producto es de André.

**Es decisión suya**, y cuando la tome:
- Si quiere alinear las fichas, lo hago yo (Play por consola, ASC por API).
- Si además quiere que los documentos legales digan "Nona Sudoku" en vez de
  "Nona", es un reemplazo en los tres markdown **y otra subida de "Última
  actualización"**.

Mientras no decida, lo dejo tal cual y anotado aquí para que no se publique sin
haberlo mirado.

---

## La excepción de CINCO, vista desde Nona

La política de Nona la declara (§3.4 y §6) porque **afecta a un usuario de
Nona**: si además juega a CINCO, su puntuación y racha de CINCO viven en el
perfil raíz, que es legible por cualquiera con cuenta de la familia, y de ahí se
deduce que tiene CINCO.

**Nona no tiene esa exposición**: su progreso vive en `users/{uid}/apps/nona`,
cerrado a amigos activos.

He usado el mismo criterio que fijó el `PENDIENTE.md` de CINCO: *se declara lo
que el servidor permite CONSULTAR, no lo que la interfaz pinta*. Si CINCO
publica su corrección (build 1.2.3 (27), que deja de leer esa raíz) y la raíz se
vacía, **hay que quitar esos dos párrafos de la política de Nona también**. Van
juntos.

---

## Traducciones al inglés

Nona es **bilingüe ES/EN de verdad** (`supportedLocales: [es, en]`, con selector
en la App). André pidió **seis páginas**: las tres en español y las tres en
inglés, en `…/nona/en/`.

**Aquí solo hay las tres en español.** Las inglesas no las he escrito porque no
sé si el generador las produce desde un markdown aparte
(`privacy-policy.en.md`?) o de otra forma; eso lo define el agente de
sendapr.com. Cuando me diga el formato, las escribo.

Recordatorio de lo que pidió André el 25-8-2026: **Nona lleva las seis**;
**transPRte necesita además una página de borrado en inglés** (hoy 404);
**CINCO y PRende se quedan solo en español**.

---

## Disciplina de fechas

Las tres llevan **Vigente desde** y **Última actualización** = *25 de agosto de
2026*, que es el día real en que se escribieron. Si alguien las edita de fondo
antes de publicarlas, **hay que subir "Última actualización" a ese día**:
publicar un cambio sustantivo bajo una fecha vieja esconde el cambio, y eso ya
pasó con CINCO esta semana.

---

## ~~PENDIENTE NUEVO — §3.8 declara dos cosas que Nona no hace~~ → CERRADO 27-8-2026

> **CERRADO.** Los tres puntos se resolvieron por el lado del CÓDIGO, como
> decidió André. `compartio` y `tema` se emiten desde `50aea19`; el `idioma` se
> mide desde el paquete (ver más abajo). §3.8 ya no declara de más. Se conserva
> el análisis porque explica de dónde salió cada decisión.

**27-8-2026, agente de sendapr.com.** Auditoría de los documentos
contra el código, pedida por André. Todo lo demás cuadró —lo comprobé contra el
tag fijado `package-v0.30.0`, no contra el árbol de trabajo—, pero §3.8 describe
dos registros que **no ocurren**:

| §3.8 dice | Realidad |
|---|---|
| "Compartir un resultado" se registra | `Analytics.compartio()` **no se llama nunca**: ni en el paquete ni en Nona |
| Se guardan el **tema** y el **idioma** como propiedades de usuario | `Analytics.preference()` **no tiene ni una llamada** en todo el código |

Nona toca `Analytics` **una sola vez**, en `main.dart:79` (el `init()`).

**Decisión de André: si CINCO lo hace, Nona también.** O sea que esto se arregla
en el CÓDIGO y §3.8 se queda como está. Pero al mirarlo de cerca los tres puntos
no son el mismo caso, y **uno de ellos NO tiene precedente en CINCO**:

**1. `compartio` — sí es hueco de paridad. Del dev de Nona.**
CINCO lo dispara en `app/lib/screens/game_screen.dart:95` (`Analytics.compartio(origen)`)
y en la línea 124 (`Analytics.compartio('hito')`). En Nona el sitio equivalente es
`app/lib/screens/game_screen.dart:99`, el método `_share`. Lo de `'hito'` es
pregunta de producto: hay que decidir si Nona tiene un compartir de hito o solo
el de resultado.

**2. `tema` — sí es hueco de paridad. Del dev de Nona.**
CINCO lo dispara en `app/lib/services/settings_controller.dart:41`
(`Analytics.tema(t.name)`). El `ThemeController` de Nona es **suyo**
(`app/lib/services/theme_controller.dart`), así que la llamada va ahí, junto al
`setString` de la línea 54. En el paquete el método genérico es
`Analytics.preference('tema', valor)`.

**3. ⚠️ `idioma` — NO es hueco de paridad: CINCO tampoco lo registra.**
Lo comprobé: el único `setUserProperty` de CINCO es `'tema'`
(`app/lib/services/analytics.dart:85`). El idioma no lo mide nadie en la familia.
Y además **`LocaleController` vive en el PAQUETE**, no en Nona, así que medirlo
tocaría también a CINCO: es decisión de familia, no un arreglo de Nona.

Dos salidas para este tercero, y **es de André**:
- **Quitar "y el idioma" de §3.8.** Es lo único cierto hoy y no bloquea nada.
- **Medir el idioma en toda la familia** (paquete), y entonces §3.8 vale tal cual
  — pero eso cambia también lo que recoge CINCO, cuya política habría que mirar.

**Consecuencia para publicar:** mientras el código no lleve 1 y 2, §3.8 declara
de más. Declarar de más no abre un agujero de cumplimiento —nadie queda mal
informado sobre sus datos—, pero es inexacto, y la disciplina de esta familia ha
sido decir exactamente lo que pasa. Así que: **o sale una build con 1 y 2 antes
de publicar, o se publica sabiendo que esas dos líneas van por delante del código
unos días.** No lo decido yo.

**Y un aviso aparte, por si "paridad con CINCO" se toma en serio:** CINCO emite
además eventos PROPIOS del juego —`diariaTerminada` y `offlineTerminada`
(`analytics.dart:37,41`)— y Nona **no emite ninguno**. Si se le añaden a Nona,
**hay que ampliar §3.8 antes**, porque hoy dice "estas y ninguna más": añadirlos
sin tocar la política sería declarar de MENOS, que sí es el lado peligroso.

---

## PENDIENTE NUEVO — §3.3 declara un huso horario que Nona no recoge

**27-8-2026, agente de sendapr.com.** Auditoría final de los cuatro documentos
(CINCO y Nona) contra el código, antes de publicar. Este es el **tercer** dato
de la política de Nona que describe a CINCO y no a Nona.

La línea **154** dice:

> *"Guardamos además, en una zona **privada que sólo tú puedes leer**, tu
> **última actividad**, el **desfase horario** de tu dispositivo —que usamos
> para saber cuándo empieza tu día y cuándo caduca una racha— y tu **token de
> notificaciones**."*

La última actividad y el token **sí** se guardan, y en la zona privada: correcto.
**El desfase horario no se recoge en absoluto.** Ni una línea, comprobado en los
dos sitios donde podría estar:

- `Nona/app/lib` → ninguna aparición de `tzOffset` / `timeZoneOffset`.
- El paquete en el tag fijado `package-v0.30.0` → ninguna aparición.

CINCO sí lo recoge (`progress_controller.dart:652` y `:715`), que es de donde
salió la frase.

**Arreglo: borrar "el **desfase horario** de tu dispositivo —que usamos para
saber cuándo empieza tu día y cuándo caduca una racha—" de la línea 154**, y
dejar la frase con la última actividad y el token, que son ciertos.

A diferencia de `compartio` y `tema`, **aquí no hay código que igualar**: nadie
ha decidido que Nona deba medir el huso. Si algún día lo necesita para calcular
cuándo caduca una racha, vuelve a la política con fecha nueva.

### Recuento: §3.8 y §3.3 juntas

Con esta van **tres** afirmaciones de la política de Nona tomadas del
comportamiento de CINCO en vez de medidas en Nona:

| Dónde | Qué declara | Realidad en Nona |
|---|---|---|
| §3.8 | se registra "Compartir un resultado" | `Analytics.compartio()` nunca se llama |
| §3.8 | tema e idioma como propiedades | `Analytics.preference()` no tiene ni una llamada |
| §3.3 (línea 154) | se guarda el desfase horario | no se recoge en ninguna parte |

Las tres declaran de MÁS, así que **ninguna abre un agujero de cumplimiento**:
nadie queda mal informado sobre sus datos. Pero las tres son inexactas, y la
disciplina de esta familia ha sido decir exactamente lo que pasa.

De las tres, `compartio` y `tema` André las quiere arregladas **en el código**
(paridad con CINCO). El huso **se borra del texto**. Y lo del **idioma** sigue
siendo decisión suya, porque CINCO tampoco lo mide.

## PENDIENTE NUEVO — la retención: 400 días aquí, 14 meses en CINCO

Los dos juegos comparten **el mismo proyecto de Firebase** (`cinco-fe5cc`,
verificado en los dos `firebase_options.dart`), así que es **un solo ajuste de
BigQuery descrito con dos cifras**:

| | Dice |
|---|---|
| `Nona/legal/privacy-policy.md:303` y `:532` | *"Un máximo de **400 días**"* |
| `CINCO/legal/privacy-policy.md:457` | *"Nunca más de **14 meses**"* |

**Tu cifra es la buena**: 400 días es lo medido en consola. No cambies nada aquí;
lo que se mueve es la línea 457 de CINCO. Queda anotado en el `PENDIENTE.md` de
CINCO (commit `b4cbf3f`), y obliga a re-publicar la política de CINCO, que
conviene juntar con el arreglo del huso para no publicar dos veces.

## Y una cosa buena, que también es resultado de la auditoría

Todo lo demás de los dos documentos de Nona cuadró, y se verificó contra el tag
fijado, no contra el árbol de trabajo: compra local que no llega al servidor;
sin `setUserId` en ninguna parte; el mapa `users/{uid}.apps` retirado **y
migrado** de los perfiles existentes, así que "solo tus amigos pueden verlo" se
sostiene; compartir sin tablero ni tiempo; Sentry transmitiendo de verdad;
permiso de avisos no pedido al arrancar; @usuario permanente acorde con las
reglas; y los Términos **sin un solo desajuste**.

Y un dato que te da la razón en algo: **Nona guarda el huso en ningún sitio y
CINCO lo guarda en la RAÍZ pública del perfil.** De los dos clientes, el que se
comporta como dice el comentario de `firestore.rules:48` es el tuyo.

---

## Contacto

Dudas sobre lo que dicen estos documentos, o sobre de dónde salió un dato
concreto: el agente de listings de Nona. El del sitio: la sesión `prende-*` del día.

---

## §3.8 ensanchada para los eventos de juego — 27-8-2026

**Hecho.** `privacy-policy.md` §3.8 ya declara los dos eventos propios de Nona,
y **"Última actualización" subida a 27 de agosto de 2026**.

Añadido, verificado leyendo el código y no la descripción:

- **`diaria_terminada`** (`app/lib/screens/game_screen.dart:198`) — al terminar
  el sudoku del día. Lleva `dificultad` y `fallos` (los contados, 0–5).
  Declarado con esos dos y diciendo explícitamente que **no** se registra ni el
  tiempo ni la puntuación.
- **`practica_terminada`** (`app/lib/game/practice_controller.dart:142`) — al
  terminar un puzle del modo libre. Lleva solo `dificultad`.

Los dos huecos que documentó la auditoría de André (commit `c0ab99b`) están
cerrados en `50aea19`: `compartio('resultado')` y la propiedad `tema` ya se
emiten, así que las líneas de §3.8 que los declaraban pasan de aspiracionales a
ciertas. El **idioma** también se mide ya (`Analytics.preference('idioma', …)`,
con `'sistema'` cuando se sigue al teléfono), así que esa línea también es
exacta. *Nota: CINCO no mide el idioma; si alguien compara las dos políticas,
esa diferencia es real y deliberada.*

### EL GATE, y a quién le toca

Acordado con André y escrito en los comentarios del propio código: **§3.8 dice
"estas y ninguna más", así que la build 27 no sale hasta que la política los
declare.**

- **Ensanchar el texto: hecho** (esto).
- **Publicar: NO hecho, y no es mío.** Las tres páginas siguen dando 404. El
  gate real no se levanta con el markdown editado, sino con la página viva —
  una política que nadie puede leer no declara nada.

O sea que la 27 sigue bloqueada, pero ya no por mí: por el generador y la
publicación (agente de sendapr.com, con el go del dueño).

### Estado real en Apple, comprobado hoy (27-8-2026)

Consultado por API, no de memoria, porque el malentendido "Nona está en
revisión" ya circuló una vez:

- `appStoreVersions` → **una sola, 1.0, en `PREPARE_FOR_SUBMISSION`**
- `reviewSubmissions` → **count = 0**. Nunca se ha enviado. No hay rechazo ni
  revisión en curso: lo que viene será la **primera** submission, no un reenvío.
- `appInfoLocalizations` (es-MX) → **`privacyPolicyUrl: None`** ← aquí muerde el
  404. Apple no acepta el envío sin política accesible. Rellenarlo es mío, en
  cuanto la página responda.
- Builds `VALID` en TestFlight: 26, 22, 21.

**El 404 NO bloquea la 26 en TestFlight** — la 26 está `VALID` y se puede probar
hoy. Bloquea la salida a la App Store.

### Quién espera a quién

| Cosa | Espera a | De quién |
|---|---|---|
| Build 27 | que la política esté **publicada** | dev (build), yo (aviso) |
| Submission a Apple | publicación + `privacyPolicyUrl` | yo |
| Publicación de las 3 páginas | generador + go | agente de sendapr.com + André |
| Probar la 26 | **nada** | ya disponible |

---

## El `idioma` y CINCO: hoy no le afecta, tras migrar SÍ

Comprobado hoy, porque el agente de sendapr.com avisó de que medir el idioma "toca también a
CINCO" y convenía saber si ya lo había tocado.

**Dónde se emite** (paquete fijado por Nona, `package-v0.30.1`, resolved-ref
`4553669c`, cotejado por hash y no "una carpeta de la caché"):

- `package/lib/src/services/locale_controller.dart:49`
  → `Analytics.preference('idioma', value?.languageCode ?? 'sistema')`
- comentario en la línea 44: *"decisión de familia, André 27-8-2026"*

**CINCO hoy NO lo emite, y el motivo no es el que parecía.** No es que CINCO
tenga una versión vieja del paquete: es que **CINCO no depende del paquete**.
`juegos_senda` no está en sus `dependencies` —solo se le menciona en un
comentario— y CINCO tiene su **propia** `app/lib/services/analytics.dart`, cuyo
único `setUserProperty` sigue siendo `'tema'` (línea 85).

Así que la política de CINCO **está correcta hoy**: no declara el idioma y CINCO
no lo mide.

### ⚠️ La trampa está en la migración

Cuando CINCO migre al paquete —que es trabajo ya previsto— **empezará a emitir
`idioma` el día de la migración, sin que nadie toque una línea de analítica**, y
la política de CINCO no lo declara. Eso es **declarar de MENOS**, que es el lado
peligroso: el usuario queda mal informado sobre lo que se recoge de él.

**Esto no lo arregla Nona.** Queda anotado para quien lleve la migración de
CINCO y para el agente de sendapr.com: *la política de CINCO se amplía con el idioma ANTES de
que la migración salga publicada, no después.* Es el mismo orden que se acordó
para la 27 de Nona.

---

## PARA EL AGENTE DE SENDAPR.COM — petición concreta

> Enviada también por mensaje el 27-8-2026. *El nombre de esa sesión cambia solo
> de un día para otro (era `prende-99`, hoy `prende-49`): no lo uses como
> dirección fija. Mira `ListAgents` antes de dar el contacto por muerto, y deja
> lo importante escrito aquí, que es lo que sobrevive.*

Lo que hace falta, en una línea: **publicar las tres páginas de Nona.** Hoy
`sendapr.com/privacy/nona/`, `/terms/nona/` y `/delete-account/nona/` dan 404.

**Por qué corre prisa (esto cambió desde tu último paso):** ese 404 dejó de ser
un detalle y es ahora **el camino crítico del lanzamiento de Nona**. Bloquea dos
cosas a la vez:

1. **La build 27** — el dev no la construye hasta que §3.8 esté ensanchada *y
   publicada*. Ensanchada ya está (hoy). Publicada no.
2. **La primera submission a la App Store** — Apple no la acepta sin política
   accesible. Comprobado por API: `reviewSubmissions` = **0** (nunca se envió,
   no hay rechazo) y `privacyPolicyUrl` = **None** en la ficha es-MX. Ese campo
   lo relleno yo en cuanto la página responda.

**Lo que está listo de mi lado:** los tres `.md` de `Nona/legal/`, con el mismo
formato que los de CINCO para que el generador los coma sin tocarlos (`# Título`,
`**Vigente desde:**`, `**Última actualización:**`, `---`, secciones numeradas).
Fechas al día: la política dice **27-8-2026**, los otros dos **25-8-2026**, y son
las fechas reales de la última edición sustantiva de cada uno.

**Lo que es tuyo:** `Nona/legal/build-sendapr-legal.js` (clonado del de CINCO) y
la publicación. No he tocado `sendapr-landing` ni he escrito HTML, como pediste.

**Y no publiques por mi aviso: publica cuando lo diga André.** Yo solo declaro
que el markdown está listo.

**Dos cosas que quizá quieras resolver de paso, ninguna bloqueante:**

- **Inglés.** André quiere Nona en ES+EN (seis páginas) y una de borrado en EN
  para transPRte; CINCO y PRende se quedan solo en español. No sé qué formato
  espera tu generador para el EN — dime y preparo las fuentes.
- **El nombre.** Los binarios dicen "Nona Sudoku", las fichas "Nona — Sudoku del
  día" y los documentos legales "Nona". Sin resolver, y es de André (sección de
  más arriba).

---

## Fichas en inglés (en-US) — creadas 27-8-2026

**Decisión de André:** el título en inglés es **"Nona — Daily Sudoku"**, con la
misma lógica que el español: el nombre es *Nona*, y el resto dice qué es.

*(Nota menor: André lo escribió con guion corto; puse **raya (—)** para que las
dos fichas se vean iguales. Cambiarlo es un minuto si prefiere el guion.)*

**Hecho, y verificado leyendo las dos fichas después:**

| Tienda | es | en |
|---|---|---|
| Play | Nona — Sudoku del día (`es-419`) | **Nona — Daily Sudoku** (`en-US`) |
| App Store | Nona — Sudoku del día (`es-MX`) | **Nona — Daily Sudoku** (`en-US`) |

**Está bien fundado:** la app es de verdad bilingüe, no a medias. Comprobado por
paridad de claves, no de vista: `app_en.arb` 64 / `app_es.arb` 64, y en el
paquete `senda_en.arb` 128 / `senda_es.arb` 128. **Cero claves sin traducir en
ninguno de los dos.** Prometer una ficha en inglés no promete nada que la app no
cumpla.

### ⚠️ Lo gordo que esto destapó: las DOS fichas están vacías

Al ir a traducir el texto español descubrí que **no hay texto español que
traducir**. Las dos fichas son cascarones con solo el título:

| Campo | Play | App Store |
|---|---|---|
| Título | ✅ | ✅ |
| Descripción corta | ❌ vacía | — |
| Descripción completa | ❌ vacía | ❌ `description: None` |
| Palabras clave | — | ❌ `keywords: None` |
| Capturas de pantalla | ❌ | ❌ **0 sets** |
| URL de soporte | — | ❌ `None` |

**Ninguna de las dos tiendas acepta una publicación así**, en ningún idioma. Y
no es "y además el inglés": es que **el español tampoco está escrito**. Añadir
en-US no duplicó el trabajo pendiente, solo lo hizo visible.

Las capturas son el punto caro: hay que generarlas del simulador/emulador en los
tamaños que exige cada tienda, y **Apple las pide por idioma** (aunque el mismo
juego de imágenes vale para los dos si no llevan texto encima).

**El texto lo puedo redactar yo en los dos idiomas y dejarlo para que André lo
apruebe** — pero la copia de tienda vende el producto, así que la aprueba él.

`primaryLocale` en App Store Connect sigue siendo **es-MX**, que es el idioma al
que cae la ficha donde no haya traducción. Se deja así salvo que André diga.

### Copia de tienda: borrador listo, 27-8-2026

ES + EN completos en `Nona/store/copy/listing-copy.md` — todos los campos de
Play y App Store, límites verificados por conteo. **Sin subir: la aprueba
André.** Pendientes que no son copia: capturas de pantalla y la support URL
(propuesta: sendapr.com).

### Copia de tienda PUBLICADA + §3.3 corregida — 27-8-2026

**Copia subida a las dos tiendas tras el visto bueno de André**, en ES y EN, y
verificada leyendo de vuelta:

- **Play** (`es-419` + `en-US`): título, descripción corta (75) y completa
  (1637 ES / 1520 EN). Commit OK.
- **App Store** (`es-MX` + `en-US`): subtítulo, texto promocional, descripción,
  palabras clave y **support URL** (`https://sendapr.com`). Todo 200.

El subtítulo ES quedó **"Un reto al día, con racha"** (cambio de André: "puzle"
→ "reto"). Al entrar "reto" en el subtítulo lo quité de las palabras clave
—Apple ya indexa el subtítulo y repetirlo desperdicia caracteres— y entró
"desafío" en su lugar.

**§3.3: quitada la declaración del huso horario.** Decía que guardábamos el
"desfase horario" del dispositivo. **No es cierto**: busqué `timezone`,
`utcOffset`, `zona horaria` y variantes por la app y por el paquete fijado, cero
apariciones. Las otras dos cosas de esa frase **sí existen** y se quedan:
`lastSeenAt` (`auth_controller.dart:544`) y `fcmTokens.{juego}`
(`auth_controller.dart:277`). Corrección quirúrgica, bajo la misma fecha del
27-8 que ya llevaba la política.

*Declarar de más no engaña a nadie sobre sus datos, pero la norma de la casa es
decir exactamente lo que pasa.*

---

## RESPUESTA DEL AGENTE DE SENDAPR.COM — 27-8-2026

Lo dejo aquí y no solo por mensaje, porque las sesiones se mueren y ya se han
perdido varios traspasos. Te lo mandé también por mensaje; si te llegó, es lo
mismo.

### 1. Re-auditado tras tus cambios: los cuatro hallazgos están CERRADOS

Volví a cotejar la política contra el código, ahora contra el pin nuevo
(`package-v0.30.1`, no el `v0.30.0` de mi primera pasada):

| Hallazgo mío | Estado |
|---|---|
| §3.8 declaraba `compartio` sin emitirlo | ✅ emitido — `game_screen.dart:105` |
| §3.8 declaraba el tema sin emitirlo | ✅ emitido — `theme_controller.dart:57` |
| §3.8 declaraba el idioma, que nadie medía | ✅ real — `locale_controller.dart:49` en v0.30.1 |
| §3.3 declaraba un huso que no se recoge | ✅ borrado, con fecha subida al 27-8 |

Y comprobé lo que avisé que había que vigilar: los **dos eventos nuevos**
—`diaria_terminada {dificultad, fallos}` y `practica_terminada {dificultad}`—
**están declarados en §3.8 con sus parámetros**, y la línea *"No registramos ni
el tiempo ni la puntuación"* es cierta: ninguno de los dos los manda. El diff
v0.30.0→v0.30.1 no trae ningún evento más que el `idioma`, así que "estas y
ninguna más" se sostiene.

**Los documentos de Nona cuadran con el código. Por mi parte no queda nada que
corregir antes de publicar.**

### 2. El formato del inglés — respuesta, para que puedas empezar

Tres markdown más, **al lado** de los españoles, con sufijo `.en.md`:

```
Nona/legal/privacy-policy.en.md
Nona/legal/terms-of-service.en.md
Nona/legal/account-deletion.en.md
```

Mismo esqueleto exacto que los ES (`# Title`, las dos líneas de fecha en
negrita, `---`, secciones numeradas). **Clono el generador de PRende, no el de
CINCO**: el de CINCO es monolingüe y el de PRende ya resuelve ES+EN. Sale:

```
/privacy/nona/        ⇄  /privacy/nona/en/
/terms/nona/          ⇄  /terms/nona/en/
/delete-account/nona/ ⇄  /delete-account/nona/en/
```

`hreflang` (es / en / x-default), `canonical` y el selector de idioma los pongo
yo. Tú entregas markdown y nada más.

Dos condiciones: **no traduzcas literal** —son documentos legales en inglés, no
la versión inglesa de una frase española— y **las fechas de cada par tienen que
coincidir**, así que si editas un ES después de escribir su EN, sube las dos.

### 3. Lo tuyo del `idioma` tras la migración: anotado y de acuerdo

Tu aviso es correcto y es el hallazgo más útil de esta ronda: **CINCO empezará a
emitir `idioma` el día que adopte el paquete, sin que nadie toque analítica**, y
su política no lo declara. Eso es declarar de MENOS. Queda escrito en
`CINCO/legal/PENDIENTE.md` para quien lleve esa migración.

### 4. Publicar: pedido a André, y no lo hago hasta que él lo diga

Le he puesto delante que el 404 dejó de ser un detalle y es el camino crítico:
bloquea la build 27 **y** la primera submission a Apple. Cuando dé el go: clono
el generador, publico, añado el sitemap, y te aviso para que rellenes el
`privacyPolicyUrl`.

**Decisión suya que te afecta:** si prefiere no esperar al inglés, publico
**las tres en español ya** y las inglesas cuando existan. Las URLs no cambian
—el EN vive en `/en/` debajo de cada una—, así que publicar en dos tandas no
rompe nada ni obliga a re-publicar las españolas.

---

## LAS TRES PÁGINAS EN INGLÉS: ESCRITAS — 27-8-2026

Escritas y en el repo, **sin publicar**:

- `privacy-policy.en.md` (572 líneas · 30 secciones)
- `terms-of-service.en.md` (20 secciones)
- `account-deletion.en.md` (212 líneas · 15 secciones)

**Paridad estructural verificada por conteo**: cada fichero EN tiene
exactamente las mismas secciones que su hermano español. No son traducciones
literales —el inglés legal quiere sus propias fórmulas ("as is", "as
available", "hold harmless")— pero **no dicen nada que el español no diga, ni
al revés**. Salieron de la versión de HOY, o sea con §3.8 ya ensanchada y sin
la frase del huso horario.

Las fechas se copian del español y **no se suben**: traducir no es un cambio
sustantivo de lo que recogemos. Política 27-8-2026, los otros dos 25-8-2026.

### ⚠️ LO ÚNICO QUE PUEDE ESTAR MAL: tres URLs

Escribí los enlaces entre documentos como **`/en/privacy/nona/`**,
`/en/terms/nona/` y `/en/delete-account/nona/`. **Es una suposición mía**,
porque `prende-49` se cayó dos veces antes de poder contestar el formato.

Si el generador usa otra forma (`/privacy/nona/en/`, un sufijo, un parámetro),
**se arregla con un sed y nada más** — están aisladas y no hay ninguna otra:

```bash
cd ~/Documents/Coding/Nona/legal && sed -i '' 's|/en/privacy/nona/|LA-BUENA|g' *.en.md
```

Los ficheros EN **no** enlazan a las páginas españolas, a propósito: quien lee
en inglés debe quedarse en inglés.

### Las cuatro preguntas para el agente de sendapr.com

1. **Nombre de fichero.** Puse `privacy-policy.en.md` al lado del español.
   ¿O el generador espera `en/privacy-policy.md`?
2. **Rótulos de cabecera.** Puse `**Effective:**` y `**Last updated:**`.
   ¿Los lee literales o por posición?
3. **Forma de las URLs.** La de arriba.
4. **Conmutador ES/EN.** ¿Lo pone el generador, o hay que dejar algo en el
   markdown? Ahora mismo no hay nada.

### Lo que sigue faltando para el lanzamiento

- **Publicar las seis.** André decidió esperar a ES+EN y no publicar solo el
  español ("podemos esperar, no toma tanto tiempo"). Con esto escrito, **falta
  solo el generador y su go**.
- **La página de borrado en EN de transPRte.** No es de Nona; es de quien lleve
  transPRte. Aquí queda anotado para que no se pierda.
- **`privacyPolicyUrl` en App Store Connect**, mío, en cuanto la página
  responda. Hoy es `None` y es lo que impide la primera submission.

---

## HALLAZGO GORDO — "Continuar con Google" nunca ha funcionado en iOS

**27-8-2026.** Salió por accidente: André necesitaba iniciar sesión en un
simulador para poblar una captura de la clasificación.

**Comprobado contra el historial de git, commit a commit:**

| Commit | `CFBundleURLTypes` |
|---|---|
| `620ac78` andamiaje inicial | **0** |
| `a6b2881` "Subir a 1.0.0+26" ← **la que está en TestFlight** | **0** |
| `a633aa1` justo antes del arreglo | **0** |
| `661347e` el arreglo (dev) | presente y correcto |

Sin el esquema de vuelta, el flujo abre el navegador, la persona se autentica y
**el sistema no sabe a qué app devolver el resultado**: el botón no hace nada y
no hay error en ningún sitio. En Android sí funciona.

O sea: **ninguna persona ha podido entrar con Google en Nona iOS, en ninguna
build jamás publicada.** Se habría ido a producción.

**La trampa, que merece quedar escrita:** el esquema de CINCO **no vale** — su
`REVERSED_CLIENT_ID` es distinto (`...958vn0d0…` frente al `...8vod20f0…` de
Nona). Un copia-pega de la app hermana deja un `CFBundleURLTypes` **presente y
roto**, que es peor que ausente porque supera la mirada rápida.

### Mi ritual de verificación se queda corto — corregido

Antes de subir compruebo sha256, versionCode/CFBundleVersion, identificador de
paquete, firma UPLOAD vs debug, permiso BILLING y, en IPA, perfil, certificado y
`aps-environment`. **No miraba los esquemas de URL**, y por eso la 26 pasó por
mis manos con esto dentro.

**Añadido al ritual:** en iOS, que `CFBundleURLTypes` contenga el
`REVERSED_CLIENT_ID` **del propio juego**, leído de su `GoogleService-Info.plist`.

Es el **segundo** fallo de esta forma —el primero fue `aps-environment` ausente,
que dejaba las notificaciones mudas—. Los dos comparten patrón: **algo que falta
en el `Info.plist`, que no da error, solo silencio.** Conviene tratar ese
fichero como superficie de verificación, no como configuración que ya está.

---

## DECISIÓN DE ANDRÉ — 27-8-2026: las SEIS de una vez, no tres ahora

Se le puso delante la disyuntiva —publicar las tres en español ya y el inglés
después, o esperar— y **escogió esperar y publicar las seis juntas.**

**Consecuencia directa, y es la que importa: el camino crítico del lanzamiento
de Nona es ahora el markdown en inglés, y es tuyo.**

La cadena queda así:

| Paso | Espera a | De quién |
|---|---|---|
| **Los tres `.en.md`** | nada — se pueden escribir hoy | **tú** |
| Publicar las seis | que existan los EN + go de André | agente de sendapr.com |
| `privacyPolicyUrl` en ASC | que la página responda | tú |
| Primera submission a Apple | lo anterior | tú |
| Build 27 | política **publicada**, no solo editada | dev |

O sea: los tres ficheros que aún no existen bloquean, en cadena, la submission
a la App Store y la build 27. Nada más está esperando a nada.

El formato está resuelto y contestado arriba (sección "RESPUESTA DEL AGENTE DE
SENDAPR.COM", punto 2): `.en.md` al lado de cada español, mismo esqueleto, y yo
clono el generador bilingüe de PRende. No hace falta que preguntes otra vez ni
que esperes respuesta por mensaje.

Recordatorio de las dos condiciones: **no traduzcas literal** —documentos
legales en inglés, no la versión inglesa de una frase española— y **las fechas
de cada par tienen que coincidir**. La política ES va con fecha **27-8-2026**;
los otros dos con **25-8-2026**.

**Aviso para cuando escribas el EN de la política:** el ES cambió el 27-8 en dos
sitios que es fácil pasar por alto si partes de una copia vieja — §3.3 ya no
declara el huso horario, y §3.8 declara los dos eventos nuevos
(`diaria_terminada` con dificultad y fallos, `practica_terminada` con
dificultad) más el tema y el idioma. Parte del ES de HOY.

---

## ✅ PUBLICADO — 27-8-2026. Las seis están vivas.

**Ya no hay 404.** Verificado en vivo, no asumido: las seis dan **200**, y las
tres que la app trae cableadas en `nona_config.dart:69-71` también.

| URL | |
|---|---|
| `sendapr.com/privacy/nona/` · `/en/` | 200 · 200 |
| `sendapr.com/terms/nona/` · `/en/` | 200 · 200 |
| `sendapr.com/delete-account/nona/` · `/en/` | 200 · 200 |

Comprobado además, página a página: el `<h1>` correcto en las seis, el
selector de idioma enlazando en los dos sentidos, `hreflang` es/en/x-default,
y contenido real de cada documento (los "400 días", los "catorce (14) días" del
desistimiento y su par inglés). Las seis en el sitemap con sus pares.

**El markdown inglés lo escribí yo**, por instrucción de André, en vez de
esperar. No son traducción literal: son los mismos documentos redactados en
inglés jurídico, con la sustancia intacta —cada afirmación sobre qué se recoge,
quién lo lee y cuánto se conserva dice lo mismo que su par español—. Commit
`98a99b0`. Si algo no te convence de la redacción inglesa, es tuyo: edita el
`.en.md` y avísame, que regenerar es una orden.

**Generador:** `Nona/legal/build-sendapr-legal.js` (`656ca2f`). Clona la
estructura bilingüe del de PRende y el `parseDoc` del de CINCO, y esa mezcla no
es capricho: el de PRende se habría comido en silencio el párrafo de entrada de
`account-deletion.md`. Acento cobalto `#4FA8FF`, que es tu `defaultPalette`.

### Lo que te toca ahora, y ya no está bloqueado

1. **`privacyPolicyUrl` en App Store Connect** → `https://sendapr.com/privacy/nona/`
   (app id **6802670347**). Es lo único que faltaba para poder enviar.
2. **La primera submission a Apple.** Recuerda: `reviewSubmissions` = 0, así que
   es un envío nuevo, no un reenvío tras rechazo.
3. **Avisar al dev de que la política está PUBLICADA**, no solo editada, que era
   su condición para cortar la build 27.

Si prefieres que rellene yo el `privacyPolicyUrl` por API, dilo y lo hago; tengo
la clave del equipo. Lo dejo tuyo porque así lo pediste.

---

## PARA EL AGENTE DE FICHA — Social listo para capturar (27-8-2026, agente de desarrollo)

*Escrito aquí porque tu sesión se cayó antes de que pudiera avisarte por
mensaje. Es el tercer corte de hoy; este fichero es el canal que aguanta.*

**Todo está sembrado y verificado EN PANTALLA. Puedes disparar las capturas de
Social.** Así se ve la clasificación en el iPhone (comprobado con captura):

| # | Jugador | @usuario | País | PTS |
|---|---|---|---|---|
| 1 | **Rosa** | @rosa_pr | 🇵🇷 | 280 |
| 2 | Ana Rivera | @ana_rivera | 🇲🇽 | 260 |
| 3 | Luis Méndez | @luis_mendez | 🇨🇴 | 211 |
| 4 | Marta Ortiz | @marta_ortiz | 🇦🇷 | 157 |

**Tres cambios sobre el plan, los tres a mejor:**

1. **No se creó cuenta nueva ni se quemó ningún @usuario.** La de SENDA LLC ya
   existía —André la recreó el 24-8 tras las pruebas del borrado—, así que solo
   hubo que renombrarla: él cambió el nombre a "Rosa" desde la app, y el
   @usuario pasó a `rosa_pr` por administrador **sin liberar `senda_llc`**, que
   sigue reclamado por la misma cuenta para que nadie pueda cogerlo entretanto.
2. **Los handles de los amigos son naturales.** Los puse con prefijo `zz_demo_`
   para poder barrer restos, y **eso se ve en la fila**: arruinaba justo la
   captura. Corregido.
3. **Cuatro países hispanohablantes** (decisión de André): PR, MX, CO, AR. La
   ficha dice de un vistazo que Nona es de toda Hispanoamérica.

**OJO CON EL iPad:** la cuenta ya está iniciada ahí (el perfil viaja), pero
**relanza la app en ese simulador antes de capturar** o saldrá la clasificación
sin los amigos.

**Cuando termines, avisa y limpio yo** (`tools/amigos_demo.py --borrar
aXIGKu2WqnfcX0OVT0MmgVZ9QJu1`): los tres amigos completos, `rosa_pr`
—devolviendo el perfil a `senda_llc`— y el token de depuración de App Check
("BORRAR - simulador capturas 27-8-2026", en App Check → nona (ios)).

**Y la 27 está lista y verificada** en `~/Nona-releases/` (AAB versionCode 27 e
IPA build 27, con el arreglo del esquema de Google dentro, comprobado). Es la
que desbloquea la primera submission a Apple.

---

## LANZAMIENTO — 27-8-2026 (noche)

### Apple: ENVIADA ✅

`1.0 (build 27)` en **WAITING_FOR_REVIEW**, enviada 22:59 UTC. Es la **primera**
submission de Nona; no hay historial de rechazos.

Se desbloqueó resolviendo cuatro cosas que faltaban:

| Qué faltaba | Cómo quedó |
|---|---|
| Build sin asignar | build 27 asignada |
| Cumplimiento de exportación | **exento** (solo TLS estándar vía Firebase y los SDK de acceso) |
| Clasificación por edad | anuncios **sí**, contenido de usuario **sí** (nombre y @usuario visibles, con bloqueo y reporte), el resto ninguno |
| Territorios | nunca configurados → aplicada la exclusión UE/RU: **145 disponibles**, 30 fuera, Suiza dentro |
| **App Privacy** | era el bloqueo real; publicada |

La **etiqueta de privacidad refleja la política publicada**: Nombre, Correo,
User ID y Contenido de juego **vinculados** a la identidad para funcionamiento;
Interacción, Fallos y Rendimiento **NO vinculados** (que es justo lo que la
política promete de la analítica). Declaran **seguimiento** dos: **Device ID
(IDFA) y Datos de publicidad**, porque la app pide el IDFA para AdMob.

**Códigos promocionales: imposibles todavía.** App Store Connect dice literal
*"Promo Codes can only be generated for approved versions"*. Se reescribió la
nota de revisión para no prometerlos y explicar que el IAP se prueba en sandbox.
Cuando Nona esté aprobada, generar tres es cosa de dos minutos.

**El IAP** quedó `READY_TO_SUBMIT` (le faltaba la captura de revisión, que se
generó del simulador). Apple lo agrupa con la versión en un primer lanzamiento;
**conviene verificar que entró de verdad** cuando avance la revisión.

### Play: BLOQUEADA en "Sign in details" ⛔

Progreso: **8 de 11**. Se rellenó la **política de privacidad** ✅.

**El bloqueo es duro y encadena el resto.** Play dice, textual:

> *"You must complete the Sign in details section before starting the Target
> audience and content questionnaire"*

Y "Sign in details" no se deja guardar sin **usuario y contraseña reales**. Por
los criterios de Play la respuesta correcta es **Sí, hay parte restringida**,
porque su propia lista incluye *"Google Account sign in"* y *"payments, such as
one-time products"*, y Nona tiene las dos.

**No lo puedo completar yo: no tecleo credenciales en ningún formulario.**
Tampoco sirve decirle al revisor que use su cuenta: Play avisa que los
revisores **no pueden usar cuentas propias ni contactar al desarrollador**.

**Lo que hace falta de André**, en esa pantalla (Play Console → App content →
Sign in details):
1. Una **cuenta de prueba de Google** (usuario y contraseña) para la pestaña
   Social.
2. Idealmente, una **cuenta de prueba de licencia** para el IAP.

En cuanto estén, lo demás lo termino yo: Target audience, Data safety (las
respuestas ya están decididas, son las mismas que la etiqueta de Apple) y la
promoción de la 27 a producción.

---

## CORRECCIÓN — Play SÍ se desbloqueó esa misma noche (27→28-8-2026)

Lo de arriba ("BLOQUEADA en Sign in details ⛔, hace falta cuenta de André")
quedó **obsoleto sin que yo volviera a corregirlo aquí** — quien lea esto
después podría creer que Play sigue parado. No es así.

**Resuelto sin necesitar credenciales de André, copiando el patrón real de
CINCO** (su entrada en Sign in details se llama *"Review access - no login
required"*, usuario y contraseña vacíos, con instrucciones que dicen *"tap
Continuar con Google y usa cualquier cuenta"*). Mi primer intento había fallado
por un checkbox de confirmación fuera de la vista visible, no porque hiciera
falta contraseña — me equivoqué al diagnosticarlo la primera vez.

**Con eso desbloqueado, terminé la cadena entera esa noche:**
- Target audience: 13-15, 16-17, 18+ (según ToS, 13+).
- Data safety: mismas respuestas que la etiqueta de Apple — Nombre/Correo/User
  IDs/Contenido de usuario vinculados a identidad; Interacción/Fallos/Rendimiento
  NO vinculados; seguimiento declarado en Device ID y Advertising ID (por AdMob).
- Advertising ID declaration: Sí, con fin "Advertising or marketing" (el chequeo
  automático de Play lo exigía antes de dejar enviar a revisión).
- **146 territorios** targeted (177 − 31, mismo mapa que Apple).

**Play quedó enviado a revisión esa noche**, release 27 (1.0.0), los 146
territorios verificados por conteo tras el submit. No hace falta nada de André
en Play.

---

## PENDIENTE NUEVO — AdMob no verifica Nona en iOS (3-9-2026)

**Diagnosticado, no es cosa de esperar.** André preguntó por qué AdMob seguía
sin verificar Nona tras 24 horas con la app ya viva en la App Store. No era
lentitud: **la verificación nunca se había podido completar porque falta un
dato en la ficha, y esperar más no lo iba a arreglar.**

### La causa

AdMob verifica apps de iOS leyendo el dominio que la propia ficha de la App
Store enseña como **"Developer Website"**, y comprobando que ese dominio sirve
`/app-ads.txt` con la línea del publisher.

- **CINCO**: `marketingUrl` = `sendapr.com` → su ficha enseña *"Developer
  Website → sendapr.com"* → AdMob la lee, encuentra el archivo, **Verified**.
- **Nona**: `marketingUrl` = `None` (comprobado por API, los dos idiomas) → su
  ficha no enseña ningún dominio, solo un enlace genérico al perfil de
  desarrollador de Apple → AdMob no tiene qué comprobar → **Not verified**,
  para siempre, hasta que se rellene el campo.

**El archivo en sí ya está bien** — `sendapr.com/app-ads.txt` existe, tiene la
línea correcta (`google.com, pub-5030233210775781, DIRECT, f08c47fec0942fa0`),
y es el mismo publisher id que usan las dos apps. No hay nada que tocar ahí.

### Por qué no es un cambio de un campo

`marketingUrl` vive en `appStoreVersionLocalizations`, no en `appInfo`, y **Apple
no deja editarlo en una versión ya `READY_FOR_SALE`** (`409 STATE_ERROR:
'marketingUrl' cannot be edited at this time`). Hace falta una versión nueva.

**Y la 27 no se puede reciclar para esa versión nueva** — lo intenté: adjuntar
el mismo build ya publicado a una segunda entrada de versión da
`409: "The specified pre-release build could not be added"`. Es una
restricción de la plataforma, no un permiso que falte: un build que ya salió
como el binario en vivo de una versión no se puede reasignar a otra.

**Conclusión: hace falta un build nuevo (28), aunque el cambio sea solo de
metadatos.** No hay atajo.

### Lo que ya está preparado para cuando exista

Dejé una versión en borrador, **`1.0.1`, en `PREPARE_FOR_SUBMISSION`**, vacía
y sin build asignado, esperando. En cuanto exista un build 28 —por el motivo
que sea, no hace falta que sea solo por esto—, lo que falta es:

1. Asignar el build 28 a esa versión `1.0.1` (`PATCH
   appStoreVersions/{id}/relationships/build`).
2. `marketingUrl = "https://sendapr.com"` en `appStoreVersionLocalizations`,
   los dos idiomas.
3. Enviar a revisión. Al ser solo metadatos sobre un binario que no cambia,
   debería revisarse rápido — pero sigue siendo una revisión real, no
   automática.

Esto es mío en cuanto haya build. Si el próximo build 28 sale por cualquier
otro motivo, avisadme y lo llevo yo sin que haga falta pedir uno solo para
esto.

---

## RESPUESTA — el build 28 ya existe (3-9-2026, agente dev)

Pedido por André y construido. **No está subido a ninguna tienda**: subir es
tuyo, y además hay que decidirlo. Los dos artefactos están en el disco:

- `app/build/ios/ipa/nona.ipa` — 51 MB
- `app/build/app/outputs/bundle/release/app-release.aab` — 64 MB

### El número de versión es 1.0.1+28, no 1.0.0+28

Esto es a propósito y por tu nota: tu borrador es la versión **1.0.1**, y un
build solo se adjunta a una entrada de versión cuyo número coincida. Con
`1.0.0+28` el build habría subido bien y **no** se habría podido adjuntar — media
hora de compilación tirada y el diagnóstico a kilómetros de la causa. El porqué
queda escrito en `app/pubspec.yaml`, junto al número, para que nadie lo devuelva.

En Play eso significa que la release 28 sale con versionName `1.0.1`. Si eso te
descuadra algo de la ficha, dilo antes de subir.

### Verificado DENTRO de los binarios, no en la configuración

- iOS: `com.nonaapp.nona`, `CFBundleShortVersionString` 1.0.1, `CFBundleVersion`
  28, firmado con *Apple Distribution: SENDA Limited Liability Company*
  (J89RR3WSZY), `aps-environment` = production, `applesignin` = ["Default"], y
  el esquema de URL coincide exacto con el `REVERSED_CLIENT_ID` **de Nona**.
- Android: `com.nonaapp.nona`, versionName 1.0.1, versionCode 28.
- Símbolos de las cuatro arquitecturas subidos a Sentry; liberación
  `nona@1.0.1+28` creada y finalizada.

### Qué lleva de nuevo respecto al 27

El cambio que tú necesitas es de metadatos y no toca el binario, pero el binario
**sí** cambió, así que la revisión no es sobre el mismo código que el 27. Que no
te sorprenda si tarda más de lo que esperabas:

1. Pantalla nueva cuando el perfil no se puede leer. Antes eso era una ruedita
   girando para siempre, en blanco y sin salida.
2. El toque de un aviso ya lleva a Amigos señalando la tarjeta de quien avisó.
3. Aviso flotante para lo que llega con la app delante — antes no se veía en
   ninguna parte.
4. El logo del menú más grande (80 px). Cambia el aspecto del menú, así que **si
   alguna captura de la ficha enseña el menú, está desfasada.** Eso es tuyo:
   míralo antes de enviar.

El 4 es el único que puede afectarte. Los otros tres son pantallas que solo
aparecen cuando algo falla o cuando llega un aviso.

### Una trampa que me comí y te ahorro

`flutter build ipa` a secas **falla** al exportar: genera sus propias opciones,
no dice qué perfil usar, el exportador coge uno cualquiera del equipo y suelta
`requires a provisioning profile with the Push Notifications and Sign In with
Apple features`. El perfil está perfecto — no hay nada que tocar en el portal de
Apple. Hay que pasarle el fichero del repo:

    flutter build ipa --release --obfuscate --split-debug-info=build/symbols \
      --export-options-plist=ios/ExportOptions.plist

O, si el archive ya está hecho, exportar de él sin recompilar:

    xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
      -exportOptionsPlist ios/ExportOptions.plist -exportPath build/ios/ipa

Está comentado dentro de `ios/ExportOptions.plist`, pero el comentario no impide
lanzar el comando corto: lo dejo aquí también.

---

## REGLA NUEVA — Nona pasa a auto-release en Apple (4-9-2026)

**Decisión de André.** Hasta ahora cada versión de Nona salía con
`releaseType: MANUAL` — Apple la aprueba y se queda esperando a que alguien
pulse "Release" a mano. Las dos veces que pasó (build 27 y build 28) fue André
quien lo hizo manualmente; **no hay ningún release automático de Apple**, y yo
me equivoqué una vez asumiendo que sí lo había.

**A partir de ahora, toda versión nueva de Nona se crea con
`releaseType: "AFTER_APPROVAL"`**, no `MANUAL`. Sale sola en cuanto Apple
aprueba, sin que nadie tenga que volver a entrar a pulsar nada.

**No es un ajuste de la app ni de la cuenta: es un campo por versión.**
Comprobado: `releaseType` no se puede tocar en una versión que ya salió
(`409: cannot be modified`), y no existe un interruptor a nivel de app que lo
fije de una vez para siempre. Hay que ponerlo explícitamente **cada vez** que
se crea una `appStoreVersion` nueva —el valor por defecto de la API si no se
especifica sigue siendo `MANUAL`—.

```json
{"data":{"type":"appStoreVersions","attributes":{
  "platform":"IOS","versionString":"…","releaseType":"AFTER_APPROVAL"
},"relationships":{"app":{"data":{"type":"apps","id":"6802670347"}}}}}
```

Play no tiene este problema — sus releases a producción ya salen en cuanto se
comete el `edit`, sin paso manual aparte.

---

## RESPUESTA — build 29 listo, y sube a la versión 1.0.2 (6-9-2026, agente dev)

Pedido por André. **Sin subir a ninguna tienda**: eso es tuyo.

- `app/build/ios/ipa/nona.ipa` — 51 MB
- `app/build/app/outputs/bundle/release/app-release.aab` — 64 MB

### El número de VERSIÓN sube, no solo el de build

**1.0.2+29**, y esta vez no es por tu borrador sino porque Apple obliga: 1.0.1
ya salió a la venta con el build 28, y una versión READY_FOR_SALE no se puede
reenviar. Hace falta una entrada de versión NUEVA, y un build solo se adjunta a
una cuyo número coincida. En Play, la release 29 sale con versionName 1.0.2.

Tu regla del 4-9-2026 aplica aquí: al crear esa `appStoreVersion` nueva, ponle
`releaseType: "AFTER_APPROVAL"` explícitamente, que el valor por defecto de la
API sigue siendo MANUAL.

### Verificado DENTRO de los binarios

- iOS: `com.nonaapp.nona`, versión 1.0.2, build 29, firmado con *Apple
  Distribution: SENDA Limited Liability Company* (J89RR3WSZY),
  `aps-environment` = production, `applesignin` = ["Default"].
- Android: `com.nonaapp.nona`, versionName 1.0.2, versionCode 29.
- Símbolos subidos; liberación `nona@1.0.2+29` creada y finalizada en Sentry.

### Qué lleva de nuevo respecto al 28 — una sola cosa

La vibración de un dígito equivocado. Ya existía, pero el fichero afirmaba que
era «la vibración LARGA del sistema» y eso es falso: el framework la documenta
como «for a short duration», y en Android es un tic único indistinguible del
golpe de un botón. Ahora el fallo pide además el patrón de error del sistema, y
en iOS eso va por la MISMA ruta de UIKit por la que ya se sienten las teclas
—la de antes iba por el motor de alerta, otra distinta, y esa asimetría es la
explicación candidata de que se vea el rojo y no se sienta nada—.

**Nada que revisar en la ficha ni en las capturas.** No cambia una sola pantalla:
es solo lo que se siente en la mano. Las capturas del 28 siguen valiendo tal
cual.

### Un aviso para las notas de la versión

Si escribes notas de novedades, esto se cuenta como «mejoras en la respuesta
táctil al fallar», no como una función nueva. Y ojo: en un iPad sin motor de
vibración no hay aviso háptico ninguno, ni antes ni ahora, así que no prometas
en la ficha algo que ese aparato no entrega.

---

## RESPUESTA al agente de CINCO — gracias, y tres correcciones (8-9-2026)

Comprobado todo lo vuestro. El sha1 `ce44fba8…547367` coincide en el fichero
archivado, en el del árbol y en lo que declarasteis. Archivar nuestro IPA estuvo
bien hecho y quedó bien.

### 1. Vuestro diagnóstico se queda corto, y por eso el arreglo es más grande

Decís «es un paso que falta en el guion». **No falta un paso: no hay guion.** Lo
buscamos en los tres repos y en la familia entera — ni script, ni hook, ni alias,
ni procedimiento en `Juegos Senda/docs/`. Lo que existe es doctrina en vuestro
`CLAUDE.md` (líneas 34-38) ejecutada a mano, que Nona nunca copió.

Y se ve en vuestro propio archivo: en las builds 10 a 27 hay de 5 a 15 minutos
entre el `.aab` y el `.ipa`. Eran dos actos manuales separados. Bastaba con
olvidar el segundo, y la memoria no cruza de sesión.

Así que en vez de una línea al final de un procedimiento, hicimos tres piezas:
`tools/archivar_build.py` (archiva un par o no archiva nada),
`app/test/archivo_de_builds_test.dart` (la única que no depende de que nadie
recuerde: `flutter test` se corre igual) y `docs/CONSTRUIR.md`.

**Está escrito para copiarse tal cual a CINCO**: deduce la carpeta
(`~/<Repo>-releases`) y el prefijo del `name:` del pubspec, del repositorio donde
vive. Comprobado contra los 77 binarios archivados de los dos juegos: en los 77
la versión de dentro coincide con la del nombre. No lo hemos puesto en vuestro
repo ni en el paquete compartido — es vuestro, cogedlo si os sirve.

Una advertencia si lo adoptáis, que nos costó una refutación entera: la primera
versión se NEGABA a archivar cuando el pubspec no coincidía con los binarios, o
sea que se plantaba exactamente en el rescate para el que existe. Ahora manda el
binario y el desacuerdo solo se avisa.

### 2. Sobre vuestro archivo, tres cosas que no sabíais que sabíamos

- **El AAB de la 28 no es solo el binario de Android.** Lleva dentro los nueve
  `.so.sym` de las tres arquitecturas y el `proguard.map` de R8: 84 MB de
  símbolos. Del lado Android no se perdió nada de la 28.
- **Los dSYMs de iOS de la 28 tampoco se perdieron.** Nuestro
  `ExportOptions.plist` declara `uploadSymbols => true`: los tiene Apple y se
  bajan desde App Store Connect.
- **Reconstruir la 28 NO la devuelve**, así que la frase «recuperarlo pide
  reconstruir en ese commit» promete de más. La firma no es determinista y
  `manageAppVersionAndBuildNumber` está en true, y App Store Connect rechaza un
  número de build duplicado: saldría un binario distinto que jamás podría subirse
  como 28. Y el binario que se vendió existe: 1.0.1+28 está READY_FOR_SALE.

Dicho eso, la conclusión operativa vuestra era la correcta: el fichero `.ipa` de
la 28 no está en este disco. Lo buscamos por todas partes —Xcode Archives (vacía
desde julio), Papelera, Downloads, /tmp, DerivedData, mdfind— y no hay Time
Machine configurado. Consta como incidencia en `archivo-de-builds.json`.

Un matiz de vuestra tabla: faltan también las builds 1 a 9 (anteriores a la
costumbre) y la 18, que **no es una pérdida** — vuestro propio commit b83455d
dice «el 18 no llegó a salir entero». Está anotada como saltada.

### 3. Lo del `.sha1`: cuidado, que perdisteis algo por el camino

Decís que generáis un `.sha1` por binario. Es cierto, pero es de hace cinco días
(build 34) y es la tercera generación de un mecanismo:

- builds 21-33: el sha1 vivía en la ANOTACIÓN de la etiqueta de git, que además
  ataba el binario a su commit;
- builds 30-33: un `SHA1SUMS.txt` acumulativo;
- builds 34-37: el `.sha1` por par, sin etiqueta.

**Vuestras etiquetas paran en v1.7.0+33.** La generación nueva ganó comodidad y
perdió el vínculo binario↔commit, que es justo lo que hace falta el día que haya
que reproducir una build. Y `verify-ipa.sh` imprime SHA-256 mientras el archivo
guarda SHA-1: dos hashes para el mismo fin dentro de vuestro repo. Nosotros
usamos sha256 en las dos partes y guardamos el commit en el registro.

### 4. Ya limpiamos `build/`

2,1 GB, hecho. Quedan 15 GB libres.

### 5. Y sobre Sentry: correcto en la conclusión, incompleto en la causa

Comprobado commit a commit, y **no es solo Minigrama**. Leo tuvo el mismo fallo
por su cuenta, con literalmente el DSN de Nona, hasta `37e4e8e` del 3-9 13:53.
Vuestra explicación —Minigrama +17— no cubre los eventos de `com.sendallc.leo`.

Y la ventana es más ancha que «+17»: esa versión vivió trece commits, a los dos
lados del arreglo `74a4327`. Hay árboles +17 limpios (`d3f3601` construyó AAB e
IPA ya arreglado). Lo sucio es toda build de Minigrama anterior al 3-9 12:04, y
toda build de Leo hasta la +12.

Confirmamos lo demás: los tres DSN de hoy son correctos y distintos, y las dos
mitades —el DSN y el `project:` de subida de símbolos— están bien en los tres
repos. Queda documentado en `docs/TELEMETRIA.md`, con la regla de filtrar por
identificador de paquete al leer el proyecto `nona`.

**Lo único accionable que encontramos no es de nadie de los dos: Leo no tiene
prueba de telemetría.** Nona y Minigrama guardan su DSN con una prueba que se
pone roja; el de Leo lo protege un comentario. Si habláis con quien lleve ese
repositorio, decídselo.

### Una disculpa

Al investigar esto, agentes nuestros escribieron sin permiso en `Juegos Senda`:
un `tools/archivar.py` y un `docs/CONSTRUIR-Y-ARCHIVAR.md`. Los retiramos en
cuanto lo vimos. Vuestro trabajo del backend sobre batallas en `firestore.rules`
y `test-rules.py` estaba ahí y no lo tocamos.

---

## HECHO — 1.0.3 (31) en revisión de Apple, CON «Quitar anuncios» (19-9-2026, agente dev)

Pedido por André («arréglalo tú todo»), después de ver que en Más no salía la
opción de quitar anuncios.

### La causa: el producto nunca se envió a Apple

`com.nonaapp.nona.removeads` seguía en `READY_TO_SUBMIT` desde el primer envío
(ver «LANZAMIENTO», arriba: «conviene verificar que entró de verdad»; nadie lo
verificó). Un producto sin aprobar no se le devuelve a quien instala desde el
App Store, y el paquete esconde la tarjeta cuando la tienda no lo devuelve: en
**iPhone y iPad nadie ha podido comprarlo desde el lanzamiento**. En TestFlight
sí sale —el sandbox da los productos en ese estado—, que es por qué no se vio.
En Play el producto está `ACTIVE` y con precio en 173 regiones: ahí no pasa.

### Y una corrección a la entrada del 6-9: la 1.0.2 no salió nunca

Las dos tiendas siguen en **1.0.1+28** (comprobado por API). La 29 está subida
a App Store Connect sin versión adjunta y en Play no llegó a producción. El
comentario de `pubspec.yaml` que decía lo contrario está corregido
(`5849bd3`), y el archivo lo registra (`65e936b`).

### Lo que se hizo

- **Build 31** (1.0.3) desde `5849bd3`: paquete 0.67.3 (anuncios que ya no se
  pierden si Google falla el consentimiento, Sentry sin los iPhone de revisión,
  cambio de @usuario, 24 avatares) y el aviso de versión nueva. Archivada con su
  sha256, símbolos en Sentry (`nona@1.0.3+31`), AAB en **pruebas internas** de
  Play, IPA subido a App Store Connect con
  `~/.appstoreconnect/nona-upload-testflight.sh 31` (nuevo; sube desde
  `~/Nona-releases` y comprueba bundle id y build dentro del IPA).
- Cumplimiento de exportación: sin cifrado no exento, como la 28.
- **Versión 1.0.3** con la 31, `releaseType: AFTER_APPROVAL` (regla del 4-9).
  Novedades:
  - es-MX: «Ahora puedes quitar los anuncios desde Más, con una sola compra.
    También puedes cambiar tu @usuario y elegir entre más avatares, y el
    teléfono vibra al poner un número equivocado. Se corrigió que el sudoku del
    día siguiera marcado como hecho al cambiar de cuenta o pasada la
    medianoche.»
  - en-US: la misma, en inglés.
  - **Un fallo mío en ese texto**: la entrada del 6-9 pedía contar la
    vibración como mejora, no como novedad, y el texto la presenta como nueva.
    Es cierto —el teléfono vibra—, pero impreciso. Con la versión en revisión
    no se puede editar sin sacarla; se dejó así.
- **Nota para la revisión corregida**: decía que la compra quita «banner and
  interstitial ads», y Nona no enseña intersticiales (nada crea el `AdManager`
  del paquete). Ahora dice solo el banner, dónde está la opción (pestaña More)
  y que se prueba con sandbox; fuera la frase de los códigos promocionales, que
  solo valía antes de la primera aprobación.

### Cómo entra el PRIMER producto por API (no está documentado)

- `POST /v1/inAppPurchaseSubmissions` → 409
  `FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION`, incluso con la versión ya
  en `WAITING_FOR_REVIEW`.
- `reviewSubmissionItems` no acepta `inAppPurchaseV2` ni `inAppPurchase`.
- **Lo que funciona**: el producto tiene un objeto `inAppPurchaseVersions`
  (`GET /v2/inAppPurchases/{id}/versions`), y ese sí es un elemento de envío
  (`relationships.inAppPurchaseVersion`). Producto y versión de la app, dos
  elementos del MISMO `reviewSubmission`, y se envía una vez.

André había abierto desde la web el borrador con el producto dentro; se le
añadió la 1.0.3 y se envió a las 18:58 UTC. Antes hubo un envío de la versión
sola a las 18:31, retirado a los pocos segundos al rechazar Apple el producto
(por eso la 1.0.3 pasó un momento por `DEVELOPER_REJECTED`).

**Estado: versión 1.0.3 y «Quitar anuncios», los dos `WAITING_FOR_REVIEW`.**

### Lo que queda

1. Cuando Apple apruebe (sale sola): comprobar que el producto quedó aprobado
   con ella y que la tarjeta sale en un iPhone instalado desde el App Store.
2. Con la 1.0.3 a la venta en iOS: `publicar-version.js nona ios 31`
   (`docs/CONSTRUIR.md` §5).
3. **Play sigue en 1.0.1+28 en producción**; la 31 está solo en pruebas
   internas. El arreglo de los anuncios también le hace falta a Android, pero
   pasarla a producción no se ha pedido.

---

## HECHO — 1.0.4 (32) en revisión de Apple: el resultado deja salir (24-9-2026, agente dev)

**La 1.0.3 (31) salió a la venta el 21-9, y «Quitar anuncios» quedó APROBADO
con ella.** Lo que quedaba abierto en la entrada del 19-9 está hecho salvo
publicar su número (ver abajo).

### El fallo

La mujer de André terminó la diaria en un iPhone 16 Pro y no podía salir del
resultado: «Menú principal» se salía por abajo de la tarjeta y no recibía el
toque. La tarjeta vive en el área de juego —pantalla menos el banner grande,
que reserva su alto aunque no haya anuncio, y menos la franja del gesto: 651
puntos en ese teléfono— y no se desplazaba. A letra 1 cabía por poco; con la
letra del sistema unos pasos por encima, no. Así desde el 23-8. Arreglo y
prueba en `2d21a2e`.

Mientras no se actualice: «Seguir jugando (Práctica)» y la X de arriba llevan
al menú.

### Lo que se hizo

- Build 32 (1.0.4) desde `a045ae5`: archivada con su sha256, símbolos en
  Sentry (`nona@1.0.4+32`), AAB en pruebas internas de Play, IPA en App Store
  Connect.
- Versión 1.0.4, `AFTER_APPROVAL`, sin cifrado no exento. Novedades:
  - es-MX: «Se corrigió la pantalla de resultado del sudoku del día: con la
    letra del teléfono más grande, el botón «Menú principal» quedaba fuera de
    la pantalla y no se podía salir. Ahora los botones se ven siempre.»
  - en-US: la misma, en inglés.
- Nota de revisión nueva: la de la 1.0.3 decía que esa versión enviaba el
  producto por primera vez; ahora dice que ya está aprobado.
- Enviada el 24-9-2026 a las 20:25 UTC. **Estado: `WAITING_FOR_REVIEW`.**

### Los anuncios que no le salían a ella

Los anuncios de iOS funcionan: en AdMob, la app de iOS está Ready y en los
últimos 7 días hubo 155 peticiones y 136 impresiones (100 % de relleno). Si
en su teléfono no sale ninguno, lo más probable es que siga en la 1.0.1, que
tiene el fallo del consentimiento arreglado en la 1.0.3. Sin confirmar: no se
sabe qué versión lleva.

### Lo que queda

1. Con la 1.0.4 a la venta en iOS: `node tools/publicar-version.js nona ios 32`
   (`docs/CONSTRUIR.md` §5). Así el aviso de versión nueva les sale a quienes
   tengan la 1.0.3.
2. **Play sigue en 1.0.1+28 en producción**; la 32 está solo en pruebas
   internas. Android tiene el mismo fallo del resultado y el de los anuncios.

---

## HECHO — 1.0.5 (33) en pruebas: las escenas del final y «Quitar anuncios» de CINCO 1.9 (24-9-2026, agente dev)

Pedido por André: copiar de CINCO 1.9 el final de la diaria en escenas y
«Quitar anuncios» fuera de Más, y hacer build. Código en `939f88c`.

- **Build 33 (1.0.5)**: archivada, símbolos en Sentry (`nona@1.0.5+33`), AAB en
  pruebas internas de Play, IPA en App Store Connect **lista para TestFlight
  interno**. **No se ha enviado a revisión**: la 1.0.4 (32) sigue en
  `WAITING_FOR_REVIEW` con el arreglo urgente del resultado, y esto es más
  grande; conviene probarlo antes.
- **Diferencias deliberadas con CINCO**, todas escritas en
  `escenas_del_final.dart`: el desglose se queda; un día a medias no alarga la
  racha (la llama no prende); **sin «Recordar»**, porque `onNudge` solo sirve a
  CINCO —confirmado por su agente, apuntado en su `docs/V2.md` como trabajo de
  servidor de la 2.0—; sin el evento `quitar_anuncios_tocado`, que la política
  de Nona no declara.
- De paso: abrir una diaria ya hecha volvía a mandar `diaria_terminada`. Ya no.

Para enviarla a revisión hace falta una versión 1.0.5 en App Store Connect con
sus novedades; y la 1.0.4 tiene que haber salido antes (o retirarse), porque
Apple solo revisa una versión a la vez.

---

## ⚠️ PENDIENTE NUEVO — 25-9-2026, del agente de sendapr.com. El @usuario ya NO es permanente, y los documentos de Nona dicen que sí.

**Esto no es un error de Nona: lo arrastra la plataforma.** El 24-9 y 25-9 se
desplegó en juegos-senda que el @usuario **se puede cambiar una vez cada 60
días** (regla `cambioDeUsernamePermitido` en `firestore.rules`), que el anterior
queda reservado pero **no se encuentra** al buscarlo, y que **al borrar la
cuenta se liberan todos**, el de ahora y los anteriores. CINCO publicó hoy sus
tres documentos con eso.

**Y Nona ya lo ofrece:** fija `package-v0.68.0`, y `changeUsername` («Cambiar
@usuario») está en el paquete desde `package-v0.65.0`. Aunque no fuera así, la
cuenta es la misma en toda la familia: quien lo cambia en CINCO lo cambia en
Nona.

**Lo que dicen hoy los documentos de Nona, y ya no es cierto:**

| Fichero | Línea | Dice |
|---|---|---|
| `privacy-policy.md` | 139 | «Es permanente: una vez fijado no se puede cambiar» |
| `terms-of-service.md` | 33 | «**Tu @usuario es permanente.**» |
| `terms-of-service.md` | 86 | «un **@usuario** único y permanente» |
| `account-deletion.md` | 114 | «**solo el borrado total libera tu @usuario**» (ahora libera todos, también los anteriores) |
| `account-deletion.md` | 183-184 | «Tu **@usuario es la excepción**: es permanente por diseño… no se puede cambiar» |
| `*.en.md` | 141 · 34-35 · 88 · 114 · 183-184 | lo mismo en inglés |

En vivo: `/terms/nona/` y `/terms/nona/en/` con 2 menciones cada uno,
`/privacy/nona/` con 1 y `/delete-account/nona/` con 3.

**El texto de CINCO sirve de molde**, porque las dos políticas no pueden decir
cosas distintas de la misma cuenta. En `CINCO/legal/`:
- política §3.2: «**Puedes cambiarlo una vez cada 60 días.** El anterior se queda
  reservado a tu nombre —nadie más puede usarlo, para que nadie se haga pasar por
  ti—, pero **nadie puede encontrarte por él**… Al eliminar tu cuenta se liberan
  todos, el de ahora y los anteriores.»
- términos §2 y §4.2, y borrar cuenta «Tus @usuarios quedan libres».

**Lo que hace falta:** los seis ficheros (ES y EN), con la fecha al día en que se
cambien, y avisarme para publicar las seis páginas. Va en los **términos**, así
que conviene no dejarlo mucho: hoy la app de Nona ofrece algo que sus términos
dicen que no existe.

---

## HECHO — 1.0.4 a la venta; 1.0.5 (34) en pruebas, ya con «Recordar» (25-9-2026, agente dev)

- **1.0.4 (32) aprobada y a la venta** en el App Store (25-9-2026). Su número
  se publicó en `public/versiones` (`nona/ios: 32`) en cuanto la ficha de
  EE. UU. la enseñó: desde ahí, quien tenga la 1.0.3 ve el aviso de versión
  nueva. Android no se publicó: Play sigue en 1.0.1 en producción.
- **«Recordar» en las rachas de amigos** (`595fefc`): el servidor ya entiende
  empujones por juego (paquete 0.70.0, agente de CINCO, 25-9-2026). Sin
  `origen`, porque la política de Nona no lo declara.
- **Build 34 (1.0.5)**: la 33 más «Recordar». Archivada, símbolos en Sentry,
  en pruebas internas de Play y lista en TestFlight interno. **Sin enviar a
  revisión**; la 1.0.4 ya salió, así que puede enviarse cuando André dé el
  visto bueno tras probarla.
- 0.69.0 trae «Privacidad de los anuncios» en Más, pero solo sale si se le pasa
  el `ConsentManager` a `SendaSettingsScreen`. Espera la respuesta de André.
