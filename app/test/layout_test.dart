import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';

import 'helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas de desbordes. El tablero es cuadrado y el numpad no se comprime, así
/// que la pantalla estrecha o baja es donde puede romperse; con un simulador de
/// iPad no se ve. Aquí se monta a varios tamaños reales y se comprueba que
/// Flutter no reporte ni un desbordamiento.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final puzzle = generate(seed: 7, target: Difficulty.hard)!;

  setUp(() {
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      '2026-08-17': {
        'givens': puzzle.givens,
        'solution': puzzle.solution,
        'difficulty': 'hard',
        'clues': puzzle.clueCount,
      },
    });
    SharedPreferences.setMockInitialValues({});
  });

  /// Tamaños en puntos lógicos de aparatos reales, del más apretado al mayor.
  const sizes = <String, Size>{
    'iPhone SE (el más apretado)': Size(320, 568),
    'iPhone 8': Size(375, 667),
    'iPhone 15 Pro': Size(393, 852),
    'iPhone 15 Pro Max': Size(430, 932),
    'iPad mini': Size(744, 1133),
    'iPad Pro 12.9"': Size(1024, 1366),
  };

  for (final entry in sizes.entries) {
    testWidgets('sin desbordes en ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = entry.value;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final c = DailyController(
        await SharedPreferences.getInstance(),
        clock: () => DateTime(2026, 8, 17, 10),
      );
      await c.load();

      // Con la barra inferior DEBAJO, no la pantalla suelta.
      //
      // La barra le quita 68 puntos de alto al tablero, y este fichero existe
      // justo para eso: la primera versión probaba `GameScreen` a pelo, así
      // que cuando se añadió la barra las seis medidas siguieron en verde sin
      // haber medido nunca el caso real. Una prueba de desbordes que no monta
      // lo que se monta en la app no prueba nada.
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: GameScreen(
              controller: c,
              progress: ProgressController(
                await SharedPreferences.getInstance(),
              ),
              theme: ThemeController(await SharedPreferences.getInstance()),
            ),
            bottomNavigationBar: SendaBottomNav(
              current: SendaTab.play,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull, reason: '${entry.key} desborda');
      // Y el tablero tiene que estar en pantalla de verdad, no simplemente
      // recortado a cero.
      expect(find.byType(GameScreen), findsOneWidget);
    });
  }

  testWidgets('con el texto del sistema al máximo tampoco desborda', (
    tester,
  ) async {
    // El tablero ignora el escalado a propósito (sus dígitos se dimensionan
    // desde el lado de la casilla), pero cabecera y numpad SÍ lo siguen, y ahí
    // es donde un ajuste de accesibilidad extremo rompería la pantalla.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = DailyController(
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 8, 17, 10),
    );
    await c.load();

    await tester.pumpWidget(
      testApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: GameScreen(
            controller: c,
            progress: ProgressController(await SharedPreferences.getInstance()),
            theme: ThemeController(await SharedPreferences.getInstance()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
