import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/widgets/result_overlay.dart';

import 'helpers.dart';

/// **Las tres salidas del resultado se ven y se tocan, en el hueco de verdad.**
///
/// El resultado se pinta dentro del área de juego, que es la pantalla MENOS el
/// banner de anuncios y la franja del gesto. El banner es el adaptativo grande
/// y reserva su alto aunque no haya anuncio. En un iPhone 16 Pro (402×874) eso
/// deja 651 puntos —medido en la captura que mandó la mujer de André el
/// 24-9-2026: 161 puntos vacíos abajo, 62 de la isla arriba—, y la tarjeta no
/// cabía: «Menú principal» se salía por abajo, cortado y sin poder tocarse.
/// Quedarse sin salida al terminar la diaria.
///
/// La prueba de siempre (`result_overlay_test.dart`) monta la tarjeta en
/// 420×1400, donde todo cabe, y por eso no lo vio nunca.
///
/// **Con Figtree de verdad.** La letra de las pruebas pinta cada glifo como un
/// cuadrado de la altura del cuerpo, sin interlineado: la tarjeta sale más
/// baja que en el teléfono y el desborde no aparece.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final figtree = FontLoader('packages/juegos_senda/Figtree');
    for (final peso in [300, 400, 500, 600, 700, 800]) {
      figtree.addFont(
        rootBundle.load('packages/juegos_senda/assets/fonts/Figtree-$peso.ttf'),
      );
    }
    await figtree.load();
  });

  DailyScore puntuar({required bool terminado, int fallos = 0}) => scoreDaily(
    DailyOutcome(
      dayKey: '2026-09-24',
      difficulty: Difficulty.medium,
      completed: terminado,
      mistakes: fallos,
      completionPercent: terminado ? 100 : 60,
      seconds: 774,
    ),
  );

  // El área de juego: ancho de la pantalla, y de alto lo que dejan el banner
  // grande y la franja del gesto (iPhone 16 Pro) o solo la isla (un SE, donde
  // el banner se sacrifica por bajo de 700).
  const areas = {
    'iPhone 16 Pro con banner': Size(402, 651),
    'iPhone SE': Size(375, 647),
  };

  for (final MapEntry(key: telefono, value: area) in areas.entries) {
    for (final letra in [1.0, 1.35, 3.1]) {
      for (final idioma in const [Locale('es'), Locale('en')]) {
        for (final terminado in [true, false]) {
          final nombre =
              '$telefono, letra ×$letra, ${idioma.languageCode}, '
              '${terminado ? 'resuelta' : 'a medias'}';

          testWidgets('$nombre: las tres salidas a la vista y se tocan', (
            tester,
          ) async {
            tester.view.physicalSize = area;
            tester.view.devicePixelRatio = 1.0;
            tester.platformDispatcher.textScaleFactorTestValue = letra;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            final tocados = <String>[];
            await tester.pumpWidget(
              testApp(
                ResultOverlay(
                  score: puntuar(terminado: terminado),
                  elapsed: const Duration(minutes: 12, seconds: 54),
                  streak: 3,
                  weekDone: const [false, true, true, true, false, false, false],
                  todayIndex: 3,
                  onShare: () => tocados.add('compartir'),
                  onPractice: () => tocados.add('práctica'),
                  onMenu: () => tocados.add('menú'),
                ),
                locale: idioma,
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);

            final botones = find.byType(FilledButton);
            expect(botones, findsNWidgets(3));
            final pantalla = Offset.zero & area;
            for (var i = 0; i < 3; i++) {
              final boton = botones.at(i);
              final caja = tester.getRect(boton);
              // A la vista SIN desplazar nada: quien acaba de terminar no tiene
              // por qué saber que la tarjeta se mueve para encontrar la salida.
              expect(
                pantalla.contains(caja.topLeft) &&
                    pantalla.contains(caja.bottomRight - const Offset(1, 1)),
                isTrue,
                reason: 'el botón $i se sale de la pantalla: $caja',
              );
              // Y su texto entero, no cortado por el botón. Mirar la caja del
              // texto no basta: Flutter la encoge a lo que le deja el padre
              // aunque las letras sigan de largo, así que la caja siempre
              // «cabe». Lo que delata el corte es que el texto, compuesto a su
              // ancho, necesite más alto del que le dieron.
              final texto = find.descendant(
                of: boton,
                matching: find.byType(RichText),
              );
              final parrafo = tester.renderObject<RenderParagraph>(texto);
              expect(
                parrafo.getMaxIntrinsicHeight(parrafo.size.width),
                lessThanOrEqualTo(parrafo.size.height + 0.5),
                reason: 'el texto del botón $i no cabe entero en él',
              );
              final visible = tester.getRect(texto);
              expect(
                caja.contains(visible.topLeft) &&
                    caja.contains(visible.bottomRight - const Offset(1, 1)),
                isTrue,
                reason: 'el texto del botón $i se sale de él: $visible en $caja',
              );
            }

            // Y se tocan: un botón pintado fuera de su padre se ve pero no
            // recibe el toque, que es exactamente lo que le pasaba al menú.
            for (var i = 0; i < 3; i++) {
              await tester.tap(botones.at(i));
            }
            expect(tocados, ['compartir', 'práctica', 'menú']);
          });
        }
      }
    }
  }
}
