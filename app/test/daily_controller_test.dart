import 'package:flutter_test/flutter_test.dart';
import 'package:nona/nona_config.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // rootBundle necesita el binding: la prueba del "día fuera del banco" llega
  // hasta el cargador de assets de verdad, que es justo lo que se quiere medir.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Dos días con dificultades distintas del mapa semanal (§3): el 2026-08-17 es
  // lunes (fácil) y el 2026-08-18 martes (medio). Se siembran a mano para no
  // depender de los assets en una prueba unitaria.
  final lunes = generate(seed: 1, target: Difficulty.easy)!;
  final martes = generate(seed: 2, target: Difficulty.medium)!;

  void seedBank() {
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      '2026-08-17': {
        'givens': lunes.givens,
        'solution': lunes.solution,
        'difficulty': 'easy',
        'clues': lunes.clueCount,
      },
      '2026-08-18': {
        'givens': martes.givens,
        'solution': martes.solution,
        'difficulty': 'medium',
        'clues': martes.clueCount,
      },
    });
  }

  late DateTime now;
  DateTime clock() => now;

  setUp(() async {
    seedBank();
    now = DateTime(2026, 8, 17, 9, 0);
    SharedPreferences.setMockInitialValues({});
  });

  Future<DailyController> make() async {
    final c = DailyController(
      await SharedPreferences.getInstance(),
      clock: clock,
    );
    await c.load();
    return c;
  }

  test('carga el puzle del día con su dificultad', () async {
    final c = await make();
    expect(c.ready, isTrue);
    expect(c.dayKey, '2026-08-17');
    expect(c.difficulty, Difficulty.easy);
    expect(c.board!.completionPercent, 0);
    expect(c.loadError, isNull);
  });

  test('un día fuera del banco se reporta, no explota', () async {
    now = DateTime(2031, 1, 1);
    final c = DailyController(
      await SharedPreferences.getInstance(),
      clock: clock,
    );
    await c.load();
    expect(c.ready, isFalse);
    expect(c.loadError, isA<DayNotInBankException>());
    expect(c.board, isNull);
  });

  group('entrada', () {
    test('escribe en la casilla seleccionada', () async {
      final c = await make();
      final cell = _firstEmpty(c);
      c.select(cell);
      c.tapDigit(c.board!.solution[cell]);
      expect(c.board!.entries[cell], c.board!.solution[cell]);
      expect(c.board!.mistakes, 0);
    });

    test('sin selección no escribe nada', () async {
      final c = await make();
      c.tapDigit(5);
      expect(c.board!.entries.every((v) => v == 0), isTrue);
    });

    test('en modo anotación anota en vez de escribir', () async {
      final c = await make();
      final cell = _firstEmpty(c);
      c.select(cell);
      c.toggleNotesMode();
      c.tapDigit(4);
      expect(c.board!.hasNote(cell, 4), isTrue);
      expect(c.board!.entries[cell], 0);
      expect(c.board!.mistakes, 0);
    });

    test('borrar y deshacer pasan al tablero', () async {
      final c = await make();
      final cell = _firstEmpty(c);
      c.select(cell);
      c.tapDigit(c.board!.solution[cell]);
      c.erase();
      expect(c.board!.entries[cell], 0);
      c.undo();
      expect(c.board!.entries[cell], c.board!.solution[cell]);
    });

    test('terminada, ya no acepta más entradas', () async {
      final c = await make();
      _solveAll(c);
      expect(c.isComplete, isTrue);
      final cell = _firstNonGiven(c);
      c.select(cell);
      final before = c.board!.entries[cell];
      c.tapDigit(before == 9 ? 1 : before + 1);
      expect(c.board!.entries[cell], before, reason: 'la partida está cerrada');
    });
  });

  group('reloj', () {
    test('acumula solo mientras corre y se para al ir al fondo', () async {
      final c = await make();
      c.startTimer();
      now = now.add(const Duration(seconds: 30));
      expect(c.elapsed.inSeconds, 30);
      c.pauseTimer();
      now = now.add(const Duration(minutes: 10)); // app en segundo plano
      expect(
        c.elapsed.inSeconds,
        30,
        reason: 'parado no debe contar tiempo de calendario',
      );
      c.startTimer();
      now = now.add(const Duration(seconds: 5));
      expect(c.elapsed.inSeconds, 35);
    });

    test('se para al completar el puzle', () async {
      final c = await make();
      c.startTimer();
      now = now.add(const Duration(seconds: 12));
      _solveAll(c);
      now = now.add(const Duration(minutes: 5));
      expect(c.elapsed.inSeconds, 12);
    });
  });

  group('persistencia', () {
    test('recupera entradas, fallos y reloj del mismo día', () async {
      final prefs = await SharedPreferences.getInstance();
      final c1 = DailyController(prefs, clock: clock);
      await c1.load();
      final cell = _firstEmpty(c1);
      c1.select(cell);
      final right = c1.board!.solution[cell];
      c1.tapDigit(right == 9 ? 1 : right + 1); // un fallo
      c1.startTimer();
      now = now.add(const Duration(seconds: 44));
      c1.pauseTimer();

      final c2 = DailyController(prefs, clock: clock);
      await c2.load();
      expect(c2.board!.mistakes, 1);
      expect(c2.board!.entries[cell], isNot(0));
      expect(c2.elapsed.inSeconds, 44);
    });

    test('un guardado de AYER no contamina el tablero de hoy', () async {
      final prefs = await SharedPreferences.getInstance();
      final c1 = DailyController(prefs, clock: clock);
      await c1.load();
      final cell = _firstEmpty(c1);
      c1.select(cell);
      c1.tapDigit(c1.board!.solution[cell]);
      expect(c1.board!.correctCount, 1);

      now = DateTime(2026, 8, 18, 9, 0); // pasa medianoche
      final c2 = DailyController(prefs, clock: clock);
      await c2.load();
      expect(c2.dayKey, '2026-08-18');
      expect(c2.board!.correctCount, 0, reason: 'tablero nuevo, no el de ayer');
      expect(c2.board!.mistakes, 0);
    });
  });

  group('cambio de día', () {
    test('refreshForToday recarga al pasar medianoche', () async {
      final c = await make();
      expect(await c.refreshForToday(), isFalse);
      now = DateTime(2026, 8, 18, 0, 5);
      expect(await c.refreshForToday(), isTrue);
      expect(c.dayKey, '2026-08-18');
      expect(
        c.difficulty,
        Difficulty.medium,
        reason: 'martes es medio en el mapa semanal',
      );
    });

    // `reloadFromPrefs` la llama el sincronizador en CADA estreno de sesión,
    // también cuando entra la misma persona. Las dos pruebas fijan las dos
    // mitades de su guardia: recarga cuando lo guardado ya no es lo que hay en
    // memoria, y no toca nada cuando sí lo es.
    test('reloadFromPrefs con la partida de hoy guardada no toca nada', () async {
      // Al abrir la app la sesión llega un instante DESPUÉS del primer
      // fotograma. Recargar a ciegas ahí le quitaría la casilla seleccionada a
      // quien ya estuviera jugando.
      final c = await make();
      final vacias = [
        for (var i = 0; i < cellCount; i++)
          if (!c.board!.isGiven(i)) i,
      ];
      c.select(vacias[0]);
      c.tapDigit(c.board!.solution[vacias[0]]);
      c.select(vacias[1]);

      await c.reloadFromPrefs();

      expect(
        c.selected,
        vacias[1],
        reason: 'recargó sin necesidad y perdió la selección de quien juega',
      );
      expect(c.board!.correctCount, 1);
    });

    test('reloadFromPrefs tras vaciar la cuenta vuelve a un tablero limpio', () async {
      // Lo que vio André el 12-9-2026: la diaria de una cuenta, terminada,
      // seguía en memoria después de que entrara otra.
      final c = await make();
      _solveAll(c);
      expect(c.isComplete, isTrue);

      // El borrado DE VERDAD —el del paquete al entrar otra cuenta—, no una
      // clave copiada a mano: si mañana la partida se guarda con otro nombre,
      // esta prueba tiene que seguir midiendo lo mismo.
      SessionSync(
        await SharedPreferences.getInstance(),
        ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
      ).wipeOwned();
      await c.reloadFromPrefs();

      expect(
        c.isComplete,
        isFalse,
        reason: 'la partida de la cuenta anterior sigue en memoria como hecha',
      );
      expect(c.board!.correctCount, 0);
    });
  });

  group('resultado para la puntuación', () {
    test('a medias informa avance y fallos, sin completar', () async {
      final c = await make();
      final empties = _empties(c).take(4).toList();
      for (final cell in empties) {
        c.select(cell);
        c.tapDigit(c.board!.solution[cell]);
      }
      final o = c.outcome!;
      expect(o.completed, isFalse);
      expect(o.mistakes, 0);
      expect(o.completionPercent, greaterThan(0));
      expect(o.difficulty, Difficulty.easy);
      expect(o.dayKey, '2026-08-17');
    });

    test('terminada informa completado al 100', () async {
      final c = await make();
      _solveAll(c);
      final o = c.outcome!;
      expect(o.completed, isTrue);
      expect(o.completionPercent, 100);
    });

    test('los fallos sobreviven a corregir la casilla', () async {
      final c = await make();
      final cell = _firstEmpty(c);
      c.select(cell);
      final right = c.board!.solution[cell];
      c.tapDigit(right == 9 ? 1 : right + 1);
      c.erase();
      c.tapDigit(right);
      final o = c.outcome!;
      expect(o.mistakes, 1);
      expect(c.board!.entries[cell], right);
    });
  });
}

int _firstEmpty(DailyController c) => _empties(c).first;
int _firstNonGiven(DailyController c) =>
    List.generate(cellCount, (i) => i).firstWhere((i) => !c.board!.isGiven(i));

Iterable<int> _empties(DailyController c) => [
  for (var i = 0; i < cellCount; i++)
    if (!c.board!.isGiven(i) && c.board!.entries[i] == 0) i,
];

void _solveAll(DailyController c) {
  for (var cell = 0; cell < cellCount; cell++) {
    if (c.board!.isGiven(cell)) continue;
    c.select(cell);
    c.tapDigit(c.board!.solution[cell]);
  }
}
