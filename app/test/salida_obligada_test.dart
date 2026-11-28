import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/game/sudoku_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Se empieza por la salida marcada.** «Sin adivinar» solo es verdad desde
/// ella: el generador verifica cada tablero abriéndola primero. Hasta abrirla,
/// tocar otra casilla no hace nada y avisa; tocarla a ella la abre, sea cual
/// sea el modo. Ver `SudokuBoard.faltaLaSalida`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const hoy = '2026-08-18';
  const salida = 63; // esquina de abajo a la derecha
  final vacio = '.' * 64;

  // Una pared de minas en la columna 3: la salida abre la mitad derecha y la
  // izquierda queda por jugar, así que abrirla no termina la partida.
  final minas = List<bool>.generate(64, (i) => i % 8 == 3);
  final sol = encodeGrid(computeSolutionFromMines(minas, 8, 8));
  const izquierda = 0; // segura, al otro lado de la pared

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      hoy: {
        'givens': vacio,
        'solution': sol,
        'difficulty': 'easy',
        'clues': 0,
        'start': salida,
      },
    });
  });

  group('el tablero', () {
    SudokuBoard tablero({int safeStart = salida}) => SudokuBoard.fromStrings(
      givens: vacio,
      solution: sol,
      safeStart: safeStart,
    );

    test('falta la salida mientras no se ha jugado nada', () {
      final b = tablero();
      expect(b.faltaLaSalida, isTrue);
      b.reveal(salida);
      expect(b.faltaLaSalida, isFalse);
      expect(b.isRevealed(izquierda), isFalse, reason: 'la pared aguanta');
      expect(b.isFinished, isFalse);
    });

    test('sin salida marcada (Clásico) no hay nada que esperar', () {
      expect(tablero(safeStart: -1).faltaLaSalida, isFalse);
    });

    test(
      'una partida empezada en otro sitio (versión anterior) no se bloquea',
      () {
        final b = tablero();
        b.reveal(izquierda);
        expect(b.faltaLaSalida, isFalse);
      },
    );

    test('deshacer la salida vuelve a pedirla', () {
      final b = tablero();
      b.reveal(salida);
      b.undo();
      expect(b.faltaLaSalida, isTrue);
    });
  });

  group('la diaria', () {
    Future<DailyController> diaria() async {
      final c = DailyController(
        await SharedPreferences.getInstance(),
        clock: () => DateTime(2026, 8, 18, 10),
      );
      await c.load();
      return c;
    }

    test('tocar otra casilla antes de la salida no abre nada y avisa', () async {
      final c = await diaria();
      var repintados = 0;
      c.addListener(() => repintados++);

      c.tapCellOnBoard(izquierda);
      expect(c.board!.isRevealed(izquierda), isFalse);
      expect(c.avisosDeSalida.value, 1);
      expect(c.isRunning, isFalse, reason: 'un toque rechazado no es jugada');
      // El aviso se esconde al repintar la partida (AvisoFlotante.ocultarCon):
      // si el toque rechazado repintara, se iría en cuanto sale.
      expect(repintados, 0);

      c.longPressCellOnBoard(izquierda);
      expect(c.board!.isFlagged(izquierda), isFalse);
      expect(c.avisosDeSalida.value, 2);
    });

    test('la salida se abre aunque esté puesto el modo Bandera', () async {
      final c = await diaria();
      c.setFlagMode(true);
      c.tapCellOnBoard(salida);
      expect(c.board!.isRevealed(salida), isTrue);
      expect(c.board!.isFlagged(salida), isFalse);
      expect(c.avisosDeSalida.value, 0);
    });

    test('la pulsación larga sobre la salida también la abre', () async {
      final c = await diaria();
      c.longPressCellOnBoard(salida);
      expect(c.board!.isRevealed(salida), isTrue);
    });

    test('abierta la salida, se juega donde se quiera', () async {
      final c = await diaria();
      c.tapCellOnBoard(salida);
      c.tapCellOnBoard(izquierda);
      expect(c.board!.isRevealed(izquierda), isTrue);
      expect(c.avisosDeSalida.value, 0);
    });

    test('las llamadas directas tampoco se saltan la salida', () async {
      final c = await diaria();
      c.select(izquierda);
      c.revealSelected();
      c.flagSelected();
      expect(c.board!.isRevealed(izquierda), isFalse);
      expect(c.board!.isFlagged(izquierda), isFalse);
    });

    test('reiniciar vuelve a pedir la salida', () async {
      final c = await diaria();
      c.tapCellOnBoard(salida);
      c.restart();
      c.tapCellOnBoard(izquierda);
      expect(c.board!.isRevealed(izquierda), isFalse);
      expect(c.avisosDeSalida.value, 1);
    });
  });

  group('la práctica', () {
    Future<PracticeController> practica() async {
      final c = PracticeController(await SharedPreferences.getInstance());
      await c.load();
      return c;
    }

    // La salida va siempre en el interior, así que la esquina nunca lo es.
    const esquina = 0;

    test('en Senda, lo mismo que la diaria', () async {
      final c = await practica();
      expect(c.board!.faltaLaSalida, isTrue);
      c.tapCellOnBoard(esquina);
      expect(c.board!.isRevealed(esquina), isFalse);
      expect(c.avisosDeSalida.value, 1);

      c.tapCellOnBoard(c.board!.safeStart);
      expect(c.board!.isRevealed(c.board!.safeStart), isTrue);
    });

    test(
      'la primera pista abre la salida, no la primera casilla segura',
      () async {
        final c = await practica();
        final s = c.board!.safeStart;
        c.hint();
        expect(c.board!.isRevealed(s), isTrue);
        expect(c.hintsUsed, 1);
      },
    );

    test(
      'en Clásico no hay salida marcada: el primer toque vale donde sea',
      () async {
        final c = await practica();
        await c.setGameMode(PracticeGameMode.classic);
        expect(c.board!.safeStart, -1);
        c.tapCellOnBoard(esquina);
        expect(c.board!.isRevealed(esquina), isTrue);
        expect(c.avisosDeSalida.value, 0);
      },
    );
  });
}
