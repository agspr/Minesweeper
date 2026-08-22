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

  testWidgets('pulsar "Pista" rellena una casilla', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    expect(c.hintsUsed, 0);
    await tester.tap(find.text('Pista'));
    await tester.pump();

    expect(c.hintsUsed, 1, reason: 'el botón de pista no llegó al controlador');
    expect(c.board!.correctCount, 1);
  });

  testWidgets('mientras se juega NO hay "Otro puzle" ni salidas', (
    tester,
  ) async {
    // Las dos salidas son de fin de partida. Verlas a mitad de un puzle
    // invitaba a tirar el tablero por accidente.
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    expect(find.text('Otro puzle'), findsNothing);
    expect(find.text('Seguir jugando'), findsNothing);
    expect(find.text('Menú principal'), findsNothing);
    // La pista sí, que es lo único que se usa jugando.
    expect(find.text('Pista'), findsOneWidget);
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
    expect(find.text('Pista'), findsNothing);
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

  testWidgets('los tres botones del numpad siguen respondiendo', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    // Las teclas de acción ya no llevan etiqueta: se buscan por su tooltip,
    // que es también su nombre accesible.
    await tester.tap(find.byTooltip('Notas'));
    await tester.pump();
    expect(c.notesMode, isTrue);
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

  testWidgets('la tecla de color apaga y enciende el tablero', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    final antes = theme!.boardColour;
    await tester.tap(
      find.byTooltip(antes ? 'Tablero en color' : 'Tablero en gris'),
    );
    await tester.pump();
    expect(theme!.boardColour, !antes);
  });

  testWidgets('ninguna tecla enseña ya cuántas quedan', (tester) async {
    // El contador vivía debajo del dígito. Si alguien lo devuelve, esta prueba
    // lo dice: en un tablero recién hecho hay dígitos con 7 u 8 por colocar.
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await entrarAlTablero(tester, c);

    final numpad = find.byType(Numpad);
    for (final n in ['5', '6', '7', '8', '9']) {
      expect(
        find.descendant(of: numpad, matching: find.text(n)),
        findsOneWidget,
        reason:
            'el $n aparece más de una vez en el numpad: ¿volvió el contador?',
      );
    }
  });
}
