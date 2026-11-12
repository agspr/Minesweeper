import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// **Que lo que trae el paquete esté ENCHUFADO en Nona.**
///
/// El comportamiento y la geometría los prueba el paquete; lo que aquí puede
/// fallar es distinto y no lo cubre nadie más: que Nona pase el flag, que la
/// barra se rehaga sola al llegar una solicitud, y que el gesto de volver esté
/// envuelto. Los tres fallan en silencio — `alert` tiene valor por omisión, así
/// que olvidarlo COMPILA y no rompe ninguna prueba existente.
class _Amigos extends FriendsService {
  _Amigos() : super(firebaseReady: false, gameId: nonaGameId);
  void avisar() => notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final p = generate(seed: 5, target: Difficulty.easy)!;
  const inset = EdgeInsets.only(top: 59, bottom: 34);

  Future<void> montar(WidgetTester tester, {FriendsService? friends}) async {
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
            friends:
                friends ??
                FriendsService(firebaseReady: false, gameId: nonaGameId),
            notifications: NotificationsService(
              firebaseReady: false,
              gameId: nonaGameId,
            ),
            prefs: prefs,
            leaderboard: null,
            purchases: PurchaseService(
              prefs,
              const IapConfig(removeAdsId: 'x'),
            ),
            banner: null,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  Friendship entrante() => Friendship(
    id: 'me_ana',
    otherUid: 'ana',
    status: 'pending',
    requestedByMe: false,
  );

  group('el punto rojo de la pestaña Social', () {
    testWidgets('sin solicitudes no sale', (tester) async {
      await montar(tester);
      expect(find.byType(SendaAlertDot), findsNothing);
    });

    testWidgets('con una RECIBIDA sale', (tester) async {
      await montar(tester, friends: _Amigos()..friendships = [entrante()]);
      expect(find.byType(SendaAlertDot), findsOneWidget);
    });

    testWidgets('y se enciende SOLO, sin cambiar de pestaña', (tester) async {
      // Esta es la que caza olvidar el `ListenableBuilder`: sin él el punto
      // solo aparecería en la siguiente reconstrucción, o sea al tocar algo.
      final f = _Amigos();
      await montar(tester, friends: f);
      expect(find.byType(SendaAlertDot), findsNothing);

      f
        ..friendships = [entrante()]
        ..avisar();
      await tester.pump();
      expect(find.byType(SendaAlertDot), findsOneWidget);
    });
  });

  testWidgets('el gesto de volver saca del tablero al menú', (tester) async {
    // André lo encontró en su Android: el swipe sacaba al escritorio. Lo que
    // se juega es un estado y no una ruta, así que el gesto no tenía nada que
    // cerrar.
    await montar(tester);
    await tester.tap(find.text('Reto diario'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(GameScreen),
      findsNothing,
      reason: 'el gesto tiene que devolver al menú, no cerrar la app',
    );
    expect(find.byType(SendaBottomNav), findsOneWidget, reason: 'menú');
  });
}
