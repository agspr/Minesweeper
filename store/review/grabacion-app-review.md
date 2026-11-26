# Grabación para App Review (Guideline 2.1, 26-11-2026)

Apple rechazó la 1.0.0 pidiendo información, no por un fallo: quiere una
grabación de pantalla **en un iPhone físico con el iOS más reciente**, que
empiece al abrir la app y enseñe el uso normal, el inicio de sesión y el
borrado de cuenta, el reportar y bloquear, y la compra. Las respuestas
escritas ya están en las notas de revisión (`notas-app-review-en.txt`,
guardadas en App Store Connect el 26-11).

## Antes de grabar

1. **iPhone al día**: Ajustes › General › Actualización de software.
2. **Build 16 desde TestFlight** (si no te sale, App Store Connect ›
   TestFlight › Pruebas internas, y añádete). En TestFlight la compra va por
   el entorno de pruebas de Apple: **no cobra**.
3. **Una cuenta de usar y tirar, nunca la tuya.** El borrado de la grabación
   es «Eliminar todo»: borra la cuenta de Juegos Senda entera, en todos los
   juegos. Con Iniciar sesión con Apple tu Apple ID ya es tu cuenta de la
   familia, así que **usa Google con una cuenta de Google desechable**.
4. **Prepara la cuenta** (un minuto, sin grabar): abre la app, entra con esa
   cuenta de Google, elige un @usuario y pásale el @usuario a la sesión de
   desarrollo. Ella le siembra tres amigos de pega (`tools/amigos_demo.py`)
   para que haya a quién reportar y bloquear. Luego **cierra sesión y borra la
   app**, para que la grabación empiece desde la primera apertura.
5. Centro de control › Grabar pantalla a mano, y modo No molestar.

## Lo que se graba, de corrido (2-4 minutos)

1. Abrir la app (instalada de nuevo desde TestFlight). Aceptar o no lo de los
   anuncios y el rastreo, lo que salga.
2. **«Jugar sin cuenta»** (o «Play without an account»). Si el iPhone está en
   español: Más › Idioma › EN, para que el revisor lo lea en inglés.
3. Jugar › Reto diario: destapar unas casillas y poner una bandera con
   pulsación larga. Volver.
4. Jugar › Modo práctica: abrir un tablero un momento. Volver.
5. **Más › Iniciar sesión › Continuar con Google**, con la cuenta desechable.
6. **Social**: se ve la clasificación con los tres amigos. Tocar uno ›
   **Reportar** › elegir un motivo › enviar. Tocar otro › **Bloquear** ›
   confirmar.
7. **Más › Bloqueados**: se ve el bloqueado, y **Desbloquear**.
8. **Más › Quitar anuncios ($1.99)** › comprar con la hoja de Apple (prueba,
   no cobra) › el banner desaparece. Luego **Restaurar compras**.
9. **Más › lápiz de la tarjeta de perfil › Eliminar cuenta**: se ven las dos
   opciones; elegir **«Eliminar todo»** y confirmar. Termina con «Tu cuenta
   de Juegos Senda se ha eliminado».

## Después

- Pasa el vídeo al Mac (AirDrop) y dile a la sesión de desarrollo dónde está.
  Ella lo adjunta en App Store Connect (Información para la revisión ›
  Adjunto), borra los amigos de pega (`amigos_demo.py --borrar`), y vuelve a
  enviar la versión con «Quitar anuncios».
- La cuenta desechable ya quedó borrada en el paso 9.
