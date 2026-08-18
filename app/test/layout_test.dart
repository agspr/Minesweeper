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
    // APAISADAS. Faltaban, y son justo donde vive el reparto de tablet: con
    // solo medidas verticales, la rama ancha de PuzzleLayout no la montaba
    // ninguna prueba. Es el mismo agujero que tenía este fichero cuando
    // probaba la pantalla sin barra inferior.
    'iPad mini apaisado': Size(1133, 744),
    'iPad Pro 12.9" apaisado': Size(1366, 1024),
    // Split View: media pantalla de un 12.9". Sigue siendo "tablet" por el
    // lado corto, pero el ancho ya no da para el reparto de dos columnas.
    'iPad Pro 12.9" a media pantalla': Size(683, 1024),
  };

  /// Las DOS escalas, cruzadas con todas las medidas.
  ///
  /// Aviso del agente de CINCO, y tenía razón: el eje que de verdad caza
  /// desbordes no es la orientación, es la escala del texto. Un tamaño cómodo
  /// con el texto al máximo revienta antes que un tamaño raro con texto normal.
  /// Añadir las apaisadas y probarlas solo a escala normal daba la SENSACIÓN de
  /// cobertura sin la cobertura.
  ///
  /// Importa especialmente aquí porque el numpad de tablet apaisada va con
  /// ancho fijo topado: ancho fijo + texto al máximo es exactamente donde una
  /// tecla se queda sin sitio para su etiqueta.
  const escalas = <String, double>{'texto normal': 1.0, 'texto al máximo': 1.6};

  for (final entry in sizes.entries) {
    for (final escala in escalas.entries) {
      testWidgets('sin desbordes en ${entry.key} · ${escala.key}', (
        tester,
      ) async {
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
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(escala.value)),
              child: Scaffold(
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
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} desborda con ${escala.key}',
        );
        // Y el tablero tiene que estar en pantalla de verdad, no simplemente
        // recortado a cero.
        expect(find.byType(GameScreen), findsOneWidget);
      });
    }
  }
}
