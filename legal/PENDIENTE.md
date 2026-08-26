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

## DECISIÓN QUE NO ES MÍA — analítica y diagnóstico

**Es lo único que dejo abierto, y conviene resolverlo antes de publicar.**

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

Lo que hay que decidir, y no me corresponde:

1. **¿Nona debe emitir los eventos propios** (inicio de sesión, compra,
   solicitud de amistad, invitación…) como CINCO? Si sí, es añadir
   `Analytics.init()` — y entonces la política necesita la lista de eventos,
   como la de CINCO. Si no, conviene decirlo explícitamente.
2. **¿Sentry debe estar activo en Nona?** Si se inicializa, hay que añadirlo a
   la tabla de proveedores de la política. Si no, valdría la pena quitar la
   dependencia para que el binario no arrastre providers inertes.
3. **Coherencia con CINCO**: la política de CINCO dice que la analítica se
   guarda *"nunca más de 14 meses"*; la consola dice **400 días** (≈13,1 meses).
   No se contradicen, pero las dos políticas deberían usar la misma cifra. Yo
   he puesto 400 días en Nona por ser lo medido.

**Publicar y corregir después es publicar dos veces**, que es justo lo que el
`PENDIENTE.md` de CINCO advertía. Mejor zanjarlo antes.

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
