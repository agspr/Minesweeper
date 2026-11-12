import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/sudoku_board.dart';
import 'package:nona/widgets/numpad.dart';

import 'helpers.dart';

/// Pruebas de los controles de Buscaminas: selector de modo, deshacer y contador.
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

  SudokuBoard tablero() => SudokuBoard.fromStrings(
    givens: puzzle.givens,
    solution: puzzle.solution,
  );

  Widget montar(
    SudokuBoard b, {
    bool enabled = true,
    bool notesMode = false,
    bool boardColourOn = true,
    VoidCallback? onUndo,
    VoidCallback? onToggleNotes,
    VoidCallback? onToggleBoardColour,
  }) => testApp(
    Scaffold(
      body: Numpad(
        board: b,
        notesMode: notesMode,
        enabled: enabled,
        onToggleNotes: onToggleNotes ?? () {},
        onUndo: onUndo ?? () {},
        boardColourOn: boardColourOn,
        onToggleBoardColour: onToggleBoardColour ?? () {},
      ),
    ),
  );

  testWidgets('muestra el selector de modo Cavar y Marcar', (tester) async {
    await tester.pumpWidget(montar(tablero()));
    expect(find.text('Cavar'), findsOneWidget);
    expect(find.text('Marcar'), findsOneWidget);
  });

  testWidgets('cambiar de modo llama a onToggleNotes y emite háptica', (tester) async {
    var toggled = 0;
    await tester.pumpWidget(
      montar(
        tablero(),
        notesMode: false,
        onToggleNotes: () => toggled++,
      ),
    );

    await tester.tap(find.text('Marcar'));
    await tester.pump();

    expect(toggled, 1);
  });

  testWidgets('el contador de minas muestra las restantes', (tester) async {
    final b = tablero();
    await tester.pumpWidget(montar(b));
    expect(find.text('${b.remainingMines}'), findsOneWidget);
  });

  testWidgets('no muestra botón de deshacer en Buscaminas', (tester) async {
    final b = tablero();
    await tester.pumpWidget(montar(b));
    final undoBtn = find.byTooltip('Deshacer');
    expect(undoBtn, findsNothing);
  });

  testWidgets('la tecla de color sigue viva con la partida terminada', (
    tester,
  ) async {
    var alternado = 0;
    await tester.pumpWidget(
      montar(
        tablero(),
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
