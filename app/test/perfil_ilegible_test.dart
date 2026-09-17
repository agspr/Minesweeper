import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';

import 'helpers.dart';

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
/// **La pantalla es la del paquete desde el 17-9-2026.** Nona tuvo su propia
/// copia, y nació sin desplazamiento: con la letra grande del sistema las dos
/// salidas quedaban debajo de la pantalla, sin forma de llegar a ellas. Lo que
/// la pantalla es por dentro —que quepa, que se desplace, que el texto salga del
/// ARB— lo prueba el paquete (`profile_error_screen_test.dart`). Aquí se
/// vigila lo que es de Nona: que la puerta la enseñe, en su sitio, y que se
/// monte bien bajo la app de Nona.
void main() {
  /// El fuente de main.dart SIN comentarios: si no, un comentario que nombrara
  /// `auth.profileError` bastaría para aprobar con la comprobación borrada.
  String codigoDeMain() => File('lib/main.dart')
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  // **Por qué la puerta se comprueba sobre el TEXTO de main.dart y no montándola:**
  // la rama vive detrás de `auth.signedIn`, que es `_user != null`, y ese
  // `_user` solo lo pone FirebaseAuth. Sin Firebase no hay forma de llegar a
  // ella en una prueba de widget, y con Firebase ya no es una prueba.

  test('Nona MIRA el fallo del perfil', () {
    expect(
      codigoDeMain(),
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
    final src = codigoDeMain();
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

  test('y lo que enseña es la pantalla del paquete', () {
    // Y no una copia propia. La de Nona no se desplazaba: medido el 17-9-2026 en
    // un iPhone 16 Pro con la accesibilidad al máximo, «Reintentar» y «Cerrar
    // sesión» quedaban 654 y 784 px por debajo de la pantalla. Una copia nueva
    // volvería a separarse de la del paquete, que es como nació aquel defecto.
    final src = codigoDeMain();
    final rama = RegExp(
      r'if \(auth\.profileError != null\) \{([\s\S]*?)\}',
    ).firstMatch(src);
    expect(rama, isNotNull, reason: 'no encuentro la rama del fallo del perfil');
    expect(
      rama!.group(1),
      contains('return SendaProfileErrorScreen(auth: auth);'),
      reason: 'la rama del fallo del perfil no enseña la pantalla del paquete',
    );
  });

  group('la pantalla del paquete, montada bajo la app de Nona', () {
    // Con los delegados, el tema y la marca de Nona (`testApp` los monta como
    // main.dart), y en los DOS idiomas de Nona: CINCO solo la enseña en
    // castellano, así que el inglés bajo Nona no lo vigila nadie más.
    //
    // En el teléfono más pequeño y con la accesibilidad al máximo, porque Nona
    // no topa la escala del texto en toda la app —su tablero no quiere las
    // cifras más grandes— y esta pantalla recibe la del sistema entera.
    for (final (idioma, titulo) in [
      (const Locale('es'), 'No se pudo cargar tu perfil'),
      (const Locale('en'), "We couldn't load your profile"),
    ]) {
      testWidgets(
        '${idioma.languageCode}: su texto, y las dos salidas se alcanzan con la letra al máximo',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1.0;
          // La letra se pone donde la pone la persona: en el sistema. Un
          // `MediaQuery` propio por encima del `MaterialApp` no valdría, porque
          // la app construye el suyo desde la vista.
          tester.platformDispatcher.textScaleFactorTestValue = 3.1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final auth = AuthController(
            gameId: nonaGameId,
            firebaseReady: false,
            prefs: null,
          );
          await tester.pumpWidget(
            testApp(SendaProfileErrorScreen(auth: auth), locale: idioma),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text(titulo), findsOneWidget);

          for (final salida in [
            find.byType(FilledButton),
            find.byType(TextButton),
          ]) {
            expect(salida, findsOneWidget);
            await tester.ensureVisible(salida);
            await tester.pump();
            final caja = tester.getRect(salida);
            expect(
              caja.top >= 0 && caja.bottom <= 568,
              isTrue,
              reason: 'una salida queda fuera de la pantalla y no se puede '
                  'llegar a ella: $caja',
            );
          }
        },
      );
    }
  });
}
