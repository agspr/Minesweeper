import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/sudoku_board.dart';
import 'package:nona/widgets/numpad.dart';

import 'helpers.dart';

/// El numpad: lo que se ve, lo que se toca y lo que vibra.
///
/// Se monta SOLO, sin pantalla alrededor, a propósito: dentro de una pantalla,
/// `find.text('5')` encuentra también los cincos del tablero, y una prueba que
/// toca "el primero que salga" no prueba lo que dice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final vibraciones = <String>[];

  setUp(() {
    vibraciones.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            vibraciones.add(call.arguments as String? ?? 'larga');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  int golpes() =>
      vibraciones.where((v) => v == 'HapticFeedbackType.lightImpact').length;

  final puzzle = generate(seed: 11, target: Difficulty.easy)!;

  /// Un tablero con el dígito [lleno] ya colocado nueve veces, para probar la
  /// tecla apagada.
  SudokuBoard tableroCon({int? lleno}) {
    final b = SudokuBoard.fromStrings(
      givens: puzzle.givens,
      solution: puzzle.solution,
    );
    if (lleno != null) {
      for (var i = 0; i < cellCount; i++) {
        if (b.solution[i] == lleno && !b.isGiven(i)) b.entries[i] = lleno;
      }
    }
    return b;
  }

  Widget montar(
    SudokuBoard b, {
    bool enabled = true,
    bool notesMode = false,
    bool boardColourOn = true,
    ValueChanged<int>? onDigit,
    VoidCallback? onToggleBoardColour,
  }) => testApp(
    Scaffold(
      body: Numpad(
        board: b,
        notesMode: notesMode,
        enabled: enabled,
        onDigit: onDigit ?? (_) {},
        onErase: () {},
        onToggleNotes: () {},
        onUndo: () {},
        boardColourOn: boardColourOn,
        onToggleBoardColour: onToggleBoardColour ?? () {},
      ),
    ),
  );

  testWidgets('las teclas no llevan cuántas quedan', (tester) async {
    // El contador iba debajo del dígito. Cada dígito tiene que aparecer UNA
    // vez en el numpad: la tecla y nada más.
    await tester.pumpWidget(montar(tableroCon()));
    for (var d = 1; d <= boardSize; d++) {
      expect(
        find.text('$d'),
        findsOneWidget,
        reason: 'el $d sale más de una vez: ¿volvió el contador?',
      );
    }
    // Y el punto que marcaba "ya están las nueve" tampoco.
    expect(find.text('·'), findsNothing);
  });

  testWidgets('las acciones son solo iconos, con su nombre en el tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(montar(tableroCon()));
    for (final nombre in ['Deshacer', 'Borrar', 'Notas', 'Tablero en color']) {
      expect(find.byTooltip(nombre), findsOneWidget, reason: nombre);
      expect(
        find.text(nombre),
        findsNothing,
        reason: '$nombre volvió a pintar su etiqueta',
      );
    }
  });

  testWidgets('el modo notas cambia el icono, no solo el color', (
    tester,
  ) async {
    // Regla de los dos canales: con el acento elegible, un estado no puede
    // distinguirse solo por tono.
    await tester.pumpWidget(montar(tableroCon()));
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.pumpWidget(montar(tableroCon(), notesMode: true));
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('pulsar un dígito vivo da UN golpe corto', (tester) async {
    var pulsado = 0;
    await tester.pumpWidget(montar(tableroCon(), onDigit: (_) => pulsado++));

    await tester.tap(find.text('5'));
    await tester.pump();

    expect(pulsado, 1);
    expect(golpes(), 1);
    // Se afirma la lista ENTERA, no la ausencia de una etiqueta concreta.
    // Antes esto decía «no aparece 'larga'», y eso dependía de que la
    // vibración de fallo siguiera siendo justo esa primitiva: el día que
    // `NonaHaptics.mistake` cambie —y ha cambiado—, el guardia se queda verde
    // sin comprobar nada, que es peor que no tenerlo. Así caza el cableado
    // equivocado use la primitiva que use.
    expect(
      vibraciones,
      ['HapticFeedbackType.lightImpact'],
      reason: 'una tecla del numpad da su golpe y NADA más',
    );
  });

  testWidgets('una tecla apagada no vibra ni llama a nadie', (tester) async {
    // Un tic significa "ha entrado". Una tecla que no hace nada tiene que
    // quedarse muda, o el tic dejaría de significar eso.
    var pulsado = 0;
    await tester.pumpWidget(
      montar(tableroCon(lleno: 4), onDigit: (_) => pulsado++),
    );

    await tester.tap(find.text('4'));
    await tester.pump();

    expect(pulsado, 0, reason: 'el 4 ya está las nueve veces');
    expect(golpes(), 0);
  });

  testWidgets('con la partida terminada, los dígitos no vibran', (
    tester,
  ) async {
    await tester.pumpWidget(montar(tableroCon(), enabled: false));
    await tester.tap(find.text('7'));
    await tester.pump();
    expect(golpes(), 0);
  });

  testWidgets('la tecla de color sigue viva con la partida terminada', (
    tester,
  ) async {
    // Es una preferencia de VISTA, no una jugada: el tablero se sigue viendo
    // debajo del resultado.
    var alternado = 0;
    await tester.pumpWidget(
      montar(
        tableroCon(),
        enabled: false,
        onToggleBoardColour: () => alternado++,
      ),
    );

    await tester.tap(find.byTooltip('Tablero en color'));
    await tester.pump();

    expect(alternado, 1);
    expect(golpes(), 1);
  });
}
