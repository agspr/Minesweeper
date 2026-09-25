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
import 'package:nona/widgets/sin_anuncios.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'escenas_del_final_test.dart' show Tienda;
import 'helpers.dart';

/// La franja de «Quitar anuncios» encima del banner, montada en la app.
///
/// Tres cosas que no se ven sin montar el armazón entero: que sale en el menú
/// y no debajo de un tablero, que entrar en una partida no vuelve a montar el
/// banner —un banner nuevo pide otro anuncio y llega sin hueco reservado—, y
/// que tocarla abre la hoja, no la compra.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final p = generate(seed: 5, target: Difficulty.easy)!;

  Future<Tienda> montar(WidgetTester tester, List<int> bannersMontados) async {
    SharedPreferences.setMockInitialValues({});
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      '2026-08-18': {
        'givens': p.givens,
        'solution': p.solution,
        'difficulty': 'easy',
        'clues': p.clueCount,
      },
    });
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
    final tienda = Tienda(prefs);
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
          leaderboard: null,
          purchases: tienda,
          banner: _Banner(montados: bannersMontados),
        ),
      ),
    );
    await tester.pump();
    return tienda;
  }

  final enlace = find.descendant(
    of: find.byType(FranjaSinAnuncios),
    matching: find.byType(TextButton),
  );

  testWidgets('en el menú, encima del banner; en la partida, no', (
    tester,
  ) async {
    final montados = <int>[];
    await montar(tester, montados);

    expect(enlace, findsOneWidget);
    expect(
      tester.getRect(find.byType(FranjaSinAnuncios)).bottom,
      tester.getRect(find.byType(_Banner)).top,
      reason: 'justo encima del banner, sin taparlo',
    );

    await tester.tap(find.text('Sudoku del día'));
    await tester.pumpAndSettle();
    expect(enlace, findsNothing);
    expect(tester.getSize(find.byType(FranjaSinAnuncios)).height, 0);

    // Y el banner es el mismo: entrar en la partida no lo volvió a montar.
    expect(montados, [1], reason: 'el banner se montó de nuevo');
  });

  testWidgets('su alto está desde el primer fotograma, haya producto o no', (
    tester,
  ) async {
    final tienda = await montar(tester, []);
    tienda.ofrece(false);
    await tester.pump();
    expect(tester.getSize(find.byType(FranjaSinAnuncios)).height, 30);
    final banner = tester.getRect(find.byType(_Banner));
    tienda.ofrece(true);
    await tester.pump();
    expect(tester.getRect(find.byType(_Banner)), banner);
  });

  testWidgets('tocarla abre la hoja; no compra', (tester) async {
    final tienda = await montar(tester, []);
    await tester.tap(enlace);
    await tester.pumpAndSettle();
    expect(find.byType(HojaSinAnuncios), findsOneWidget);
    expect(tienda.compras, 0);
  });

  testWidgets('con la compra hecha se va, con el banner', (tester) async {
    final tienda = await montar(tester, []);
    tienda.contesta(conCompra: true);
    await tester.pump();
    expect(enlace, findsNothing);
    expect(tester.getSize(find.byType(FranjaSinAnuncios)).height, 0);
  });
}

/// Un banner de mentira, del alto del grande, que cuenta cuántas veces se
/// monta.
class _Banner extends StatefulWidget {
  const _Banner({required this.montados});

  final List<int> montados;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  @override
  void initState() {
    super.initState();
    widget.montados.add(widget.montados.length + 1);
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: double.infinity, height: 127);
}
