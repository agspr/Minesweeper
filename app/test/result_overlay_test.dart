import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/widgets/result_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// La pantalla de fin de partida, reconciliada con la de CINCO.
///
/// Lo que decidió el dueño: **la racha es la protagonista** y los puntos bajan
/// a una pastilla, pero el DESGLOSE se queda porque nace de la naturaleza del
/// juego. Antes esta pantalla abría con "+90" en grande y mandaba la racha a
/// una pastilla de 12,5 puntos al fondo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DailyScore puntuar({int mistakes = 0, bool completed = true}) => scoreDaily(
    DailyOutcome(
      dayKey: '2026-08-19',
      difficulty: Difficulty.hard,
      completed: completed,
      mistakes: mistakes,
      completionPercent: completed ? 100 : 60,
      seconds: 300,
    ),
  );

  Future<void> montar(
    WidgetTester tester, {
    int streak = 13,
    List<bool>? semana,
    int hoy = 2,
    DailyScore? score,
    VoidCallback? onPractice,
    VoidCallback? onMenu,
  }) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(
        ResultOverlay(
          score: score ?? puntuar(mistakes: 4),
          elapsed: const Duration(minutes: 95, seconds: 52),
          streak: streak,
          weekDone: semana ?? [true, true, true, false, false, false, false],
          todayIndex: hoy,
          onShare: () {},
          onPractice: onPractice ?? () {},
          onMenu: onMenu ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la racha manda: va más arriba y más grande que los puntos', (
    tester,
  ) async {
    await montar(tester);

    final racha = tester.widget<Text>(find.text('13')).style!.fontSize!;
    final puntos = tester.widget<Text>(find.textContaining('+90')).style!;

    expect(
      tester.getTopLeft(find.text('13')).dy,
      lessThan(tester.getTopLeft(find.textContaining('+90')).dy),
      reason: 'la racha tiene que ir por encima de los puntos',
    );
    expect(
      racha,
      greaterThan(puntos.fontSize!),
      reason: 'y más grande: es la protagonista',
    );
    expect(find.text('días de racha'), findsOneWidget);
  });

  testWidgets('el desglose se queda: es de la naturaleza del juego', (
    tester,
  ) async {
    // CINCO no lo tiene y no pasa nada. Aquí sí, porque la penalización por
    // fallos solo educa si se ve de dónde sale.
    await montar(tester);

    expect(find.text('150'), findsOneWidget, reason: 'la base del día');
    expect(find.text('−60'), findsOneWidget, reason: 'lo que restan 4 errores');
    expect(find.text('90'), findsWidgets, reason: 'el total');
  });

  testWidgets('la semana enseña los días jugados, no la racha', (tester) async {
    // Racha de 13 pero hoy es miércoles: TRES marcas, no siete ni trece.
    await montar(tester);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
  });

  testWidgets('los tres botones, y cada uno a su sitio', (tester) async {
    var practica = 0;
    var menu = 0;
    await montar(tester, onPractice: () => practica++, onMenu: () => menu++);

    expect(find.text('Compartir'), findsOneWidget);
    await tester.tap(find.text('Seguir jugando (Práctica)'));
    await tester.tap(find.text('Menú principal'));
    await tester.pump();

    expect(practica, 1);
    expect(menu, 1);
  });

  testWidgets('sin terminar, se dice que la racha pide terminarlo', (
    tester,
  ) async {
    // Un día a medias da puntos pero NO racha. Con la racha ahora arriba y en
    // grande, callarlo haría creer que el crédito parcial la mantiene.
    await montar(tester, score: puntuar(completed: false));
    expect(find.text('La racha pide terminarlo'), findsOneWidget);
  });

  test('la semana de progreso sale de los días, no del contador', () async {
    // El fallo que tiene CINCO publicado, comprobado por su agente: deduce los
    // días jugados de la racha, así que al romperse pierde días que SÍ se
    // jugaron. Aquí la fuente son los registros por día, y esta prueba fija esa
    // diferencia.
    SharedPreferences.setMockInitialValues({});
    final progress = ProgressController(await SharedPreferences.getInstance());

    void jugar(DateTime d) => progress.record(
      scoreDaily(
        DailyOutcome(
          dayKey: dayKeyFor(d),
          difficulty: Difficulty.easy,
          completed: true,
          mistakes: 0,
          completionPercent: 100,
          seconds: 0,
        ),
      ),
      d,
    );

    // Lunes, martes, miércoles... jueves NO... viernes. La racha vale 1.
    for (final d in [17, 18, 19, 21]) {
      jugar(DateTime(2026, 8, d));
    }
    final semana = progress.weekDoneAsOf(DateTime(2026, 8, 21, 10));

    expect(semana, [true, true, true, false, true, false, false]);
    expect(
      progress.streakAsOf(DateTime(2026, 8, 21, 10)),
      1,
      reason: 'la racha se rompió el jueves...',
    );
    expect(
      semana.where((x) => x).length,
      4,
      reason: '...y aun así los cuatro días jugados siguen ahí',
    );
  });
}
