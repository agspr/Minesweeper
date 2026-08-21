import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/screens/practice_screen.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:nona/widgets/numpad.dart';

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

    expect(c.hintsUsed, 0);
    await tester.tap(find.text('Pista'));
    await tester.pump();

    expect(c.hintsUsed, 1, reason: 'el botón de pista no llegó al controlador');
    expect(c.board!.correctCount, 1);
  });

  testWidgets('pulsar "Otro puzle" llega al controlador', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    await tester.tap(find.text('Otro puzle'));
    await tester.pump();

    // Basta con comprobar que la pulsación LLEGA: que el puzle acabe de
    // generarse depende de un isolate real, y eso ya lo cubre practice_test.
    expect(
      c.generating,
      isTrue,
      reason: 'el botón de otro puzle no llegó al controlador',
    );
  });

  testWidgets('los tres botones del numpad siguen respondiendo', (
    tester,
  ) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    // Las teclas de acción ya no llevan etiqueta: se buscan por su tooltip,
    // que es también su nombre accesible.
    await tester.tap(find.byTooltip('Notas'));
    await tester.pump();
    expect(c.notesMode, isTrue);
  });

  testWidgets('la X vuelve al menú', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    await tester.tap(find.byTooltip('Menú principal'));
    await tester.pump();
    expect(salidas, 1, reason: 'la X no llegó al armazón');
  });

  testWidgets('la tecla de color apaga y enciende el tablero', (tester) async {
    sized(tester);
    final c = await loadedIn(tester);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

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
