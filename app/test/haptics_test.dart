import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un fallo vibra; lo demás, no.
///
/// Se mide en el canal de plataforma, que es donde acaba `HapticFeedback`: así
/// la prueba ve la vibración de verdad que se pidió al sistema y no un
/// contador propio que podría quedarse desconectado de ella. Y se comprueba
/// en los DOS controladores, porque cada uno decide por su cuenta cuándo
/// llamar: que el diario vibre no dice nada del modo práctica.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final vibraciones = <String>[];

  setUp(() {
    vibraciones.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            // Los golpes cortos llegan con su tipo como argumento
            // ('HapticFeedbackType.lightImpact'...); la vibración larga de
            // `vibrate()` llega SIN argumento. Ese vacío es su firma.
            vibraciones.add(call.arguments as String? ?? 'larga');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Solo la vibración LARGA cuenta como fallo; los golpes cortos son de otras
  /// cosas y no deben colarse aquí.
  int fallos() => vibraciones.where((v) => v == 'larga').length;

  int primeraVacia(List<int> givens) => givens.indexWhere((v) => v == 0);
  int otro(int right) => right == 9 ? 1 : right + 1;

  group('modo práctica', () {
    Future<PracticeController> make() async {
      final c = PracticeController(await SharedPreferences.getInstance());
      await c.load();
      return c;
    }

    test('un dígito equivocado vibra largo, una vez', () async {
      final c = await make();
      final cell = primeraVacia(c.board!.givens);
      c.select(cell);
      c.tapDigit(otro(c.board!.solution[cell]));
      expect(fallos(), 1);
    });

    test('un dígito correcto no vibra', () async {
      final c = await make();
      final cell = primeraVacia(c.board!.givens);
      c.select(cell);
      c.tapDigit(c.board!.solution[cell]);
      expect(fallos(), 0);
    });

    test(
      'repetir el mismo fallo no vuelve a vibrar: no vuelve a contar',
      () async {
        // `place` no penaliza dos veces la misma tecla, y la vibración va con
        // la penalización, no con la pulsación.
        final c = await make();
        final cell = primeraVacia(c.board!.givens);
        c.select(cell);
        final wrong = otro(c.board!.solution[cell]);
        c.tapDigit(wrong);
        c.tapDigit(wrong);
        expect(c.board!.mistakes, 1);
        expect(fallos(), 1);
      },
    );

    test(
      'anotar un dígito equivocado no vibra: una nota no es un fallo',
      () async {
        final c = await make();
        final cell = primeraVacia(c.board!.givens);
        c.select(cell);
        c.toggleNotesMode();
        c.tapDigit(otro(c.board!.solution[cell]));
        expect(fallos(), 0);
      },
    );
  });

  group('diario', () {
    final lunes = generate(seed: 1, target: Difficulty.easy)!;

    setUp(() {
      DailyBank.debugClear();
      DailyBank.debugSeedYear(2026, {
        '2026-08-17': {
          'givens': lunes.givens,
          'solution': lunes.solution,
          'difficulty': 'easy',
          'clues': lunes.clueCount,
        },
      });
    });

    Future<DailyController> make() async {
      final c = DailyController(
        await SharedPreferences.getInstance(),
        clock: () => DateTime(2026, 8, 17, 9, 0),
      );
      await c.load();
      return c;
    }

    test('un dígito equivocado vibra largo, una vez', () async {
      final c = await make();
      final cell = primeraVacia(c.board!.givens);
      c.select(cell);
      c.tapDigit(otro(c.board!.solution[cell]));
      expect(c.board!.mistakes, 1);
      expect(fallos(), 1);
    });

    test('un dígito correcto no vibra', () async {
      final c = await make();
      final cell = primeraVacia(c.board!.givens);
      c.select(cell);
      c.tapDigit(c.board!.solution[cell]);
      expect(fallos(), 0);
    });
  });
}
