import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/game/sudoku_board.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:nona/widgets/numpad.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **Un número puesto no se pisa: primero se borra** (André, 22-10-2026).
///
/// Las quejas: rozar otra tecla cambiaba un número bueno por uno malo, y ese
/// fallo contaba para siempre. Ahora la cifra sobre una casilla ocupada no hace
/// nada, y sale un aviso desde abajo: «Usa el botón de borrar para quitarlo
/// primero». Lo que se vigila: que no cambie nada ni cuente, que el aviso salga
/// solo cuando toca, y que no tape la tecla que manda tocar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final p = generate(seed: 5, target: Difficulty.easy)!;
  const hoy = '2026-08-18';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      hoy: {
        'givens': p.givens,
        'solution': p.solution,
        'difficulty': 'easy',
        'clues': p.clueCount,
      },
    });
  });

  SudokuBoard tablero() =>
      SudokuBoard.fromStrings(givens: p.givens, solution: p.solution);
  int primeraVacia(SudokuBoard b) =>
      List.generate(cellCount, (i) => i).firstWhere((i) => !b.isGiven(i));
  int otra(int d) => d == 9 ? 1 : d + 1;

  group('el tablero', () {
    test('no pisa un número puesto, ni bueno ni malo', () {
      final b = tablero();
      final c = primeraVacia(b);
      final bien = b.solution[c];

      b.place(c, bien);
      expect(b.place(c, otra(bien)), isFalse);
      expect(b.entries[c], bien, reason: 'el bueno sigue');
      expect(b.mistakes, 0, reason: 'y no cuenta un fallo');

      b.erase(c);
      b.place(c, otra(bien));
      expect(b.place(c, otra(otra(bien))), isFalse);
      expect(b.entries[c], otra(bien));
      expect(b.mistakes, 1, reason: 'solo el primero que entró');
    });

    test('borrado primero, se escribe', () {
      final b = tablero();
      final c = primeraVacia(b);
      final bien = b.solution[c];
      b.place(c, otra(bien));
      b.erase(c);
      b.place(c, bien);
      expect(b.entries[c], bien);
    });

    test('la pista del modo libre sí cambia el malo por el bueno', () {
      final b = tablero();
      final c = primeraVacia(b);
      b.place(c, otra(b.solution[c]));
      b.place(c, b.solution[c], sobrescribir: true);
      expect(b.entries[c], b.solution[c]);
    });

    test('«ocupada» es lo puesto por quien juega, no las pistas', () {
      final b = tablero();
      final c = primeraVacia(b);
      final pista = List.generate(cellCount, (i) => i).firstWhere(b.isGiven);
      expect(b.ocupada(c), isFalse);
      expect(b.ocupada(pista), isFalse);
      b.place(c, b.solution[c]);
      expect(b.ocupada(c), isTrue);
    });
  });

  group('la diaria', () {
    Future<DailyController> diaria() async {
      final c = DailyController(
        await SharedPreferences.getInstance(),
        clock: () => DateTime(2026, 8, 18, 10),
      );
      await c.load();
      return c;
    }

    test(
      'otra cifra sobre un número: nada cambia, no es jugada, y avisa',
      () async {
        final c = await diaria();
        final cel = primeraVacia(c.board!);
        final bien = c.board!.solution[cel];
        c.select(cel);
        c.tapDigit(bien);
        final antes = c.estadoGuardado!;

        expect(c.tapDigit(otra(bien)), isFalse);
        expect(c.board!.entries[cel], bien);
        expect(c.estadoGuardado!['jugadas'], antes['jugadas']);
        expect(c.estadoGuardado!['mistakes'], 0);
        expect(c.intentosDeSobrescribir.value, 1);
      },
    );

    test('avisa también en modo notas, que tampoco hace nada ahí', () async {
      final c = await diaria();
      final cel = primeraVacia(c.board!);
      c.select(cel);
      c.tapDigit(c.board!.solution[cel]);
      c.toggleNotesMode();
      // La MISMA cifra: fuera de notas no haría nada y no avisaría, pero en
      // notas se intenta anotar en una casilla llena, que tampoco se puede.
      c.tapDigit(c.board!.solution[cel]);
      expect(c.intentosDeSobrescribir.value, 1);
    });

    test(
      'no avisa con la casilla vacía, con una pista, ni con la misma cifra',
      () async {
        final c = await diaria();
        final b = c.board!;
        final cel = primeraVacia(b);
        final pista = List.generate(cellCount, (i) => i).firstWhere(b.isGiven);

        c.select(cel);
        c.tapDigit(b.solution[cel]);
        c.tapDigit(b.solution[cel]);
        c.select(pista);
        c.tapDigit(otra(b.solution[pista]));
        expect(c.intentosDeSobrescribir.value, 0);
      },
    );
  });

  group('la práctica', () {
    Future<PracticeController> practica() async {
      final c = PracticeController(await SharedPreferences.getInstance());
      await c.load();
      return c;
    }

    test('tampoco pisa, y avisa', () async {
      final c = await practica();
      final cel = primeraVacia(c.board!);
      final bien = c.board!.solution[cel];
      c.select(cel);
      c.tapDigit(bien);
      c.tapDigit(otra(bien));
      expect(c.board!.entries[cel], bien);
      expect(c.intentosDeSobrescribir.value, 1);
    });

    test('la pista sigue corrigiendo un número equivocado', () async {
      final c = await practica();
      final cel = primeraVacia(c.board!);
      c.select(cel);
      c.tapDigit(otra(c.board!.solution[cel]));
      c.hint();
      expect(c.board!.entries[cel], c.board!.solution[cel]);
    });
  });

  test('la práctica también lo enseña', () {
    // Montar la práctica pide generar un puzle en un isolate; se mira el
    // cableado en el código, como en `mas_y_social_test`.
    final fuente = File('lib/screens/practice_screen.dart').readAsStringSync();
    expect(fuente, contains('disparo: c.intentosDeSobrescribir'));
    expect(fuente, contains('texto: l.eraseFirst'));
    expect(fuente, contains('ocultarCon: c,'));
  });

  group('el aviso en pantalla', () {
    final aviso = find.text('Usa el botón de borrar para quitarlo primero.');

    Future<DailyController> montar(WidgetTester tester) async {
      late DailyController c;
      late SharedPreferences prefs;
      await tester.runAsync(() async {
        prefs = await SharedPreferences.getInstance();
        c = DailyController(prefs, clock: () => DateTime(2026, 8, 18, 10));
        await c.load();
      });
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: GameScreen(
              controller: c,
              progress: ProgressController(prefs),
              theme: ThemeController(prefs),
              friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
              purchases: PurchaseService(prefs, nonaConfig.iap),
              onExit: () {},
              onPractice: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      return c;
    }

    Future<void> tocarCifra(WidgetTester tester, int d) async {
      final tecla = find.descendant(
        of: find.byType(Numpad),
        matching: find.text('$d'),
      );
      await tester.tap(tecla.first);
      await tester.pump();
    }

    testWidgets('sale al tocar otra cifra, y se va sola', (tester) async {
      final c = await montar(tester);
      final cel = primeraVacia(c.board!);
      final bien = c.board!.solution[cel];
      c.select(cel);
      await tester.pump();
      await tocarCifra(tester, bien);
      expect(c.intentosDeSobrescribir.value, 0);

      await tocarCifra(tester, otra(bien));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.board!.entries[cel], bien);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(of: aviso, matching: find.byType(AnimatedOpacity)),
            )
            .opacity,
        1,
      );

      await tester.pump(const Duration(seconds: 3));
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(of: aviso, matching: find.byType(AnimatedOpacity)),
            )
            .opacity,
        0,
      );
    });

    testWidgets(
      'no tapa la tecla Borrar, y Borrar funciona con él a la vista',
      (tester) async {
        final c = await montar(tester);
        final cel = primeraVacia(c.board!);
        final bien = c.board!.solution[cel];
        c.select(cel);
        await tester.pump();
        await tocarCifra(tester, bien);
        await tocarCifra(tester, otra(bien));
        await tester.pump(const Duration(milliseconds: 300));

        // La del numpad: el aviso lleva el mismo icono.
        final borrar = find.descendant(
          of: find.byType(Numpad),
          matching: find.byIcon(Icons.backspace_outlined),
        );
        final rectAviso = tester.getRect(
          find.ancestor(of: aviso, matching: find.byType(Container)).first,
        );
        expect(
          rectAviso.overlaps(tester.getRect(find.byType(Numpad))),
          isFalse,
          reason: 'el aviso tapa el numpad',
        );

        // Y lo que tape del tablero sigue respondiendo: el aviso deja pasar
        // los toques.
        expect(
          tester
              .widgetList<IgnorePointer>(
                find.ancestor(of: aviso, matching: find.byType(IgnorePointer)),
              )
              .any((w) => w.ignoring),
          isTrue,
        );

        await tester.tap(borrar);
        await tester.pump();
        expect(c.board!.entries[cel], 0, reason: 'Borrar no respondió');
        // Y en cuanto se borra, el aviso se va: en un iPhone SE tapa la fila
        // de abajo del tablero, quizá la casilla que se está corrigiendo.
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.ancestor(
                  of: aviso,
                  matching: find.byType(AnimatedOpacity),
                ),
              )
              .opacity,
          0,
        );
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
