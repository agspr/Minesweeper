import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_controller.dart';
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

  @override
  Future<void> writeDay(String uid, String d, Map<String, dynamic> r) async {}
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

    // La nube de ana sigue intacta: 300, no 0.
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
}
