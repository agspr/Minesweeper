import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/home_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **Tocar un aviso tenía que llevar a algún sitio, y no llevaba a ninguno.**
///
/// Nona llamaba a `wireInviteTaps()`, así que los toques se recogían y el
/// paquete dejaba el uid en `abrirAmigosPara`… y nadie lo leía. Resultado:
/// tocar «X te agregó» abría la app en el menú y ahí se acababa. Sin error, sin
/// registro, sin nada que mirar — el síntoma era «no pasa nada».
///
/// Lo que se comprueba aquí es el consumo y el destino. Lo que NO se puede
/// montar es el empujón con sesión: vive detrás de `auth.signedIn`, que es
/// `_user != null`, y ese `_user` solo lo pone FirebaseAuth. Esa mitad se
/// vigila sobre el texto de la pantalla, al final.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final p = generate(seed: 7, target: Difficulty.easy)!;

  Future<NotificationsService> montar(
    WidgetTester tester, {
    String? avisoPrevio,
  }) async {
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      '2026-08-18': {
        'givens': p.givens,
        'solution': p.solution,
        'difficulty': 'easy',
        'clues': p.clueCount,
      },
    });
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final daily = DailyController(
      prefs,
      clock: () => DateTime(2026, 8, 18, 10),
    );
    await daily.load();

    final avisos = NotificationsService(
      firebaseReady: false,
      gameId: nonaGameId,
    );
    // Se pone ANTES de montar a propósito: es el caso de la app cerrada, donde
    // `getInitialMessage` resuelve antes de que la pantalla exista.
    if (avisoPrevio != null) avisos.abrirAmigosPara.value = avisoPrevio;

    await tester.pumpWidget(
      testApp(
        HomeScreen(
          daily: daily,
          practice: PracticeController(prefs),
          locale: LocaleController(prefs),
          theme: ThemeController(prefs),
          progress: ProgressController(prefs),
          auth: AuthController(
            gameId: nonaGameId,
            firebaseReady: false,
            prefs: prefs,
          ),
          friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
          notifications: avisos,
          prefs: prefs,
          leaderboard: null,
          purchases: PurchaseService(prefs, const IapConfig(removeAdsId: 'x')),
          banner: null,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    return avisos;
  }

  testWidgets('el aviso que llegó con la app CERRADA no se pierde', (
    tester,
  ) async {
    // El listener no basta: con la app cerrada el valor ya está puesto cuando
    // la pantalla se monta, así que nunca «cambia» y el listener no dispara.
    // Es el caso más común de todos —tocar el aviso sin tener la app abierta—
    // y es el que se caía por el suelo.
    final avisos = await montar(tester, avisoPrevio: 'uid-de-quien-avisa');
    expect(
      avisos.abrirAmigosPara.value,
      isNull,
      reason: 'si no se consume, la pantalla se reabriría sola al volver atrás',
    );
  });

  testWidgets('y lleva a la Social, que es de donde cuelga Amigos', (
    tester,
  ) async {
    // Cerrar Amigos tiene que dejar debajo el sitio del que salió. Sin mover la
    // pestaña, al cerrar la pantalla completa aparece el TABLERO, que no tiene
    // nada que ver con el aviso que se acababa de tocar.
    await montar(tester, avisoPrevio: 'uid-de-quien-avisa');
    expect(find.byType(SendaSocialSignedOut), findsOneWidget);
  });

  testWidgets('sin sesión no abre Amigos: no hay nada que enseñar', (
    tester,
  ) async {
    // Pasa con un aviso viejo en la bandeja después de cerrar sesión. Las
    // amistades no están cargadas, así que Amigos saldría vacía y sin explicar
    // por qué. La Social ya invita a entrar; ahí se queda.
    final avisos = await montar(tester, avisoPrevio: 'uid-de-quien-avisa');
    // Hay que dejar que la ruta se construya. Sin estos bombeos, `findsNothing`
    // sale verde aunque el empujón se haya hecho —la pantalla aún no existe—, y
    // la prueba pasaría igual con el guardarraíl quitado: comprobado quitándolo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SendaFriendsScreen), findsNothing);
    // Consumido igualmente: dejarlo puesto haría que abriera Amigos sola en el
    // momento en que esa persona entre.
    expect(avisos.abrirAmigosPara.value, isNull);
  });

  testWidgets('un aviso que llega DESPUÉS también se atiende', (tester) async {
    final avisos = await montar(tester);
    expect(avisos.abrirAmigosPara.value, isNull);
    avisos.abrirAmigosPara.value = 'otro-uid';
    await tester.pump();
    expect(
      avisos.abrirAmigosPara.value,
      isNull,
      reason: 'con la app abierta, el toque llega por el listener',
    );
  });

  group('la mitad que necesita sesión, sobre el texto', () {
    String src() => File('lib/screens/home_screen.dart').readAsStringSync();

    test('el uid del aviso llega a la pantalla de Amigos', () {
      // Sin `destacar`, quien toca el aviso aterriza en una lista y tiene que
      // buscar qué le habían dicho — justo lo que el aviso venía a ahorrarle.
      expect(src(), contains('destacar: destacar'));
    });

    test('y Amigos se construye en UN solo sitio', () {
      // La abren dos caminos: el icono de persona y el toque del aviso. Con dos
      // copias de la construcción, la que se toca a mano queda bien y la del
      // aviso lleva meses abriendo otra cosa sin que nadie lo note. Este defecto
      // no da la cara en ninguna prueba de las de arriba.
      expect(
        RegExp('SendaFriendsScreen\\(').allMatches(src()).length,
        1,
        reason: 'dos construcciones de Amigos se separan',
      );
    });

    test('el listener se suelta al desmontar', () {
      // `NotificationsService` sobrevive a la pantalla —lo crea main()—, así que
      // un listener sin soltar mantiene viva la State y llama a `setState` sobre
      // algo desmontado.
      expect(src(), contains('abrirAmigosPara.removeListener'));
    });
  });
}
