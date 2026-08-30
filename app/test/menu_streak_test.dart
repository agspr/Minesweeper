import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/screens/home_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// La racha del menú: la pieza que sustituye a la franja de estadísticas.
///
/// Se prueba porque su regla es condicional —solo aparece con racha viva— y
/// una condición que nadie ejerce es una condición que nadie ha visto.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final p = generate(seed: 7, target: Difficulty.medium)!;

  Future<void> montar(
    WidgetTester tester,
    Map<String, Object> prefsIniciales,
  ) async {
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      '2026-08-18': {
        'givens': p.givens,
        'solution': p.solution,
        'difficulty': 'medium',
        'clues': p.clueCount,
      },
    });
    SharedPreferences.setMockInitialValues(prefsIniciales);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final prefs = await SharedPreferences.getInstance();
    final daily = DailyController(
      prefs,
      clock: () => DateTime(2026, 8, 18, 10),
    );
    await daily.load();

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
          notifications: NotificationsService(
            firebaseReady: false,
            gameId: nonaGameId,
          ),
          prefs: prefs,
          // Sin Firebase no hay de dónde leer puntos: la pestaña Social
          // enseña el estado sin sesión, que es lo que se comprueba.
          leaderboard: null,
          purchases: PurchaseService(prefs, const IapConfig(removeAdsId: 'x')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// El día de HOY según el reloj real.
  ///
  /// El menú llama a `streakAsOf(DateTime.now())`, no a un reloj inyectado, así
  /// que la prueba tiene que usar el mismo reloj que el widget. Con una fecha
  /// fija la píldora no saldría nunca — y eso es un fallo de la prueba, no del
  /// menú.
  String hoy() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}';
  }

  testWidgets('con racha viva, sale la píldora', (tester) async {
    await montar(tester, {
      'progress.streak': 10,
      'progress.lastPlayedDay': hoy(),
    });
    expect(find.textContaining('🔥'), findsOneWidget);
    expect(find.textContaining('10'), findsOneWidget);
  });

  testWidgets('sin racha, no sale nada', (tester) async {
    await montar(tester, {});
    expect(find.textContaining('🔥'), findsNothing);
  });

  testWidgets('con racha ROTA tampoco sale', (tester) async {
    // Último día terminado hace tres: el contador guardado sigue en 10 pero la
    // racha ya no está viva, y el menú no debe presumir de ella.
    await montar(tester, {
      'progress.streak': 10,
      // Hace mucho: el contador guardado sigue en 10 pero la racha está rota.
      'progress.lastPlayedDay': '2020-01-01',
    });
    expect(find.textContaining('🔥'), findsNothing);
  });

  testWidgets('la franja de estadísticas ya no está en el menú', (
    tester,
  ) async {
    await montar(tester, {'progress.streak': 10});
    expect(find.text('Días jugados'), findsNothing);
    expect(find.text('Mejor racha'), findsNothing);
  });
}
