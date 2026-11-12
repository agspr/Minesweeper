import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/screens/home_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// El armazón: quién enseña la barra inferior y quién se la lleva.
///
/// Mientras se juega la barra **desaparece del árbol** para que el tablero se
/// quede su alto, y en su sitio queda una franja del alto de la barra de
/// gestos. Las dos mitades importan: sin la franja, el numpad se metería debajo
/// de la raya del iPhone; sin quitar la barra, no se habría ganado nada.
///
/// Y con la barra fuera, la X de la cabecera es la ÚNICA salida de una partida:
/// si dejara de funcionar, no habría forma de volver al menú.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final p = generate(seed: 5, target: Difficulty.easy)!;
  const inset = EdgeInsets.only(top: 59, bottom: 34);

  Future<void> montar(WidgetTester tester) async {
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

    await tester.pumpWidget(
      testApp(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(padding: inset, viewPadding: inset),
          child: HomeScreen(
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
            notifications: NotificationsService(
              firebaseReady: false,
              gameId: nonaGameId,
            ),
            prefs: prefs,
            // Sin Firebase no hay de dónde leer puntos: la pestaña Social
            // enseña el estado sin sesión, que es lo que se comprueba.
            leaderboard: null,
            purchases: PurchaseService(
              prefs,
              const IapConfig(removeAdsId: 'x'),
            ),
            // Sin banner: el de verdad pregunta su tamaño por un canal de
            // plataforma que aquí no existe. Que se pueda pasar `null` es justo
            // lo que mantiene a las pruebas fuera del SDK de anuncios.
            banner: null,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('en el menú está la barra; en la partida no', (tester) async {
    await montar(tester);
    expect(find.byType(SendaBottomNav), findsOneWidget);

    await tester.tap(find.text('Reto diario'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(
      find.byType(SendaBottomNav),
      findsNothing,
      reason: 'la barra tiene que IRSE del árbol, no atenuarse',
    );
  });

  testWidgets('la X devuelve al menú, con su barra', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Reto diario'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Menú principal'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(SendaBottomNav), findsOneWidget);
  });

  testWidgets('en la partida, la franja de abajo mide el gesto', (
    tester,
  ) async {
    // Es lo que evita que el numpad quede debajo de la raya del iPhone. Si
    // alguien sustituye la franja por `bottomNavigationBar: null`, el hueco
    // vuelve al cuerpo y esta medida se va a cero.
    await montar(tester);
    await tester.tap(find.text('Reto diario'));
    await tester.pump(const Duration(milliseconds: 200));

    final franja = tester.widgetList<Container>(find.byType(Container)).where((
      c,
    ) {
      final size = c.constraints?.maxHeight;
      return size == inset.bottom;
    });
    expect(
      franja,
      isNotEmpty,
      reason: 'no hay ninguna franja del alto de la barra de gestos',
    );
  });
}
