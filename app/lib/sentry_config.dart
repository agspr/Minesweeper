/// DSN del proyecto de Sentry (org `senda-6q`, proyecto `nona`).
///
/// Se puede sobrescribir en build con `--dart-define=SENTRY_DSN=...`
/// (cadena vacía = Sentry desactivado; Crashlytics sigue activo).
// El DSN va embebido y no es un secreto: solo permite ENVIAR eventos, no
// leerlos — por eso vive en el repositorio y no en el directorio de
// credenciales. Y tiene que ser el DEFAULT: los builds no pasan --dart-define,
// así que sin default real todas las builds saldrían con Sentry apagado sin
// que nada falle. (Trampa documentada en PARIDAD §Telemetría.)
const String sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: 'https://d023f3b74bcd04a2997ce0ec5e7cba48@o4511451179581440.ingest.us.sentry.io/4511975097368576',
);
