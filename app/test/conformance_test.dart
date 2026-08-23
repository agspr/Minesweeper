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
  test('Nona conforma con la plataforma', () {
    final incumple = SendaGameConformance.violations(nonaConfig);
    expect(
      incumple,
      isEmpty,
      reason: 'Nona no conforma:\n${incumple.join('\n')}',
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
}
