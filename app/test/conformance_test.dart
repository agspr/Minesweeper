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
}
