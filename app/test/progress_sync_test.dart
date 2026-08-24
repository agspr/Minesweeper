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

/// La copia del progreso en la nube, y sobre todo el ORDEN en que la hace.
///
/// El fallo que vigila esto no aparece nunca en desarrollo: hace falta la app
/// recién instalada Y una cuenta con historia. Escribir antes de leer publica
/// un resumen a cero encima del bueno y le borra la racha y los puntos a quien
/// llevaba meses jugando. No hay error, no hay aviso, y no se recupera.
class _StoreEspia implements ProgressStore {
  _StoreEspia({
    this.enLaNube = const ProgressSummary(),
    this.leerFalla = false,
    this.escribirFalla = false,
  });

  final ProgressSummary enLaNube;
  final bool leerFalla;
  final bool escribirFalla;

  final List<String> pasos = [];
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
    if (escribirFalla) throw Exception('permission-denied');
    escrito.add(summary);
  }

  @override
  Future<void> writeDay(String uid, String d, Map<String, dynamic> r) async {}

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

  test('al estrenar sesión LEE antes de escribir', () async {
    final store = _StoreEspia(enLaNube: conHistoria());
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(store.pasos, ['leer', 'escribir']);
  });

  test('un teléfono recién instalado no borra el progreso de la cuenta', () {
    // La prueba entera de por qué existe el orden: prefs vacías, nube con
    // 4000 puntos. Al revés, se publicaría un cero encima.
    final store = _StoreEspia(enLaNube: conHistoria());
    sync(store).start();
    sesion.entrar('u1');
    return pumpEventQueue().then((_) {
      expect(progress.totalPoints, 4000);
      expect(store.escrito.single.totalPoints, 4000);
      expect(store.escrito.single.weekPoints, 200);
    });
  });

  test('lo local por delante sube, y la nube vieja no lo pisa', () async {
    jugar(DateTime(2026, 8, 18));
    final local = progress.totalPoints;

    final store = _StoreEspia(enLaNube: const ProgressSummary(totalPoints: 1));
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(progress.totalPoints, local);
    expect(store.escrito.last.totalPoints, local);
  });

  test('si la lectura falla, el teléfono sigue siendo la verdad', () async {
    // Reglas sin desplegar o sin cobertura. Adoptar es una MEJORA, no un
    // requisito: lo que no puede pasar es que un fallo de red pare la subida.
    jugar(DateTime(2026, 8, 18));
    final store = _StoreEspia(leerFalla: true);
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(store.pasos, ['leer', 'escribir']);
    expect(store.escrito.single.totalPoints, progress.totalPoints);
  });

  test('cada partida sube sola', () async {
    final store = _StoreEspia();
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();
    final tras = store.escrito.length;

    jugar(DateTime(2026, 8, 18));
    await pumpEventQueue();

    expect(store.escrito.length, tras + 1);
    expect(store.escrito.last.totalPoints, progress.totalPoints);
  });

  test('sin sesión no se escribe nada', () async {
    final store = _StoreEspia();
    sync(store).start();
    jugar(DateTime(2026, 8, 18));
    await pumpEventQueue();

    expect(store.pasos, isEmpty);
  });

  test('adoptar no rebota una escritura a mitad de reconciliación', () async {
    // `adoptCloud` avisa a los oyentes, y el oyente del progreso escribe. Sin
    // el candado, la adopción devolvería a la nube lo que se acaba de leer,
    // antes incluso de terminar de reconciliar.
    final store = _StoreEspia(enLaNube: conHistoria());
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(store.escrito, hasLength(1));
  });

  test('que la escritura falle no rompe nada', () async {
    // Hasta el despliegue de las reglas, TODA escritura es permission-denied.
    // Es una copia de seguridad, no una acción de quien juega: no se le enseña
    // un error por algo que ni pidió ni puede arreglar.
    // Se juega ANTES de entrar: sin progreso no habría escritura que fallar,
    // porque un resumen vacío no se publica.
    jugar(DateTime(2026, 8, 18));

    final store = _StoreEspia(escribirFalla: true);
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();
    jugar(DateTime(2026, 8, 19));
    await pumpEventQueue();

    expect(store.pasos, ['leer', 'escribir', 'escribir']);
  });

  test('el aparato de otra cuenta se limpia ANTES de reconciliar', () async {
    // Sin esto, el progreso del dueño anterior se le regalaría a quien acaba
    // de entrar: local va por delante, así que "local manda" lo subiría a la
    // cuenta nueva.
    jugar(DateTime(2026, 8, 18));
    prefs.setString('account.owner', 'otro');

    final store = _StoreEspia();
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(progress.totalPoints, 0);
    // Y NO se publica un cero en su nombre. Antes se escribía un resumen vacío
    // y eso creaba `users/{uid}/apps/nona` para alguien que no ha jugado aquí
    // — que es lo que el marcador toma por prueba de que sí juega.
    expect(store.escrito, isEmpty);
    expect(store.pasos, ['leer']);
  });

  test('un resumen vacío no se publica', () async {
    // El otro lado del borrado: tras "Borrar Nona de tu cuenta" el teléfono
    // queda limpio, así que el primer aviso del progreso volvería a CREAR el
    // documento que el servidor acaba de borrar. Vacío, pero existiendo.
    final store = _StoreEspia();
    sync(store).start();
    sesion.entrar('u1');
    await pumpEventQueue();

    expect(store.escrito, isEmpty);

    // Y en cuanto hay algo de verdad, se publica.
    jugar(DateTime(2026, 8, 18));
    await pumpEventQueue();

    expect(store.escrito, hasLength(1));
    expect(store.escrito.single.totalPoints, greaterThan(0));
  });
}
