import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/screens/practice_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:nona/widgets/escenas_del_final.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **Los anuncios a pantalla completa de Nona** (André, 4-10-2026: «Nona
/// should absolutely be showing them too»).
///
/// Nona no los enseñó NUNCA: las unidades estaban en `nona_config` desde el
/// principio, pero nada creaba el `AdManager`. Aquí se vigila cuándo salen,
/// que es lo que el paquete no puede saber por el juego:
///
/// - **el del día**, debido desde que se resuelve —cerrar la app no lo salta—,
///   y enseñado tras el respiro y ANTES de la celebración, que espera detrás;
/// - el día de un **hito**, la reseña ocupa su sitio, y nunca van seguidos;
/// - una **repetición** (abrir una diaria ya hecha) no debe ni enseña nada;
/// - en la **práctica**, cada partida terminada se apunta, y la pausa entre
///   una y otra es donde puede salir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final p = generate(seed: 5, target: Difficulty.easy)!;
  const dia = '2026-08-18';

  Future<(DailyController, ProgressController, List<String>)> montarDiaria(
    WidgetTester tester, {
    required _Anuncios ads,
    _Resenas? resenas,
    int diasAntes = 0,
  }) async {
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      dia: {
        'givens': p.givens,
        'solution': p.solution,
        'difficulty': 'easy',
        'clues': p.clueCount,
      },
    });
    final prefs = await SharedPreferences.getInstance();
    final progress = ProgressController(prefs);
    // Una racha previa: los días justo antes del de hoy, terminados.
    for (var i = diasAntes; i >= 1; i--) {
      final d = DateTime(2026, 8, 18 - i);
      progress.record(
        scoreDaily(
          DailyOutcome(
            dayKey: dayKeyFor(d),
            difficulty: Difficulty.easy,
            completed: true,
            mistakes: 0,
            completionPercent: 100,
            seconds: 0,
          ),
        ),
        d,
      );
    }
    final daily = DailyController(
      prefs,
      clock: () => DateTime(2026, 8, 18, 10),
    );
    await daily.load();
    final salidas = <String>[];
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: GameScreen(
            controller: daily,
            progress: progress,
            theme: ThemeController(prefs),
            friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
            purchases: PurchaseService(prefs, nonaConfig.iap),
            ads: ads,
            resenas: resenas,
            onExit: () => salidas.add('menú'),
            onPractice: () => salidas.add('práctica'),
          ),
        ),
      ),
    );
    await tester.pump();
    return (daily, progress, salidas);
  }

  void resolver(DailyController c) {
    for (var i = 0; i < cellCount; i++) {
      if (c.board!.isGiven(i)) continue;
      c.select(i);
      c.tapDigit(c.board!.solution[i]);
    }
  }

  final escenas = find.byType(EscenasDelFinal);

  group('el del día', () {
    testWidgets('se debe al resolver, sale tras el respiro, y la celebración '
        'espera detrás', (tester) async {
      final ads = _Anuncios(await SharedPreferences.getInstance());
      final (daily, _, _) = await montarDiaria(tester, ads: ads);
      resolver(daily);
      await tester.pump();
      // Debido en el acto: quien cierre la app ahora lo verá en la próxima
      // pausa.
      expect(ads.llamadas, containsAllInOrder(['debe:$dia', 'precarga:$dia']));
      expect(ads.llamadas, isNot(contains('anuncio:$dia')));

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(ads.llamadas.last, 'anuncio:$dia');
      // Con el anuncio en pantalla, la celebración todavía no.
      await tester.pump(const Duration(milliseconds: 500));
      expect(escenas, findsNothing);

      ads.cierraElAnuncio();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(escenas, findsOneWidget);
    });

    testWidgets('salir antes del respiro no lo salta: queda debido', (
      tester,
    ) async {
      final ads = _Anuncios(await SharedPreferences.getInstance());
      final (daily, _, _) = await montarDiaria(tester, ads: ads);
      resolver(daily);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(ads.llamadas, contains('debe:$dia'));
      expect(ads.llamadas, isNot(contains('anuncio:$dia')));
    });

    testWidgets('el día de un hito, la reseña en su lugar, y después', (
      tester,
    ) async {
      final ads = _Anuncios(await SharedPreferences.getInstance());
      final resenas = _Resenas(await SharedPreferences.getInstance());
      // Nueve días seguidos antes: hoy la racha llega a 10, un hito.
      final (daily, _, _) = await montarDiaria(
        tester,
        ads: ads,
        resenas: resenas,
        diasAntes: 9,
      );
      resolver(daily);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ads.llamadas, contains('saldada'));
      expect(ads.llamadas, isNot(contains('anuncio:$dia')));
      expect(escenas, findsOneWidget);
      expect(
        resenas.pedidas,
        0,
        reason: 'la reseña va DESPUÉS de la celebración',
      );

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 3));
        await tester.tap(find.byKey(const ValueKey('principal')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpAndSettle();
      expect(resenas.pedidas, 1);
    });

    testWidgets('un día normal no pide la reseña aunque tocara', (
      tester,
    ) async {
      final ads = _Anuncios(await SharedPreferences.getInstance());
      final resenas = _Resenas(await SharedPreferences.getInstance());
      final (daily, _, _) = await montarDiaria(
        tester,
        ads: ads,
        resenas: resenas,
        diasAntes: 3,
      );
      resolver(daily);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      ads.cierraElAnuncio();
      await tester.pumpAndSettle();
      expect(ads.llamadas, contains('anuncio:$dia'));
      expect(resenas.pedidas, 0);
    });

    testWidgets('abrir una diaria ya hecha no debe ni enseña nada', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final primera = _Anuncios(prefs);
      final (daily, _, _) = await montarDiaria(tester, ads: primera);
      resolver(daily);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      primera.cierraElAnuncio();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());

      final otra = _Anuncios(prefs);
      await montarDiaria(tester, ads: otra);
      await tester.pump(const Duration(seconds: 3));
      expect(escenas, findsOneWidget, reason: 'la repetición');
      expect(otra.llamadas.where((x) => !x.startsWith('precarga')), isEmpty);
    });
  });

  group('la práctica', () {
    testWidgets('cada partida terminada muestra el anuncio inmediatamente al terminar', (tester) async {
      // Generar un puzle va en un isolate, que en el tiempo falso de las
      // pruebas no termina: se carga fuera, con `runAsync`, como en
      // `practice_screen_test`.
      late PracticeController practica;
      late SharedPreferences prefs;
      await tester.runAsync(() async {
        prefs = await SharedPreferences.getInstance();
        practica = PracticeController(prefs);
        await practica.load();
      });
      final ads = _Anuncios(prefs);
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: PracticeScreen(
              controller: practica,
              theme: ThemeController(prefs),
              ads: ads,
              onExit: () {},
            ),
          ),
        ),
      );
      // El mismo nivel que ya estaba: no regenera.
      await tester.tap(
        find.text(switch (practica.difficulty) {
          Difficulty.easy => 'Fácil',
          Difficulty.medium => 'Medio',
          Difficulty.hard => 'Difícil',
        }),
      );
      await tester.pump();
      final b = practica.board!;
      for (var i = 0; i < cellCount; i++) {
        if (b.isGiven(i)) continue;
        practica.select(i);
        practica.tapDigit(b.solution[i]);
      }
      // Al resolver, se anota la partida y se muestra el anuncio inmediatamente
      // tras el respiro de 300 ms, sin necesidad de esperar a "Seguir jugando".
      await tester.pump();
      expect(ads.llamadas.where((x) => x == 'partida'), hasLength(1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(ads.llamadas, contains('pausa'));

      await tester.tap(find.text('Seguir jugando'));
      await tester.pump();
      expect(practica.generating, isTrue, reason: 'y empieza otra');
    });

    testWidgets('respeta un enfriamiento mínimo de 15 s desde que se cierra '
        'un anuncio hasta el siguiente', (tester) async {
      late PracticeController practica;
      late SharedPreferences prefs;
      await tester.runAsync(() async {
        prefs = await SharedPreferences.getInstance();
        practica = PracticeController(prefs);
        await practica.load();
      });
      final ads = _Anuncios(prefs)..mostrarEnPausa = true;
      var ahora = DateTime(2026, 11, 9, 12, 0, 0);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: PracticeScreen(
              controller: practica,
              theme: ThemeController(prefs),
              ads: ads,
              clock: () => ahora,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.tap(
        find.text(switch (practica.difficulty) {
          Difficulty.easy => 'Fácil',
          Difficulty.medium => 'Medio',
          Difficulty.hard => 'Difícil',
        }),
      );
      await tester.pump();

      void resolverTableroActual() {
        final b = practica.board!;
        for (var i = 0; i < cellCount; i++) {
          if (b.isGiven(i)) continue;
          practica.select(i);
          practica.tapDigit(b.solution[i]);
        }
      }

      // 1ª partida terminada -> muestra el primer anuncio inmediatamente al resolver (t = 0s).
      resolverTableroActual();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(ads.llamadas.where((x) => x == 'pausa'), hasLength(1));

      Future<void> pasarASiguienteTablero() async {
        await tester.runAsync(() async {
          await practica.newPuzzle();
        });
        await tester.pump();
      }

      // Empezar nuevo puzle
      await pasarASiguienteTablero();

      // 2ª partida terminada a los 8s (< 15s) -> NO debe mostrar otro anuncio.
      ahora = ahora.add(const Duration(seconds: 8));
      resolverTableroActual();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        ads.llamadas.where((x) => x == 'pausa'),
        hasLength(1),
        reason: 'dentro de los 15 s de enfriamiento no debe salir otro anuncio',
      );

      // Empezar nuevo puzle
      await pasarASiguienteTablero();

      // 3ª partida terminada a los 16s desde el 1er anuncio (>= 15s) -> SÍ sale de inmediato.
      ahora = ahora.add(const Duration(seconds: 8));
      resolverTableroActual();
      await tester.pump();
      expect(ads.llamadas.where((x) => x == 'partida'), hasLength(3));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        ads.llamadas.where((x) => x == 'pausa'),
        hasLength(2),
        reason: 'pasados los 15 s de enfriamiento vuelve a permitir el anuncio de inmediato',
      );
    });
  });
}

/// Un `AdManager` que apunta lo que se le pide, y que tiene el anuncio del día
/// «en pantalla» hasta que la prueba lo cierra.
class _Anuncios extends AdManager {
  _Anuncios(SharedPreferences prefs)
    : super(ConsentManager(), prefs, nonaConfig.ads);

  final llamadas = <String>[];
  Completer<bool>? _enPantalla;
  bool mostrarEnPausa = false;

  void cierraElAnuncio() => _enPantalla?.complete(true);

  @override
  Future<void> deberElDelDia(String dayKey) async =>
      llamadas.add('debe:$dayKey');

  @override
  Future<void> preloadFor(String dayKey) async =>
      llamadas.add('precarga:$dayKey');

  @override
  Future<bool> maybeShowAfterPuzzle(
    String dayKey, {
    Duration timeout = const Duration(seconds: 1),
  }) {
    llamadas.add('anuncio:$dayKey');
    return (_enPantalla = Completer<bool>()).future;
  }

  @override
  Future<void> saldarDelDia() async => llamadas.add('saldada');

  @override
  Future<void> anotarPartida() async => llamadas.add('partida');

  @override
  Future<bool> mostrarSiToca() async {
    llamadas.add('pausa');
    return mostrarEnPausa;
  }
}

/// La reseña, siempre «toca», contando las veces que se pide.
class _Resenas extends SendaResenas {
  _Resenas(super.prefs);

  int pedidas = 0;

  @override
  bool get toca => true;

  @override
  Future<bool> pedirSiToca() async {
    pedidas++;
    return true;
  }
}
