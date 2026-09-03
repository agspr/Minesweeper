import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/l10n/app_localizations.dart';

/// **Que el fallo del perfil se GUARDE no sirve de nada si Nona no lo mira.**
///
/// El paquete ya cuida su mitad (`perfil_ilegible_test.dart` allí): recoge el
/// error del `snapshots()`, lo guarda en `profileError`, avisa, y deja
/// `profileReady` en false a propósito. Nona tenía la otra mitad sin hacer:
/// `profileError` no se leía en ningún sitio, así que el fallo terminaba en la
/// ruedita de siempre, girando para siempre, en blanco y sin salida.
///
/// Pasó de verdad el 3-9-2026 con App Check denegando en un simulador cuyo
/// token de depuración no estaba registrado.
///
/// **Por qué esto se comprueba sobre el TEXTO de main.dart y no montando la
/// pantalla:** la rama vive detrás de `auth.signedIn`, que es `_user != null`,
/// y ese `_user` solo lo pone FirebaseAuth. Sin Firebase no hay forma de
/// llegar a ella en una prueba de widget, y con Firebase ya no es una prueba.
/// Lo que se puede vigilar —y es justo lo que se rompió— es que la
/// comprobación siga estando y siga estando ANTES.
void main() {
  String main_() => File('lib/main.dart').readAsStringSync();

  test('Nona MIRA el fallo del perfil', () {
    expect(
      main_(),
      contains('auth.profileError'),
      reason: 'sin esto el fallo se guarda y nadie lo enseña: ruedita eterna',
    );
  });

  test('y lo mira ANTES que la ruedita', () {
    // El orden ES la garantía. `profileReady` se queda en false ante el fallo
    // —a propósito, porque darlo por leído mandaría al alta a quien ya tiene
    // @usuario—, así que si el `if (!auth.profileReady)` va primero se lleva
    // el caso entero y la pantalla de error no se enseña nunca. Quedaría todo
    // escrito, compilando y en verde, sin hacer nada.
    final src = main_();
    final fallo = src.indexOf('auth.profileError');
    // Sin esto la prueba pasa EN VACÍO: si la comprobación desaparece del todo,
    // `indexOf` devuelve -1 y -1 sí es menor que cualquier posición. Verde
    // sobre nada, que es la forma exacta en que estas garantías se mueren.
    expect(fallo, isNonNegative);
    expect(
      fallo,
      lessThan(src.indexOf('!auth.profileReady')),
      reason: 'detrás del spinner, la pantalla de error es código muerto',
    );
  });

  test('con las DOS salidas', () {
    // Reintentar cubre lo pasajero (la conexión). Si el fallo es de la cuenta
    // —atestación que no pasa, una regla que la deja fuera— reintentar no sale
    // nunca del bucle: cerrar sesión es lo único que devuelve el control. Con
    // una sola, esto es otro callejón sin salida, más bonito.
    final src = main_();
    expect(src, contains('auth.reintentarPerfil'));
    expect(src, contains('auth.signOut'));
  });

  test('y en los dos idiomas', () async {
    // Nona es bilingüe de verdad —CINCO puede permitirse castellano fijo aquí
    // y Nona no—, así que los textos salen del ARB. Una clave sin traducir sale
    // en la pantalla que alguien ve el peor día que tiene con la app.
    for (final code in ['es', 'en']) {
      final l = await L.delegate.load(Locale(code));
      expect(l.profileErrorTitle.trim(), isNotEmpty);
      expect(l.profileErrorBody.trim(), isNotEmpty);
      expect(l.profileErrorRetry.trim(), isNotEmpty);
      expect(l.profileErrorSignOut.trim(), isNotEmpty);
    }
  });

  test('el cuerpo dice que el progreso local NO se ha perdido', () async {
    // Es lo primero que teme quien ve fallar su perfil, y es verdad: la diaria
    // y la racha viven en el teléfono. Si el texto se reescribe y se pierde esa
    // frase, la pantalla asusta sin motivo.
    final es = await L.delegate.load(const Locale('es'));
    final en = await L.delegate.load(const Locale('en'));
    expect(es.profileErrorBody.toLowerCase(), contains('no se ha perdido'));
    expect(en.profileErrorBody.toLowerCase(), contains("hasn't been lost"));
  });
}
