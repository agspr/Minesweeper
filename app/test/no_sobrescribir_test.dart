import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/game/sudoku_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Protección de casillas en Buscaminas:**
/// - Una casilla descubierta no se puede volver a descubrir ni marcar.
/// - Una casilla con bandera está protegida: Cavar no la descubre ni detona.
/// - El toque en Cavar descubre; en Bandera, marca.
/// - El toque prolongado (long press) alterna bandera en cualquier modo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const hoy = '2026-08-18';
  final emptyGivens = '.' * 64;
  final solBuilder = List.filled(64, '1'); // pista 0
  solBuilder[0] = '$kMine'; // mina en 0
  solBuilder[1] = '2'; // pista 1
  solBuilder[8] = '2'; // pista 1
  solBuilder[9] = '2'; // pista 1
  final sol = solBuilder.join();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      hoy: {
        'givens': emptyGivens,
        'solution': sol,
        'difficulty': 'easy',
        'clues': 0,
        'start': 63,
      },
    });
  });

  SudokuBoard tablero() => SudokuBoard.fromStrings(
    givens: emptyGivens,
    solution: sol,
    safeStart: 63,
  );

  group('el tablero de Buscaminas: protección de casillas', () {
    test('una casilla descubierta no se puede marcar con bandera', () {
      final b = tablero();
      b.reveal(63);
      expect(b.isRevealed(63), isTrue);
      b.toggleFlag(63);
      expect(b.isFlagged(63), isFalse);
    });

    test('la bandera protege la casilla: cavar no la detona ni la descubre', () {
      final b = tablero();
      b.toggleFlag(0); // Casilla con mina
      expect(b.isFlagged(0), isTrue);
      final fallo = b.reveal(0);
      expect(fallo, isFalse, reason: 'la bandera debe proteger la casilla');
      expect(b.isRevealed(0), isFalse);
      expect(b.isFlagged(0), isTrue);
      expect(b.mistakes, 0);
    });

    test('quitar la bandera vuelve a permitir descubrir la casilla', () {
      final b = tablero();
      b.toggleFlag(63);
      expect(b.isFlagged(63), isTrue);
      b.toggleFlag(63);
      expect(b.isFlagged(63), isFalse);
      final fallo = b.reveal(63);
      expect(fallo, isFalse);
      expect(b.isRevealed(63), isTrue);
    });

    test('acorde seguro no actúa si faltan banderas', () {
      final b = tablero();
      b.reveal(1); // Casilla con pista 1
      expect(b.canChord(1), isFalse);
      final fallo = b.chord(1);
      expect(fallo, isFalse);
    });

    test('acorde seguro revela vecinas cuando las banderas coinciden', () {
      final b = tablero();
      b.reveal(1); // Pista 1 (su única mina vecina es la 0)
      b.toggleFlag(0); // Coloca bandera en la mina
      expect(b.canChord(1), isTrue);
      final fallo = b.chord(1);
      expect(fallo, isFalse);
      expect(b.isRevealed(2), isTrue);
    });
  });

  group('la diaria en Buscaminas', () {
    Future<DailyController> diaria() async {
      final c = DailyController(
        await SharedPreferences.getInstance(),
        clock: () => DateTime(2026, 8, 18, 10),
      );
      await c.load();
      return c;
    }

    test('tocar en modo Cavar descubre, en modo Bandera marca', () async {
      final c = await diaria();
      expect(c.isDigMode, isTrue);
      c.tapCellOnBoard(63);
      expect(c.board!.isRevealed(63), isTrue);

      c.toggleNotesMode();
      expect(c.isFlagMode, isTrue);
      c.tapCellOnBoard(0);
      expect(c.board!.isFlagged(0), isTrue);
    });

    test('toque prolongado (long press) alterna bandera directamente', () async {
      // Sin salida marcada: abrirla aquí despejaría el tablero entero (todo
      // son ceros), y lo que se prueba es la pulsación larga. La salida tiene
      // sus propias pruebas en salida_obligada_test.dart.
      DailyBank.debugClear();
      DailyBank.debugSeedYear(2026, {
        hoy: {
          'givens': emptyGivens,
          'solution': sol,
          'difficulty': 'easy',
          'clues': 0,
        },
      });
      final c = await diaria();
      expect(c.isDigMode, isTrue);
      c.longPressCellOnBoard(0);
      expect(c.board!.isFlagged(0), isTrue);
      c.longPressCellOnBoard(0);
      expect(c.board!.isFlagged(0), isFalse);
    });
  });

  group('la práctica en Buscaminas', () {
    Future<PracticeController> practica() async {
      final c = PracticeController(await SharedPreferences.getInstance());
      await c.load();
      return c;
    }

    test('tocar en modo Bandera protege la casilla de cavar', () async {
      final c = await practica();
      // Antes de abrir la salida no se marca nada (salida_obligada_test.dart).
      c.tapCellOnBoard(c.board!.safeStart);
      final b = c.board!;
      final cel = List.generate(
        b.boardCellCount,
        (i) => i,
      ).firstWhere((i) => !b.isRevealed(i));
      c.setFlagMode(true);
      c.tapCellOnBoard(cel);
      expect(c.board!.isFlagged(cel), isTrue);

      c.setFlagMode(false);
      c.tapCellOnBoard(cel);
      expect(c.board!.isRevealed(cel), isFalse, reason: 'bandera protege');
    });

    test('la pista revela una casilla segura sin penalización', () async {
      final c = await practica();
      expect(c.hintsUsed, 0);
      c.hint();
      expect(c.hintsUsed, 1);
      expect(c.board!.correctCount, greaterThanOrEqualTo(1));
    });
  });
}
