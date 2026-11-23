import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/settings_tab.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:nona/widgets/chip_de_racha_de_amigo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Lo que Nona adopta del paquete 0.86.0 en Más y en la Social (André,
/// 5-10-2026), y el arreglo que lo acompaña en Android.
///
/// Lo que el paquete ya prueba —cómo se pinta cada fila— no se repite aquí. Se
/// vigila lo que es de Nona: que se lo PASE, con los datos buenos. Sin
/// pasárselo, cada una de estas cosas simplemente no sale, y nada da error.
String sinComentarios(String ruta) =>
    File(ruta)
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Más', () {
    Future<void> montar(
      WidgetTester tester, {
      ConsentManager? consent,
      SendaResenas? resenas,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        testApp(
          SettingsTab(
            practice: PracticeController(prefs),
            auth: AuthController(
              gameId: nonaGameId,
              firebaseReady: false,
              prefs: prefs,
            ),
            friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
            purchases: PurchaseService(prefs, nonaConfig.iap),
            notifications: NotificationsService(
              firebaseReady: false,
              gameId: nonaGameId,
            ),
            prefs: prefs,
            locale: LocaleController(prefs),
            theme: ThemeController(prefs),
            progress: ProgressController(prefs),
            consent: consent,
            resenas: resenas ?? SendaResenas(prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('«Otros Juegos Senda» anuncia CINCO y Nona, con sus datos', (
      tester,
    ) async {
      await montar(tester);
      await tester.scrollUntilVisible(find.text('CINCO'), 200);
      // El rótulo de la sección va en versalitas.
      expect(
        find.textContaining(RegExp('otros juegos senda', caseSensitive: false)),
        findsOneWidget,
      );
      expect(find.text('La palabra del día'), findsOneWidget);
      expect(find.text('El sudoku del día'), findsOneWidget);
    });

    test('el icono de CINCO está en el binario', () async {
      // Declarado en la lista pero sin estar entre los assets, la fila sale
      // con el icono roto: no hay error, solo un hueco.
      final icono = await rootBundle.load('assets/juegos/cinco.png');
      expect(icono.lengthInBytes, greaterThan(1000));
    });

    testWidgets('«Califica Buscaminas»: el nombre en el idioma de la pantalla',
        (tester) async {
      // En español la app se llama Buscaminas (teléfono y tiendas), y Más
      // decía «Califica Minesweeper» debajo de «Acerca de Buscaminas»
      // (`nonaConfigNamed`).
      await montar(tester);
      await tester.scrollUntilVisible(find.text('Califica Buscaminas'), 200);
      expect(find.text('Califica Buscaminas'), findsOneWidget);
      expect(find.text('Califica Minesweeper'), findsNothing);
    });

    testWidgets('«Privacidad de los anuncios», donde Google dice que hace '
        'falta', (tester) async {
      await montar(tester, consent: _ConsentimientoObligatorio());
      await tester.scrollUntilVisible(
        find.text('Privacidad de los anuncios'),
        200,
      );
      expect(find.text('Privacidad de los anuncios'), findsOneWidget);
    });

    test('la app le pasa a Más el consentimiento y la reseña de verdad', () {
      // Montar `main` no se puede sin Firebase, así que el último tramo se
      // mira en el código: sin esto, Más recibe null y las dos filas no salen.
      final home = sinComentarios('lib/screens/home_screen.dart');
      expect(home, contains('consent: widget.consent'));
      expect(home, contains('resenas: widget.resenas'));
      final main = sinComentarios('lib/main.dart');
      expect(main, contains('consent: consent,'));
      expect(main, contains('resenas: resenas,'));
      expect(main, contains('ads: ads,'));
      expect(main, contains('..isEntitled = () => purchases.adsRemoved'));
    });
  });

  group('la Social', () {
    test('lleva la racha de cada amigo y el empujón, con su condición', () {
      // La rama de la clasificación vive detrás de `auth.signedIn`, que solo
      // pone FirebaseAuth: no se puede montar en una prueba de widget. Se mira
      // el código.
      final home = sinComentarios('lib/screens/home_screen.dart');
      expect(home, contains('insigniaDeFila: (uid) {'));
      expect(home, contains('ChipDeRachaDeAmigo('));
      // Solo si TÚ terminaste la de hoy: la misma regla que el servidor.
      expect(home, contains('puedeEmpujar: _terminadaHoy'));
      expect(home, contains('widget.progress.lastCompletedDay == hoy'));
    });

    testWidgets('la racha de un amigo, viva solo si hoy jugaron los dos', (
      tester,
    ) async {
      for (final (yo, el, viva) in [
        (true, true, true),
        (true, false, false),
        (false, true, false),
      ]) {
        await tester.pumpWidget(
          testApp(ChipDeRachaDeAmigo(n: 7, yoJugue: yo, elJugo: el)),
        );
        expect(find.text('7'), findsOneWidget);
        expect(
          tester
              .widget<ChipDeRachaDeAmigo>(find.byType(ChipDeRachaDeAmigo))
              .viva,
          viva,
        );
      }
    });
  });

  group('Android', () {
    test('Play Juegos no arranca solo: su proveedor y su atajo, fuera', () {
      // games_services → play-services-games-v2 trae un proveedor que arranca
      // Play Juegos al abrir CUALQUIER app que lo lleve, y una actividad
      // exportada para sus atajos. Nona no tiene Play Juegos configurado.
      final manifiesto = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifiesto, contains('xmlns:tools='));
      expect(
        RegExp(r'PlayGamesInitProvider"[^>]*tools:node="remove"')
            .hasMatch(manifiesto),
        isTrue,
        reason: 'el proveedor de Play Juegos sigue entrando',
      );
      expect(
        RegExp(r'PlayGamesAppShortcutsActivity"[^>]*tools:node="remove"')
            .hasMatch(manifiesto),
        isTrue,
        reason: 'la actividad exportada de Play Juegos sigue entrando',
      );
    });
  });
}

/// El consentimiento de un sitio donde la ley pide poder retirarlo.
class _ConsentimientoObligatorio extends ConsentManager {
  @override
  bool get opcionesDePrivacidadObligatorias => true;
}
