import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **El envoltorio de las pruebas tiene que montar como monta `main.dart`.**
///
/// Es la regla de `PARIDAD.md` §4, y el propio `helpers.dart` cuenta el fallo
/// que la produjo: el `SendaBrandScope` estuvo dentro de `home` aquí y en la
/// app a la vez, así que las pruebas pasaban montando la pantalla directa
/// mientras «Eliminar cuenta» reventaba al llegar empujada.
///
/// Hoy las dos listas coinciden. Esto es lo que impide que se separen: el día
/// que `main.dart` gane una pieza que cambie cómo se dibuja, esto cae y
/// **alguien decide a mano** si va también al envoltorio.
///
/// Se escribió tras repetirse el fallo en CINCO el 30-8-2026, donde el
/// envoltorio se dejó el `builder` del tope de escala y las pruebas dibujaban
/// un 32 % más pequeño que la app.
void main() {
  test('helpers.dart lleva las mismas piezas que main.dart', () {
    final app = File('lib/main.dart').readAsStringSync();
    final envoltorio = File('test/helpers.dart').readAsStringSync();

    for (final pieza in [
      'SendaBrandScope',
      'nonaBrand',
      'nonaTheme()',
      'L.delegate',
      'SendaL.delegate',
      'GlobalMaterialLocalizations.delegate',
      'L.supportedLocales',
    ]) {
      expect(
        app.contains(pieza),
        isTrue,
        reason: '¿se fue $pieza de main.dart?',
      );
      expect(
        envoltorio.contains(pieza),
        isTrue,
        reason:
            '$pieza está en main.dart y no en el envoltorio: las pruebas '
            'montarían un árbol que la app no tiene',
      );
    }
  });

  test('y NO topa la escala del texto, que es decisión de Nona', () {
    // Al revés que en CINCO, y a propósito: el tablero de Nona no quiere las
    // cifras un 32 % más grandes, así que no hay tope a nivel de app. Lo que
    // sube los literales es su menú, uno a uno. Si algún día se añade el tope
    // en `main.dart`, esta prueba cae y hay que ponerlo también en el
    // envoltorio — que es justo lo que se olvidó en CINCO.
    final app = File('lib/main.dart').readAsStringSync();
    final envoltorio = File('test/helpers.dart').readAsStringSync();
    expect(
      app.contains('SendaTextScale'),
      envoltorio.contains('SendaTextScale'),
      reason:
          'el tope de escala tiene que estar en los dos sitios o en ninguno',
    );
  });
}
