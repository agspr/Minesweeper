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

/// La pestaña Social de Nona: un MARCADOR, igual que el de CINCO.
///
/// Las solicitudes y las invitaciones no viven aquí, viven detrás del icono de
/// persona, en Amigos. Esta prueba cuida las dos mitades de eso: que la
/// pestaña no se convierta otra vez en la pantalla de Amigos, y que las
/// pantallas del paquete se puedan montar bajo los delegados y la marca de
/// Nona — que es lo único que las pruebas del paquete no pueden comprobar.
/// Nadie más en la lista: lo que se comprueba aquí es que la pantalla del
/// paquete se monta bajo Nona, no cómo ordena las filas — eso ya lo cubren las
/// pruebas del paquete, y repetirlo aquí sería mantener lo mismo dos veces.
class _FuenteFalsa implements LeaderboardSource {
  @override
  Future<Map<String, ProgressSummary>> summariesFor(
    Iterable<String> uids,
  ) async => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final p = generate(seed: 5, target: Difficulty.easy)!;

  setUp(() {
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
  });

  testWidgets('sin Firebase, la Social invita a entrar y nada más', (
    tester,
  ) async {
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
          auth: AuthController(firebaseReady: false, prefs: prefs),
          friends: FriendsService(firebaseReady: false),
          purchases: PurchaseService(prefs, const IapConfig(removeAdsId: 'x')),
          notifications: NotificationsService(
            firebaseReady: false,
            gameId: nonaGameId,
          ),
          leaderboard: null,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byIcon(Icons.leaderboard_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(SendaSocialSignedOut), findsOneWidget);
    // Lo que NO puede estar: la pestaña ya no es la pantalla de Amigos.
    expect(find.byType(SendaFriendsScreen), findsNothing);
    expect(find.text('PENDIENTES'), findsNothing);
  });

  testWidgets('el marcador del paquete se monta con la marca de Nona', (
    tester,
  ) async {
    // Nona pone sus delegados y su marca; el paquete pone la pantalla. Si esa
    // costura se rompe —falta un delegado, la marca no llega— revienta con un
    // "Null check operator used on a null value" que no dice nada de eso.
    await tester.pumpWidget(
      testApp(
        SendaLeaderboardScreen(
          friends: FriendsService(firebaseReady: false),
          leaderboard: _FuenteFalsa(),
          gameId: nonaGameId,
          myUid: 'yo',
          mySummary: ProgressSummary(
            totalPoints: 40,
            weekPoints: 40,
            // El id tiene que ser el de la semana EN CURSO o el marcador lo
            // cuenta como cero: son puntos de otra semana.
            weekId: weekIdFor(DateTime.now()),
          ),
          onOpenFriends: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    // El marcador no lleva solicitudes: eso está en Amigos.
    expect(find.text('PENDIENTES'), findsNothing);
  });

  testWidgets('Amigos se monta con la marca de Nona y sin sugerencias', (
    tester,
  ) async {
    // `kInvitesEnabled` está en false hasta que las invitaciones funcionen de
    // punta a punta. Un "+" que no manda nada promete algo que no cumple.
    await tester.pumpWidget(
      testApp(
        SendaFriendsScreen(
          friends: FriendsService(firebaseReady: false),
          gameId: nonaGameId,
          notifications: NotificationsService(
            firebaseReady: false,
            gameId: nonaGameId,
          ),
          invitesEnabled: kInvitesEnabled,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PENDIENTES'), findsOneWidget);
    expect(find.text('AÑADIR AMIGO'), findsOneWidget);
    expect(
      find.text('TUS AMIGOS QUE AÚN NO LO TIENEN'),
      findsNothing,
      reason: 'las invitaciones aún no funcionan: la sección no se pinta',
    );
  });

  test('las invitaciones siguen apagadas', () {
    // Un recordatorio con forma de prueba: encenderlas es una línea, y tiene
    // que ir DESPUÉS de que `onInvite` esté desplegada. Si alguien la cambia
    // sin querer, esto lo dice.
    expect(kInvitesEnabled, isFalse);
  });
}
