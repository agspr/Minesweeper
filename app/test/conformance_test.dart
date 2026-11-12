import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';

/// Nona conforma con la plataforma compartida.
///
/// Esta es LA línea que copia un juego nuevo. Todo lo que comprueba son cosas
/// que fallan en silencio y tarde: una política que apunta a otro juego, un id
/// de producto de otra app —que en Apple es inmutable y no se corrige—, unos
/// anuncios a medio rellenar que dejan `isTestOnly` en true.
///
/// Lo que NO cubre está en `docs/NUEVO-JUEGO.md`, y lo primero de esa lista es
/// lo que más caro sale: dar de alta el juego en `backend/functions/games.js`.
void main() {
  test('Minesweeper conforma con la plataforma', () {
    final incumple = SendaGameConformance.violations(nonaConfig);
    expect(
      incumple,
      isEmpty,
      reason: 'Minesweeper no conforma:\n${incumple.join('\n')}',
    );
  });
  test('Android declara su icono de avisos', () {
    // Sin esta declaración, FCM cae al icono del LANZADOR. Android se queda con
    // su silueta por el canal alfa, y el de Nona no tiene canal alfa —medido:
    // tipo de color 2, opaco al 100 %—, así que lo aplana a un cuadrado blanco
    // en la barra de estado.
    //
    // Nadie lo ve hasta que llega el primer aviso de verdad, y para entonces ya
    // está publicado. Lo levantó el agente de CINCO al encontrárselo en su app.
    final manifiesto = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(
      manifiesto,
      contains('default_notification_icon'),
      reason: 'sin esto, el primer aviso sale como un cuadrado blanco',
    );
    expect(manifiesto, contains('@drawable/ic_notification'));
    expect(
      manifiesto,
      contains('default_notification_color'),
      reason: 'sin color, el icono sale en gris del sistema',
    );

    // Y que el dibujo exista y sea silueta: sin `fillColor` blanco no hay nada
    // que Android pueda teñir.
    final icono = File('android/app/src/main/res/drawable/ic_notification.xml');
    expect(icono.existsSync(), isTrue);
    expect(icono.readAsStringSync(), contains('#FFFFFFFF'));
  });
  test('todo lo que Nona guarda cae bajo un prefijo declarado', () {
    // `SendaGameConformance` comprueba que `ownedPrefKeyPrefixes` no esté
    // VACÍA, no que esté COMPLETA. Un juego que declare `['game.']` y escriba
    // también `progress.` pasa la conformidad y deja la mitad sin borrar al
    // cambiar de cuenta o al salirse del juego — y encima cree que está
    // cubierto, que es lo peor de los dos.
    //
    // El agente de CINCO lo señaló con un caso suyo que duele: si se le olvida
    // `days.`, la clave `days.seeded` sobrevive y quien vuelva **nunca** baja
    // su historial. No da error: deja la semana vacía para siempre.
    //
    // Así que aquí no se comprueba la lista contra sí misma: se comprueba
    // contra las claves que el código escribe DE VERDAD.
    final claves = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      // Constantes de clave (`static const _kAlgo = 'x.y'`) y literales
      // pasados directamente a shared_preferences.
      for (final m in RegExp(r"_k[A-Za-z]+ *= *'([^']+)'").allMatches(src)) {
        claves.add(m.group(1)!);
      }
      for (final m in RegExp(
        r"prefs\.(?:get|set)[A-Za-z]+\('([^']+)'",
      ).allMatches(src)) {
        claves.add(m.group(1)!);
      }
    }

    // Lo que NO es de la cuenta, con su motivo. Una exención sin motivo escrito
    // es un fallo disfrazado: son ajustes del APARATO, no de quien ha entrado,
    // y no deben borrarse al cambiar de cuenta. Igual que hace la plataforma
    // con `settings.locale`.
    const delAparato = {'settings.'};

    expect(claves, isNotEmpty, reason: 'sin claves no se comprueba nada');
    final huerfanas = claves.where(
      (k) =>
          !nonaConfig.ownedPrefKeyPrefixes.any(k.startsWith) &&
          !delAparato.any(k.startsWith),
    );
    expect(
      huerfanas,
      isEmpty,
      reason:
          'estas claves no las borraría nadie al cambiar de cuenta ni al '
          'salirse del juego: $huerfanas',
    );
  });
  test('iOS registra el esquema de vuelta de Google, y es el SUYO', () {
    // Sin este esquema, "Continuar con Google" abre el navegador, la persona
    // se autentica, y el sistema no sabe a qué app devolver el resultado: el
    // botón no hace nada y no hay error en ninguna parte. Nona no lo tuvo
    // NUNCA — se descubrió al ir a iniciar sesión en el simulador para las
    // capturas de tienda, no porque nadie lo probara.
    //
    // Y se comprueba que sea EL SUYO, leído de su propio
    // `GoogleService-Info.plist`: el de CINCO tiene otro client id, así que un
    // copia-pega del de la app hermana pasaría "tener un esquema" y seguiría
    // sin funcionar. Es el fallo con mejor disfraz de los dos.
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final google = File('ios/Runner/GoogleService-Info.plist')
        .readAsStringSync();

    final reverso = RegExp(
      r'<key>REVERSED_CLIENT_ID</key>\s*<string>([^<]*)</string>',
    ).firstMatch(google)?.group(1);
    expect(
      reverso,
      isNotNull,
      reason: 'GoogleService-Info sin REVERSED_CLIENT_ID',
    );

    expect(
      info,
      contains('CFBundleURLTypes'),
      reason: 'sin esquemas de URL, el inicio de sesión con Google no vuelve',
    );
    expect(
      info,
      contains('<string>$reverso</string>'),
      reason:
          'el esquema registrado no es el de ESTE proyecto: el navegador '
          'volvería a otra app, o a ninguna',
    );
  });
}
