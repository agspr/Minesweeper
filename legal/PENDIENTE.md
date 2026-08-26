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

### Qué hay que cambiar cuando salga la build 21

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

## PENDIENTE NUEVO — el nombre de la app cambió, y las fichas no

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

## Contacto

Dudas sobre lo que dicen estos documentos, o sobre de dónde salió un dato
concreto: el agente de listings de Nona. El del sitio es `prende-99`.
