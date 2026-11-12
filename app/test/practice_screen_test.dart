import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/screens/practice_screen.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:nona/widgets/numpad.dart';
import 'package:nona/widgets/sudoku_board_view.dart';

import 'helpers.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Los botones de "Pista" y "Otro puzle" no reaccionaban en el simulador aunque
/// `PracticeController.hint()` pasaba sus pruebas: el fallo estaba en la
/// pantalla, no en la lógica, y solo lo caza pulsar los botones de verdad.
///
/// Nota sobre `runAsync`: `testWidgets` corre en una zona de tiempo FALSO, y
/// `compute()` levanta un isolate real cuyo resultado llega por el bucle de
/// eventos de verdad. Sin `runAsync`, generar un puzle no termina nunca y la
/// prueba se cuelga —pasó, y cuesta un rato entenderlo—.
String _labelDe(Difficulty d) => switch (d) {
  Difficulty.easy => 'Fácil',
  Difficulty.medium => 'Medio',
  Difficulty.hard => 'Difícil',
};

void main() {
  ThemeController? theme;
  int salidas = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    salidas = 0;
    theme = ThemeController(await SharedPreferences.getInstance());
  });

  Widget wrap(PracticeController c) => testApp(
    PracticeScreen(controller: c, theme: theme!, onExit: () => salidas++),
  );

  Future<PracticeController> loadedIn(WidgetTester tester) async {
    late PracticeController c;
    await tester.runAsync(() async {
      c = PracticeController(await SharedPreferences.getInstance());
      await c.load();
    });
    return c;
  }

  /// El modo libre abre AHORA en la pantalla de nivel, así que todo lo que
  /// pruebe el tablero tiene que pasar por ahí primero. Se elige el mismo nivel
  /// que ya estaba: `setDifficulty` corta en seco y no regenera, así que el
  /// puzle que cargó `loadedIn` sigue intacto y la prueba no depende de un
  /// isolate.
  Future<void> entrarAlTablero(
    WidgetTester tester,
    PracticeController c,
  ) async {
    expect(
      find.textContaining('dificultad'),
      findsOneWidget,
      reason: 'el modo libre debe abrir en la pantalla de nivel',
    );
    await tester.tap(find.text(_labelDe(c.difficulty)));
    await tester.pump();
  }

  void sized(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('cambiar entre Senda y Clásico responde al toque en la pantalla de nivel', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    expect(c.gameMode, PracticeGameMode.senda);
    await tester.tap(find.text('Clásico (1 vida)'));
    await tester.pump();
    expect(c.gameMode, PracticeGameMode.classic);

    await tester.tap(find.text('Senda (3 vidas)'));
    await tester.pump();
    expect(c.gameMode, PracticeGameMode.senda);
  });

  testWidgets('mientras se juega NO hay pastillas de control ni numpad bajo el tablero', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    expect(find.byType(Numpad), findsNothing);
    expect(find.text('Pista'), findsNothing);
    expect(find.text('Cavar'), findsNothing);
    expect(find.text('Marcar'), findsNothing);
    expect(find.text('Seguir jugando'), findsNothing);
    expect(find.text('Menú principal'), findsNothing);
  });

  testWidgets('al resolver salen "Seguir jugando" y "Menú principal"', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    // Se resuelve el tablero de golpe.
    for (var i = 0; i < cellCount; i++) {
      c.board!.entries[i] = c.board!.solution[i];
    }
    await tester.pumpWidget(wrap(c));
    await tester.pump();

    expect(c.isComplete, isTrue);
    expect(find.text('Seguir jugando'), findsOneWidget);
    expect(find.text('Menú principal'), findsOneWidget);
  });

  testWidgets('"Menú principal" del final vuelve al menú', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);
    for (var i = 0; i < cellCount; i++) {
      c.board!.entries[i] = c.board!.solution[i];
    }
    await tester.pumpWidget(wrap(c));
    await tester.pump();

    await tester.tap(find.text('Menú principal'));
    await tester.pump();
    expect(salidas, 1);
  });

  testWidgets('la pulsación larga alterna la bandera en una casilla oculta', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    expect(c.board!.isFlagged(0), isFalse);
    c.longPressCellOnBoard(0);
    await tester.pump();
    expect(c.board!.isFlagged(0), isTrue);

    c.longPressCellOnBoard(0);
    await tester.pump();
    expect(c.board!.isFlagged(0), isFalse);
  });

  testWidgets('la pantalla de nivel se ve al entrar, con los tres niveles', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    // El tablero NO está todavía: primero se elige.
    expect(find.byType(SudokuBoardView), findsNothing);
    for (final n in ['Fácil', 'Medio', 'Difícil']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    // Y cada uno dice QUÉ cambia: "Fácil" a secas no informa de nada.
    expect(find.textContaining('pistas'), findsWidgets);
  });

  testWidgets('elegir el MISMO nivel no tira el puzle a medias', (
    tester,
  ) async {
    // Es la promesa de la pantalla: entrar, elegir igual y seguir donde
    // estabas. Si `setDifficulty` dejara de cortar en seco, esto se rompe y
    // quien entre a mirar el nivel perdería la partida.
    sized(tester);
    final c = await loadedIn(tester);
    final antes = List<int>.from(c.board!.givens);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    expect(c.generating, isFalse, reason: 'no debería regenerar nada');
    expect(c.board!.givens, antes, reason: 'el puzle cambió al elegir igual');
    expect(find.byType(SudokuBoardView), findsOneWidget);
  });

  testWidgets('la X de la pantalla de nivel vuelve al menú', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    await tester.tap(find.byTooltip('Menú principal'));
    await tester.pump();
    expect(
      salidas,
      1,
      reason: 'sin esto, la pantalla de nivel no tiene salida',
    );
  });

  testWidgets('la X vuelve al menú', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    await tester.tap(find.byTooltip('Menú principal'));
    await tester.pump();
    expect(salidas, 1, reason: 'la X no llegó al armazón');
  });

  testWidgets('tocar una pista con sus minas marcadas ejecuta el acorde automáticamente', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    final b = c.board!;
    // Encontrar una casilla segura con pista > 0
    var clueCell = -1;
    for (var i = 0; i < b.boardCellCount; i++) {
      if (!b.isMine(i)) {
        b.reveal(i);
        if (b.clueAt(i) > 0) {
          clueCell = i;
          break;
        }
      }
    }
    expect(clueCell, greaterThanOrEqualTo(0));

    // Abanderar las minas vecinas
    final clue = b.clueAt(clueCell);
    var flagsPlaced = 0;
    for (final n in b.neighborsOf(clueCell)) {
      if (b.isMine(n) && flagsPlaced < clue) {
        b.toggleFlag(n);
        flagsPlaced++;
      }
    }
    expect(flagsPlaced, clue);

    // Al tocar la casilla de la pista, se ejecuta el acorde y se descubren
    // todas las demás vecinas seguras sin necesidad de tocar una a una.
    c.tapCellOnBoard(clueCell);
    await tester.pump();

    for (final n in b.neighborsOf(clueCell)) {
      if (!b.isMine(n)) {
        expect(b.isRevealed(n), isTrue, reason: 'la vecina segura $n debió ser descubierta por el acorde');
      }
    }
  });
}
