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
    bool Function(int)? onDigit,
    VoidCallback? onUndo,
    VoidCallback? onErase,
    VoidCallback? onToggleNotes,
    VoidCallback? onToggleBoardColour,
  }) => testApp(
    Scaffold(
      body: Numpad(
        board: b,
        notesMode: notesMode,
        enabled: enabled,
        onDigit: onDigit ?? (_) => false,
        onErase: onErase ?? () {},
        onToggleNotes: onToggleNotes ?? () {},
        onUndo: onUndo ?? () {},
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
    await tester.pumpWidget(
      montar(
        tableroCon(),
        onDigit: (_) {
          pulsado++;
          return false;
        },
      ),
    );

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
    expect(vibraciones, [
      'HapticFeedbackType.lightImpact',
    ], reason: 'una tecla del numpad da su golpe y NADA más');
  });

  testWidgets('una tecla apagada no vibra ni llama a nadie', (tester) async {
    // Un tic significa "ha entrado". Una tecla que no hace nada tiene que
    // quedarse muda, o el tic dejaría de significar eso.
    var pulsado = 0;
    await tester.pumpWidget(
      montar(
        tableroCon(lleno: 4),
        onDigit: (_) {
          pulsado++;
          return false;
        },
      ),
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

  group('la cifra entra al tocar, y los huecos son de las teclas', () {
    // André, 5-10-2026 (el mismo arreglo que CINCO en su teclado): la cifra
    // entraba al LEVANTAR el dedo y solo si no se había deslizado, y los
    // huecos entre teclas no eran de nadie. Con prisa se perdían cifras: el
    // dedo vibraba y no entraba nada.

    testWidgets('entra al bajar el dedo, y deslizarlo después no la quita', (
      tester,
    ) async {
      final pulsadas = <int>[];
      await tester.pumpWidget(
        montar(
          tableroCon(),
          onDigit: (d) {
            pulsadas.add(d);
            return false;
          },
        ),
      );
      final dedo = await tester.startGesture(tester.getCenter(find.text('5')));
      await tester.pump();
      expect(pulsadas, [5], reason: 'con el dedo todavía abajo');
      expect(golpes(), 1);
      // El dedo se desliza, como con prisa: antes esto cancelaba el toque.
      await dedo.moveBy(const Offset(30, 25));
      await dedo.up();
      await tester.pump();
      expect(pulsadas, [5], reason: 'ni se pierde ni se repite');
    });

    testWidgets('el hueco entre dos cifras es de una de las dos', (
      tester,
    ) async {
      final pulsadas = <int>[];
      await tester.pumpWidget(
        montar(
          tableroCon(),
          onDigit: (d) {
            pulsadas.add(d);
            return false;
          },
        ),
      );
      // Justo en medio del hueco entre el 4 y el 5: el borde derecho del
      // fondo del 4 más la mitad del hueco.
      final cuatro = tester.getRect(_fondoDe(find.text('4')));
      final cinco = tester.getRect(_fondoDe(find.text('5')));
      expect(cinco.left - cuatro.right, greaterThan(1), reason: 'hay hueco');
      await tester.tapAt(
        Offset((cuatro.right + cinco.left) / 2, cuatro.center.dy),
      );
      await tester.pump();
      expect(pulsadas, hasLength(1));
      expect(pulsadas.single, anyOf(4, 5));
    });

    testWidgets('el hueco entre las dos filas, y entre dos acciones, también', (
      tester,
    ) async {
      // Con borrar y notas, que están vivas siempre: deshacer está apagada
      // con el tablero sin tocar, y su mitad de hueco, como ella, no hace
      // nada.
      final pulsadas = <int>[];
      var borrar = 0, notas = 0;
      await tester.pumpWidget(
        montar(
          tableroCon(),
          onDigit: (d) {
            pulsadas.add(d);
            return false;
          },
          onErase: () => borrar++,
          onToggleNotes: () => notas++,
        ),
      );
      final cifra = tester.getRect(_fondoDe(find.text('3')));
      final erase = tester.getRect(
        _fondoDe(find.byIcon(Icons.backspace_outlined)),
      );
      final notes = tester.getRect(_fondoDe(find.byIcon(Icons.edit_outlined)));
      // Entre filas, encima de borrar.
      await tester.tapAt(
        Offset(erase.center.dx, (cifra.bottom + erase.top) / 2),
      );
      await tester.pump();
      expect(pulsadas.length + borrar, 1, reason: 'el hueco entre filas');
      // Entre borrar y notas.
      await tester.tapAt(
        Offset((erase.right + notes.left) / 2, erase.center.dy),
      );
      await tester.pump();
      expect(
        pulsadas.length + borrar + notas,
        2,
        reason: 'el hueco entre acciones',
      );
    });

    testWidgets('una cifra equivocada no da el golpe de la tecla', (
      tester,
    ) async {
      // El fallo trae su propio patrón (lo pide el controlador). Con la cifra
      // entrando al bajar, el golpe y el patrón caerían a la vez.
      await tester.pumpWidget(montar(tableroCon(), onDigit: (_) => true));
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(vibraciones, isEmpty, reason: 'la tecla no añade su golpe');
    });

    testWidgets(
      'con lector de pantalla, la cifra y la acción siguen entrando',
      (tester) async {
        // VoiceOver y TalkBack no bajan dedos: mandan la acción «tocar».
        final semantica = tester.ensureSemantics();
        final pulsadas = <int>[];
        var deshacer = 0;
        await tester.pumpWidget(
          montar(
            tableroCon(),
            onDigit: (d) {
              pulsadas.add(d);
              return false;
            },
            onUndo: () => deshacer++,
          ),
        );
        tester.semantics.tap(find.semantics.byLabel('7'));
        await tester.pump();
        expect(pulsadas, [7]);
        semantica.dispose();
      },
    );

    testWidgets('se ven igual que antes: mismas medidas y mismos huecos', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(montar(tableroCon()));
      final cifras = [
        for (var d = 1; d <= 9; d++) tester.getRect(_fondoDe(find.text('$d'))),
      ];
      expect(cifras.map((r) => r.height).toSet(), {62});
      expect(
        cifras.map((r) => r.width.toStringAsFixed(2)).toSet(),
        hasLength(1),
      );
      expect(cifras[1].left - cifras[0].right, closeTo(4, .01));
      final acciones = [
        for (final i in [
          Icons.undo_rounded,
          Icons.backspace_outlined,
          Icons.edit_outlined,
          Icons.palette_rounded,
        ])
          tester.getRect(_fondoDe(find.byIcon(i))),
      ];
      expect(acciones.map((r) => r.height).toSet(), {40});
      // Las cuatro del mismo ancho a la vista, también las de los extremos.
      expect(
        acciones.map((r) => r.width.toStringAsFixed(2)).toSet(),
        hasLength(1),
      );
      for (var i = 1; i < 4; i++) {
        expect(acciones[i].left - acciones[i - 1].right, closeTo(8, .01));
      }
      expect(acciones.first.top - cifras.first.bottom, closeTo(10, .01));
      expect(acciones.first.left, closeTo(cifras.first.left - 2, .01));
      expect(acciones.last.right, closeTo(cifras.last.right + 2, .01));
    });
  });
}

/// El fondo pintado de una tecla: el `Container` decorado que la contiene.
Finder _fondoDe(Finder dentro) => find
    .ancestor(
      of: dentro,
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    )
    .first;
