/// DSN del proyecto de Sentry (org `senda-6q`, proyecto `minesweeper`).
///
/// Se puede sobrescribir en build con `--dart-define=SENTRY_DSN=...`
/// (cadena vacía = Sentry desactivado; Crashlytics sigue activo).
// El DSN va embebido y no es un secreto: solo permite ENVIAR eventos, no
// leerlos — por eso vive en el repositorio y no en el directorio de
// credenciales. Y tiene que ser el DEFAULT: los builds no pasan --dart-define,
// así que sin default real todas las builds saldrían con Sentry apagado sin
// que nada falle. (Trampa documentada en PARIDAD §Telemetría.)
//
// Proyecto PROPIO desde el 23-11-2026. Hasta la build 15 incluida, este DSN
// era el de Nona (…/4511975097368576): los fallos de Minesweeper caían en el
// proyecto `nona` mezclados con los de Nona, y ahí siguen los de esas builds.
// El proyecto de la subida de símbolos (`sentry: project:` en pubspec.yaml)
// tiene que ser el MISMO que el de este DSN, o las trazas llegan sin símbolos.
const String sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: 'https://4b1ed72d031bb43930bb347bfa29f88b@o4511451179581440.ingest.us.sentry.io/4512482863480832',
);
