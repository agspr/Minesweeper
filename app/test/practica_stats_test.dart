import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las cifras de práctica por nivel (pedido de André, 26-8-2026): jugadas,
/// completadas y mejor tiempo de cada dificultad.
///
/// Los detalles que estas pruebas sujetan, cada uno con su porqué:
/// - Una jugada cuenta al PRIMER TOQUE, no al generarse el tablero: entrar en
///   la pestaña ya genera uno, y contar eso inflaría las jugadas con puzles
///   que nadie miró.
/// - El mejor tiempo solo MEJORA: una partida lenta no puede pisar una rápida.
/// - Sin completar ninguno no hay mejor tiempo: `null`, jamás un cero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  DateTime clock() => now;

  Future<PracticeController> nuevo() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 8, 26, 10);
    final c = PracticeController(prefs, seedSource: () => 7, clock: clock);
    await c.load();
    return c;
  }

  /// Rellena el tablero entero con la solución, tardando [porCasilla] entre
  /// toques. Devuelve cuántas casillas escribió.
  int resolver(PracticeController c, {Duration porCasilla = Duration.zero}) {
    var puestas = 0;
    final b = c.board!;
    for (var cell = 0; cell < 81 && !c.isComplete; cell++) {
      if (b.isGiven(cell) || b.entries[cell] == b.solution[cell]) continue;
      now = now.add(porCasilla);
      c.select(cell);
      c.tapDigit(b.solution[cell]);
      puestas++;
    }
    return puestas;
  }

  test(
    'generar un tablero NO cuenta jugada; el primer toque sí, y una',
    () async {
      final c = await nuevo();
      expect(
        c.statsFor(Difficulty.easy).played,
        0,
        reason: 'entrar en la pestaña genera tablero: eso no es jugar',
      );

      final b = c.board!;
      final cell = List.generate(81, (i) => i).firstWhere((i) => !b.isGiven(i));
      c.select(cell);
      c.tapDigit(b.solution[cell]);
      expect(c.statsFor(Difficulty.easy).played, 1);

      // Más toques del MISMO tablero no suman jugadas.
      resolver(c);
      expect(c.statsFor(Difficulty.easy).played, 1);
    },
  );

  test('completar suma, y el mejor tiempo solo mejora', () async {
    final c = await nuevo();
    resolver(c, porCasilla: const Duration(seconds: 2));
    final s1 = c.statsFor(Difficulty.easy);
    expect(s1.completed, 1);
    expect(s1.bestSeconds, isNotNull);
    final primero = s1.bestSeconds!;

    // Otro puzle, el doble de lento: completadas sube, el mejor NO empeora.
    await c.newPuzzle();
    resolver(c, porCasilla: const Duration(seconds: 4));
    final s2 = c.statsFor(Difficulty.easy);
    expect(s2.completed, 2);
    expect(s2.played, 2);
    expect(
      s2.bestSeconds,
      primero,
      reason: 'una partida lenta pisó el mejor tiempo',
    );

    // Y uno más rápido sí lo mejora.
    await c.newPuzzle();
    resolver(c, porCasilla: const Duration(seconds: 1));
    expect(c.statsFor(Difficulty.easy).bestSeconds, lessThan(primero));
  });

  test('sin completar ninguno, el mejor tiempo es null — nunca cero', () async {
    final c = await nuevo();
    final b = c.board!;
    final cell = List.generate(81, (i) => i).firstWhere((i) => !b.isGiven(i));
    c.select(cell);
    c.tapDigit(b.solution[cell]);
    final s = c.statsFor(Difficulty.easy);
    expect(s.played, 1);
    expect(s.completed, 0);
    expect(s.bestSeconds, isNull);
  });

  test('cada dificultad lleva su cuenta aparte', () async {
    final c = await nuevo();
    resolver(c);
    expect(c.statsFor(Difficulty.easy).completed, 1);
    expect(c.statsFor(Difficulty.medium).played, 0);
    expect(c.statsFor(Difficulty.hard).played, 0);
  });
}
