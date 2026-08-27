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

/// La copia del progreso en la nube — y desde el 27-8-2026, su contrato final:
/// **el cliente escribe DÍAS y lee el resumen; el resumen lo escribe SOLO el
/// servidor**, recalculado desde los días crudos más `legacyPoints`.
///
/// Mientras el cliente escribía el resumen, cualquiera con su sesión podía
/// ponerse los puntos que quisiera, y dos escritores del mismo documento
/// significaba que el que ganara podía pisar al otro — pasó en producción
/// (el hallazgo #3, cerrado por fases con el agente de CINCO).
class _StoreEspia implements ProgressStore {
  _StoreEspia({
    this.enLaNube = const ProgressSummary(),
    this.leerFalla = false,
  });

  final ProgressSummary enLaNube;
  final bool leerFalla;

  final List<String> pasos = [];

  /// Si esto deja de estar vacío, el cliente ha vuelto a escribir el resumen.
  final List<ProgressSummary> escrito = [];

  @override
  Future<ProgressSummary> readSummary(String uid) async {
    pasos.add('leer');
    if (leerFalla) throw Exception('permission-denied');
    return enLaNube;
  }

  @override
  Future<void> writeSummary(String uid, ProgressSummary summary) async {
    pasos.add('escribir');
    escrito.add(summary);
  }

  final List<String> dias = [];

  /// Días cuya escritura FALLA, para ejercer el reintento del backfill.
  final Set<String> fallan = {};

  @override
  Future<void> writeDay(String uid, String d, Map<String, dynamic> r) async {
    if (fallan.contains(d)) throw Exception('sin red');
    dias.add('$uid:$d:${r['points']}');
  }

  @override
  Future<void> deleteAllDays(String uid) async {}
}

/// La sesión, fingida. [ProgressSync] solo pide "avísame" y "¿de quién es?",
/// justo para poder montarla sin Firebase.
class _Sesion extends ChangeNotifier {
  String? uid;

  void entrar(String u) {
    uid = u;
    notifyListeners();
  }
}

void main() {
  late SharedPreferences prefs;
  late ProgressController progress;
  late _Sesion sesion;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    progress = ProgressController(prefs);
    sesion = _Sesion();
  });

  ProgressSync sync(_StoreEspia store) => ProgressSync(
    prefs: prefs,
    progress: progress,
    auth: sesion,
    uidOf: () => sesion.uid,
    store: store,
    session: SessionSync(prefs, ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes),
    clock: () => DateTime(2026, 8, 18, 10),
  );

  void jugar(DateTime day) => progress.record(
    scoreDaily(
      DailyOutcome(
        dayKey: dayKeyFor(day),
        difficulty: Difficulty.easy,
        completed: true,
        mistakes: 0,
        completionPercent: 100,
        seconds: 0,
      ),
    ),
    day,
  );

  ProgressSummary conHistoria() => ProgressSummary(
    streak: 12,
    bestStreak: 30,
    totalPoints: 4000,
    weekPoints: 200,
    weekId: weekIdFor(DateTime(2026, 8, 18)),
    monthPoints: 900,
    monthId: monthIdFor(DateTime(2026, 8, 18)),
    lastPlayedDay: '2026-08-17',
  );

  test('el cliente NUNCA escribe el resumen — ni una vez, en ningún flujo', () async {
    // El contrato final del #3. Se ejercen los tres flujos que ANTES escribían
    // —estrenar sesión con historia en la nube, jugar con sesión abierta, y
    // el teléfono de otra cuenta— y ninguno puede producir un writeSummary:
    // el resumen es del servidor, y un cliente que vuelva a escribirlo reabre
    // el fraude Y la pisada mutua de dos escritores.
    final store = _StoreEspia(enLaNube: conHistoria());
    final s = sync(store)..start();
    sesion.entrar('u1');
    await pumpEventQueue();
    jugar(DateTime(2026, 8, 18));
    await pumpEventQueue();
    s.dispose();

    prefs.setString('account.owner', 'otro');
    final store2 = _StoreEspia();
    sync(store2).start();
    sesion.entrar('u2');
    await pumpEventQueue();
    jugar(DateTime(2026, 8, 19));
    await pumpEventQueue();

    expect(store.escrito, isEmpty);
    expect(store2.escrito, isEmpty);
    expect(store.pasos, isNot(contains('escribir')));
    expect(store2.pasos, isNot(contains('escribir')));
  });

  test(
    'un teléfono recién instalado ADOPTA el progreso de la cuenta',
    () async {
      // Prefs vacías, nube con 4000 puntos: la nube manda hacia abajo. (Hacia
      // arriba ya no hay nada que mandar: el resumen lo escribe el servidor.)
      final store = _StoreEspia(enLaNube: conHistoria());
      sync(store).start();
      sesion.entrar('u1');
      await pumpEventQueue();

      expect(progress.totalPoints, 4000);
    },
  );

  test('la nube vieja no pisa lo local que va por delante', () async {
    jugar(DateTime(2026, 8, 18));
    final local = progress.totalPoints;

    final store = _StoreEspia(enLaNube: const ProgressSummary(totalPoints: 1));
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(progress.totalPoints, local);
  });

  test(
    'si la lectura falla, el teléfono sigue siendo la verdad y el día sube',
    () async {
      // Reglas o red caídas. Adoptar es una MEJORA, no un requisito: lo que no
      // puede pasar es que un fallo de lectura pare la subida de los DÍAS, que
      // son la materia prima del recálculo.
      jugar(DateTime(2026, 8, 18));
      final store = _StoreEspia(leerFalla: true);
      sync(store).start();
      sesion.entrar('u1');
      await pumpEventQueue();

      expect(store.pasos, ['leer']);
      expect(store.dias, isNotEmpty);
    },
  );

  test('sin sesión no se toca la nube', () async {
    final store = _StoreEspia();
    sync(store).start();
    jugar(DateTime(2026, 8, 18));
    await pumpEventQueue();

    expect(store.pasos, isEmpty);
    expect(store.dias, isEmpty);
  });

  test('el aparato de otra cuenta se limpia ANTES de reconciliar', () async {
    // Sin esto, el progreso del dueño anterior se le regalaría a quien acaba
    // de entrar. Y limpio significa limpio: ni resumen ni días en nombre de
    // quien no ha jugado aquí.
    jugar(DateTime(2026, 8, 18));
    prefs.setString('account.owner', 'otro');

    final store = _StoreEspia();
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(progress.totalPoints, 0);
    expect(store.escrito, isEmpty);
    expect(store.dias, isEmpty);
    expect(store.pasos, ['leer']);
  });
  group('el crudo del día (mitad cliente del #3)', () {
    test('jugar sube el día, y el servidor recalcula desde él', () async {
      final store = _StoreEspia();
      sync(store).start();
      sesion.entrar('u1');
      await pumpEventQueue();
      expect(store.dias, isEmpty, reason: 'sin registro hoy, nada que subir');

      jugar(DateTime(2026, 8, 18));
      await pumpEventQueue();

      expect(store.dias, hasLength(1));
      expect(store.dias.single, startsWith('u1:2026-08-18:'));
    });

    test(
      'lo idéntico no se reescribe: cada día dispara un recálculo',
      () async {
        // Contrato, cláusula 3: cada escritura de un día relee TODOS los días
        // del juego en el servidor. Reescribir sin cambios es pagar eso por
        // nada — y el oyente del progreso se dispara por cosas que no son el
        // día (adoptar la nube, por ejemplo).
        final store = _StoreEspia();
        sync(store).start();
        sesion.entrar('u1');
        await pumpEventQueue();

        jugar(DateTime(2026, 8, 18));
        await pumpEventQueue();
        // Un aviso más del progreso sin cambio del día:
        progress.notifyListeners();
        await pumpEventQueue();

        expect(
          store.dias,
          hasLength(1),
          reason: 'el mismo día subió dos veces',
        );
      },
    );

    test('al estrenar sesión, el día jugado sin red también sube', () async {
      // Se jugó como invitado o sin cobertura, y luego se entra: el registro
      // local de hoy existe y la nube no lo tiene. Es el mismo motivo por el
      // que el resumen se empuja al reconciliar.
      jugar(DateTime(2026, 8, 18));

      final store = _StoreEspia();
      sync(store).start();
      sesion.entrar('u1');
      await pumpEventQueue();

      expect(store.dias, hasLength(1));
      expect(store.dias.single, startsWith('u1:2026-08-18:'));
    });
  });
  group('el backfill del histórico (la migración del #3)', () {
    test('al entrar, TODO el histórico local sube una vez', () async {
      jugar(DateTime(2026, 8, 16));
      jugar(DateTime(2026, 8, 17));
      jugar(DateTime(2026, 8, 18));

      final store = _StoreEspia();
      sync(store).start();
      sesion.entrar('u1');
      await pumpEventQueue();

      expect(store.dias.where((d) => d.startsWith('u1:')).length, 3);
      expect(prefs.getBool('progress.daysBackfilled'), isTrue);

      // Un ARRANQUE nuevo (sincronizador nuevo, mismas prefs) no vuelve a
      // subir nada: la bandera manda.
      store.dias.clear();
      final s2 = sync(store)..start();
      sesion.entrar('u1');
      await pumpEventQueue();
      expect(store.dias.where((d) => d.contains('2026-08-16')), isEmpty);
      expect(store.dias.where((d) => d.contains('2026-08-17')), isEmpty);
      s2.dispose();
    });

    test('si UN día falla, la bandera no se marca y se reintenta', () async {
      // Marcada a medias sería no reintentar nunca: el fallo silencioso de
      // siempre, en su variante de migración.
      jugar(DateTime(2026, 8, 16));
      jugar(DateTime(2026, 8, 17));

      final store = _StoreEspia()..fallan.add('2026-08-16');
      sync(store).start();
      sesion.entrar('u1');
      await pumpEventQueue();

      expect(prefs.getBool('progress.daysBackfilled'), isNot(isTrue));

      // Vuelve la red: el siguiente ARRANQUE (sincronizador nuevo) completa
      // y marca.
      store.fallan.clear();
      final s2 = sync(store)..start();
      sesion.entrar('u1');
      await pumpEventQueue();
      expect(store.dias.where((d) => d.contains('2026-08-16')), isNotEmpty);
      expect(prefs.getBool('progress.daysBackfilled'), isTrue);
      s2.dispose();
    });
  });
}
