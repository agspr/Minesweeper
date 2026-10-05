import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/progress_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El caso que corrompió la nube de CINCO: jugar en una cuenta, entrar con otra
/// en el mismo teléfono, y volver.
///
/// En CINCO la racha de 15 días apareció como 1 y ese estado vacío se SUBIÓ,
/// pisando en la nube una racha real. La causa: vaciar lo local (correcto, para
/// no heredar progreso ajeno) sin nada que lo reconstruyera, y sin freno a la
/// subida.
///
/// **Nona no lo reproduce, y esta prueba fija por qué.** El sincronizador LEE y
/// ADOPTA la nube ANTES de escribir, así que al volver a su cuenta restaura
/// desde la nube en vez de recalcular desde un teléfono vacío; y el guardia de
/// resumen vacío impide subir ceros si la lectura falla. Dos frenos
/// independientes.
///
/// Lo que Nona SÍ pierde —y esta prueba lo deja dicho, no lo esconde— es el
/// historial por día LOCAL (estadísticas derivadas de los registros y la fila
/// de la semana), porque esos días no se guardan en la nube todavía. La racha y
/// los puntos sobreviven; el detalle diario no. Su arreglo es persistir los
/// días, que es trabajo aplazado.
class _StorePorUid implements ProgressStore {
  final Map<String, ProgressSummary> nube;
  _StorePorUid(this.nube);

  final List<String> escrituras = [];

  @override
  Future<ProgressSummary> readSummary(String uid) async =>
      nube[uid] ?? const ProgressSummary();

  @override
  Future<void> writeSummary(String uid, ProgressSummary s) async {
    escrituras.add('$uid:${s.totalPoints}');
    nube[uid] = s;
  }

  /// Los días subidos, como `uid:día:puntos`.
  final List<String> diasEscritos = [];

  @override
  Future<void> writeDay(String uid, String d, Map<String, dynamic> r) async {
    diasEscritos.add('$uid:$d:${r['points']}');
  }
  @override
  Future<void> deleteAllDays(String uid) async {}
}

class _Sesion extends ChangeNotifier {
  String? uid;
  void entrar(String u) {
    uid = u;
    notifyListeners();
  }
}

void main() {
  // Las pruebas de la diaria tocan el tablero, y el tablero vibra al moverse:
  // sin binding, `HapticFeedback` no encuentra canal de plataforma y revienta
  // antes de medir nada.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('volver a mi cuenta NO pisa mi racha en la nube con ceros', () async {
    // La cuenta REAL 'ana' lleva 15 días y 300 puntos en la nube. La de prueba
    // 'test' está vacía.
    final hoy = DateTime(2026, 8, 24, 10);
    final nube = <String, ProgressSummary>{
      'ana': ProgressSummary(
        streak: 15,
        bestStreak: 15,
        totalPoints: 300,
        weekPoints: 120,
        weekId: weekIdFor(hoy),
        monthPoints: 300,
        monthId: monthIdFor(hoy),
        lastPlayedDay: dayKeyFor(hoy),
      ),
    };
    final store = _StorePorUid(nube);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = ProgressController(prefs);
    final sesion = _Sesion();

    // Ana ya venía jugando en este teléfono: su progreso local y su sello.
    progress.record(
      scoreDaily(
        DailyOutcome(
          dayKey: dayKeyFor(hoy),
          difficulty: Difficulty.hard,
          completed: true,
          mistakes: 0,
          completionPercent: 100,
          seconds: 0,
        ),
      ),
      hoy,
    );
    prefs.setInt('progress.streak', 15);
    prefs.setInt('progress.totalPoints', 300);
    prefs.setString('progress.lastPlayedDay', dayKeyFor(hoy));
    prefs.setString('account.owner', 'ana');

    ProgressSync sync() => ProgressSync(
      prefs: prefs,
      progress: progress,
      auth: sesion,
      uidOf: () => sesion.uid,
      store: store,
      session: SessionSync(
        prefs,
        ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
      ),
      clock: () => hoy,
    )..start();

    final s = sync();

    // 1) Ana entra: sincroniza sin novedad.
    sesion.entrar('ana');
    await pumpEventQueue();

    // 2) Entra la cuenta de PRUEBA. Vacía el teléfono; su nube sigue vacía.
    sesion.entrar('test');
    await pumpEventQueue();
    expect(
      store.nube['test']?.totalPoints ?? 0,
      0,
      reason: 'la cuenta de prueba no debe recibir el progreso de ana',
    );

    // 3) Ana VUELVE. Aquí es donde CINCO se rompía.
    sesion.entrar('ana');
    await pumpEventQueue();

    // La nube de ana sigue intacta: 300, no 0. Desde el 27-8-2026 esto está
    // garantizado DOS veces: el cliente ya no escribe el resumen en absoluto
    // (contrato final del #3), y aunque volviera a hacerlo, el orden
    // lee-adopta-escribe seguiría protegiéndolo.
    expect(
      store.escrituras,
      isEmpty,
      reason: 'el cliente escribió un resumen: el contrato del #3 está roto',
    );
    expect(
      store.nube['ana']!.totalPoints,
      300,
      reason: 'volver a mi cuenta pisó mi racha real con el teléfono vacío',
    );
    expect(store.nube['ana']!.streak, 15);
    // Y lo local quedó restaurado desde la nube.
    expect(progress.totalPoints, 300);
    expect(progress.streakAsOf(hoy), 15);

    s.dispose();
  });

  group('la diaria EN MEMORIA tras un cambio de cuenta', () {
    // Lo que vio André el 12-9-2026. Jugó la diaria en su cuenta, entró en la de
    // pruebas, y la de pruebas la veía como HECHA: `claimDevice` borraba lo
    // guardado, pero el tablero ya cargado seguía siendo el de la otra cuenta.
    // Y no era solo aspecto: abrir esa diaria hacía que `GameScreen` anotara el
    // resultado en el progreso de la cuenta que tuviera la sesión.
    final hoy = DateTime(2026, 8, 24, 10);
    final puzle = generate(seed: 3, target: Difficulty.easy)!;

    setUp(() {
      DailyBank.debugClear();
      DailyBank.debugSeedYear(2026, {
        dayKeyFor(hoy): {
          'givens': puzle.givens,
          'solution': puzle.solution,
          'difficulty': 'easy',
          'clues': puzle.clueCount,
        },
      });
      SharedPreferences.setMockInitialValues({});
    });

    Future<(DailyController, _Sesion, ProgressSync)> montar() async {
      final prefs = await SharedPreferences.getInstance();
      final daily = DailyController(prefs, clock: () => hoy);
      await daily.load();
      final sesion = _Sesion();
      final sync = ProgressSync(
        prefs: prefs,
        progress: ProgressController(prefs),
        auth: sesion,
        uidOf: () => sesion.uid,
        store: _StorePorUid({}),
        session: SessionSync(
          prefs,
          ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
        ),
        // El mismo cableado que main.dart: la prueba de abajo vigila que siga
        // ahí, porque esta no puede verlo.
        onDeviceClaimed: daily.reloadFromPrefs,
        clock: () => hoy,
      )..start();
      return (daily, sesion, sync);
    }

    void resolver(DailyController c) {
      for (var i = 0; i < cellCount; i++) {
        if (c.board!.isGiven(i)) continue;
        c.select(i);
        c.tapDigit(c.board!.solution[i]);
      }
    }

    test('la cuenta que entra no ve la diaria de la anterior como hecha', () async {
      final (daily, sesion, sync) = await montar();
      sesion.entrar('ana');
      await pumpEventQueue();
      resolver(daily);
      expect(daily.isComplete, isTrue, reason: 'ana terminó la de hoy');

      sesion.entrar('pruebas');
      await pumpEventQueue();

      expect(
        daily.isComplete,
        isFalse,
        reason: 'la cuenta de pruebas ve como hecha la diaria de ana, y abrirla '
            'le anotaría ese resultado',
      );
      expect(daily.dayKey, dayKeyFor(hoy), reason: 'sigue siendo el mismo día');
      expect(daily.board!.correctCount, 0);
      sync.dispose();
    });

    test('la sesión que llega con la partida empezada no la reinicia', () async {
      // El caso de TODOS los días, no el raro: al abrir la app la sesión de
      // Firebase llega un instante después del primer fotograma, y
      // `onDeviceClaimed` salta aunque sea la misma persona de siempre. Si
      // recargara a ciegas, quien ya hubiera tocado el tablero perdería la
      // selección y se le pararía el reloj.
      SessionSync(
        await SharedPreferences.getInstance(),
        ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
      ).claimDevice('ana');
      final (daily, sesion, sync) = await montar();
      final vacias = [
        for (var i = 0; i < cellCount; i++)
          if (!daily.board!.isGiven(i)) i,
      ];
      daily.select(vacias[0]);
      daily.tapDigit(daily.board!.solution[vacias[0]]);
      daily.select(vacias[1]);

      sesion.entrar('ana');
      await pumpEventQueue();

      expect(daily.selected, vacias[1]);
      expect(daily.board!.correctCount, 1);
      sync.dispose();
    });

    test('volver a tu cuenta el mismo día no deja repetir la diaria para pisar tu resultado', () async {
      // Lo que el arreglo hizo alcanzable sin reiniciar la app, y lo midió la
      // revisión: ana termina la de hoy, entra la cuenta de pruebas, vuelve
      // ana. El cambio borra su registro local, así que la diaria sale limpia;
      // si la repite peor, sus puntos se contaban dos veces aquí y la subida
      // pisaba su día en la nube.
      final prefs = await SharedPreferences.getInstance();
      SessionSync(
        prefs,
        ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
      ).claimDevice('pruebas');
      final store = _StorePorUid({
        'ana': ProgressSummary(
          streak: 1,
          bestStreak: 1,
          totalPoints: 50,
          weekPoints: 50,
          weekId: weekIdFor(hoy),
          monthPoints: 50,
          monthId: monthIdFor(hoy),
          lastPlayedDay: dayKeyFor(hoy),
        ),
      });
      final daily = DailyController(prefs, clock: () => hoy);
      await daily.load();
      final progress = ProgressController(prefs);
      final sesion = _Sesion();
      final sync = ProgressSync(
        prefs: prefs,
        progress: progress,
        auth: sesion,
        uidOf: () => sesion.uid,
        store: store,
        session: SessionSync(
          prefs,
          ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
        ),
        onDeviceClaimed: daily.reloadFromPrefs,
        clock: () => hoy,
      )..start();

      sesion.entrar('ana');
      await pumpEventQueue();
      expect(progress.lastCompletedDay, dayKeyFor(hoy),
          reason: 'la nube dice que ana ya la terminó hoy');
      expect(progress.recordFor(dayKeyFor(hoy)), isNull,
          reason: 'y este teléfono no guarda su registro');

      // Ana la repite, esta vez con un fallo, y la pantalla de juego la anota.
      final b = daily.board!;
      final vacia = [
        for (var i = 0; i < cellCount; i++)
          if (!b.isGiven(i)) i,
      ].first;
      daily.select(vacia);
      daily.tapDigit(b.solution[vacia] == 9 ? 1 : b.solution[vacia] + 1);
      resolver(daily);
      progress.record(scoreDaily(daily.outcome!), hoy);
      await pumpEventQueue();

      expect(progress.totalPoints, 50,
          reason: 'la repetición se sumó encima de lo adoptado: contada dos veces');
      expect(
        store.diasEscritos.where((e) => e.startsWith('ana:${dayKeyFor(hoy)}')),
        isEmpty,
        reason: 'la repetición pisó el día de ana en la nube',
      );
      sync.dispose();
    });
  });

  test('main.dart le pasa la recarga de la diaria al sincronizador', () {
    // `reloadFromPrefs` existió desde el primer commit con un comentario que
    // decía que se llamaba tras un cambio de cuenta, y no la llamaba nadie.
    // Definida y documentada, sin cablear: la forma exacta en que este fallo
    // vivió sin que ninguna prueba se enterase, porque todas llamaban a la
    // función directamente. Se comprueba sobre el texto porque main() no se
    // puede montar en una prueba.
    //
    // Sin comentarios de línea NI de bloque, y dentro de un `ProgressSync(...)`
    // que se arranca de verdad bajo `if (firebaseReady)`: la revisión burló la
    // versión anterior metiendo el bloque entero en /* */. Un `if` muerto a
    // propósito la seguiría burlando, pero eso ya no es un descuido, y cazar
    // sabotajes no es trabajo de una prueba de texto.
    final src = File('lib/main.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final arranque =
        RegExp(r'ProgressSync\(([\s\S]*?)\)\s*\.start\(\);').firstMatch(src);
    expect(arranque, isNotNull, reason: 'no hay un ProgressSync(...).start() vivo');
    expect(arranque!.group(1), contains('onDeviceClaimed: daily.reloadFromPrefs'));
    // Dentro del `if (firebaseReady) {` más cercano, y sin haberlo cerrado:
    // el bloque ya no empieza por él —antes va la partida en la nube—, así
    // que se mira que siga DENTRO, no que sea lo primero.
    final antes = src.substring(0, arranque.start);
    final si = antes.lastIndexOf('if (firebaseReady) {');
    expect(si, isNonNegative, reason: 'no hay if (firebaseReady) antes');
    final tramo = antes.substring(si + 'if (firebaseReady) {'.length);
    final abiertas =
        '{'.allMatches(tramo).length - '}'.allMatches(tramo).length;
    expect(
      abiertas,
      greaterThanOrEqualTo(0),
      reason: 'el ProgressSync está fuera del if (firebaseReady)',
    );
    expect(
      RegExp(r'\bif \(').allMatches(tramo),
      isEmpty,
      reason: 'el ProgressSync cuelga de otro if, no de firebaseReady',
    );
  });

}
