import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **La telemetría se declara, o se pierde en silencio.**
///
/// Regla de familia (PARIDAD §Telemetría, directiva de André del 25-8-2026):
/// cada juego declara Analytics, Crashlytics y Sentry desde el día uno. Las
/// tres librerías viajan con el paquete de todos modos, así que el coste de no
/// declararlas no es que falte una función: es que compila, corre, y NO MIDE
/// NADA. Nona estuvo así sus primeras veinte versiones — cada evento que el
/// paquete emitía se descartaba (`Analytics._ready` nunca pasó a true) y un
/// crash no lo veía nadie.
///
/// Se comprueba sobre el código porque nada de esto se puede ejercer sin
/// Firebase y sin un binario. Los comentarios se quitan antes de mirar: un
/// comentario que NOMBRA la llamada que falta mantendría esto en verde.
/// Solo líneas que SON comentario, no el resto de una línea con código: el
/// recorte ingenuo por el primer `//` se come cualquier URL del código —
/// el DSN incluido, que es justo lo que una de estas pruebas busca. Lo cazó
/// esta misma prueba en rojo mientras el fichero ya tenía el DSN.
String _sinComentarios(String fuente) => fuente
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final main_ = _sinComentarios(File('lib/main.dart').readAsStringSync());

  test('Crashlytics recoge los errores de Flutter y de plataforma', () {
    expect(main_, contains('setCrashlyticsCollectionEnabled'));
    expect(
      main_,
      contains(
        'FlutterError.onError = '
        'FirebaseCrashlytics.instance.recordFlutterFatalError',
      ),
    );
    expect(main_, contains('PlatformDispatcher.instance.onError'));
  });

  test('Analytics se inicializa: sin esto cada evento del paquete muere', () {
    expect(
      main_,
      contains('Analytics.init()'),
      reason:
          'el paquete emite eventos en cada inicio de sesión e invitación; '
          'sin init(), TODOS se descartan en silencio',
    );
  });

  test('Sentry envuelve runApp, y solo si hay DSN', () {
    expect(main_, contains('SentryFlutter.init'));
    expect(main_, contains('sentryDsn.isNotEmpty'));
    expect(
      RegExp('runApp').allMatches(main_).length,
      2,
      reason: 'una llamada por rama: con Sentry y sin él',
    );
  });

  test('Sentry lleva el filtro de la familia, y nada lo pisa después', () {
    // Sin él, cada revisión de Apple vuelve a mandar su ráfaga de «fallos» de
    // entrada —265 de 266 en CINCO— y el correo de prioridad alta con ella.
    // Se mira DENTRO del init: fuera no configuraría nada.
    final init = RegExp(
      r'SentryFlutter\.init\(\(options\) \{([\s\S]*?)\}, appRunner',
    ).firstMatch(main_)?.group(1);
    expect(init, isNotNull, reason: 'no encuentro el cuerpo del init');
    final filtro = init!.indexOf('configurarSentryDeLaFamilia(options);');
    expect(filtro, isNonNegative, reason: 'el init no llama al filtro');
    expect(
      filtro,
      greaterThan(init.indexOf('options.dsn = ')),
      reason: 'el filtro va después del DSN, como pide NUEVO-JUEGO.md',
    );
    // El filtro envuelve el `beforeSend` que ya hubiera; uno puesto después
    // lo sustituye entero y el filtro deja de correr, sin error ninguno.
    expect(
      init.substring(filtro),
      isNot(contains('beforeSend')),
      reason: 'un beforeSend después del filtro lo desengancha',
    );
  });

  test('el DSN tiene un default REAL', () {
    // La trampa (agente de CINCO): los builds no pasan --dart-define, así que
    // `String.fromEnvironment` sin default deja Sentry apagado en TODAS las
    // builds sin que nada falle. Mismo silencio, otro camino.
    final cfg = _sinComentarios(
      File('lib/sentry_config.dart').readAsStringSync(),
    );
    expect(
      cfg,
      contains('ingest.us.sentry.io'),
      reason: 'sin DSN por defecto, Sentry queda apagado en todas las builds',
    );
  });

  test('los símbolos de Sentry saben a qué proyecto van', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('project: minesweeper'));
    // Hasta la build 15 Minesweeper informaba al proyecto `nona` (copiado al
    // convertir el juego) y sus fallos se mezclaban con los de Nona. Si el DSN
    // vuelve a ser el de Nona, los informes van a un sitio y los símbolos a
    // otro, y las trazas llegan sin leer.
    final cfg = _sinComentarios(
      File('lib/sentry_config.dart').readAsStringSync(),
    );
    expect(
      cfg,
      isNot(contains('4511975097368576')),
      reason: 'ese es el proyecto de Nona',
    );
    expect(pubspec, contains('org: senda-6q'));
    expect(pubspec, contains('upload_debug_symbols: true'));
  });

  test('el plugin de Crashlytics está en los DOS gradle', () {
    // En settings se declara la versión; en app se aplica. Con uno solo,
    // Android compila igual y los crashes nativos van sin símbolos.
    expect(
      File('android/settings.gradle.kts').readAsStringSync(),
      contains('com.google.firebase.crashlytics'),
    );
    expect(
      File('android/app/build.gradle.kts').readAsStringSync(),
      contains('id("com.google.firebase.crashlytics")'),
    );
  });

  test('la fase de símbolos de iOS está ENGANCHADA, no solo definida', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    // Definida…
    expect(pbx, contains('upload-crashlytics-symbols'));
    // …y referenciada en buildPhases (dos menciones: el objeto y la lista).
    // Un objeto suelto sin referencia no corre nunca — y no avisa.
    expect(
      RegExp(r'94AF371B927573C1EA731A31').allMatches(pbx).length,
      greaterThanOrEqualTo(2),
      reason: 'la fase existe pero ningún target la ejecuta',
    );
  });
  test('los eventos que la política declara SE EMITEN (§3.8)', () {
    // El hueco que encontró el agente de ficha de PRende cotejando la
    // política contra el código: §3.8 declaraba "compartió" y "tema"
    // describiendo a CINCO, y Nona no emitía ninguno de los dos — declarar de
    // más también es inexactitud, y la política es un contrato.
    final game = _sinComentarios(
      File('lib/screens/game_screen.dart').readAsStringSync(),
    );
    expect(
      game,
      contains("Analytics.compartio('resultado')"),
      reason: 'compartir el resultado se declara en §3.8 y no se emitía',
    );
    final theme = _sinComentarios(
      File('lib/services/theme_controller.dart').readAsStringSync(),
    );
    expect(
      theme,
      contains("Analytics.preference('tema'"),
      reason: 'el tema elegido se declara en §3.8 y no se emitía',
    );
  });
  test('los eventos de juego existen — y su gate es la política', () {
    // diaria_terminada y practica_terminada, hermanos de los de CINCO. Van en
    // el código ANTES que en la política publicada, y por eso el build que
    // los lleve tiene un gate: §3.8 dice "estas y ninguna más", así que
    // publicar sin ensancharla sería declarar de menos — la dirección que sí
    // importa (orden acordado con André el 27-8-2026: política primero).
    final game = _sinComentarios(
      File('lib/screens/game_screen.dart').readAsStringSync(),
    );
    expect(game, contains("Analytics.gameEvent('diaria_terminada'"));
    final practica = _sinComentarios(
      File('lib/game/practice_controller.dart').readAsStringSync(),
    );
    expect(practica, contains("Analytics.gameEvent('practica_terminada'"));
  });
}
