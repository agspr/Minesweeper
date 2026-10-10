import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/services/partida_en_la_nube.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/progress_sync.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:nona/widgets/escenas_del_final.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **La diaria a medias viaja con la cuenta** (André, 5-10-2026: «cuando cambio
/// de aparato se pierde el sudoku del día»).
///
/// Solo subía el día TERMINADO; el tablero a medias vivía en el teléfono.
/// Cambiar de teléfono, o salir de la cuenta y volver, dejaba la diaria en
/// blanco: se podía empezar de cero cuantas veces se quisiera, sin los fallos.
/// Lo que se vigila aquí es que suba, que baje, cuándo, y que al adoptar nunca
/// se vaya hacia atrás ni se borren fallos.
const hoy = '2026-08-18';

Map<String, dynamic> partida({
  String dia = hoy,
  int jugadas = 0,
  int fallos = 0,
  bool completa = false,
  String entries = '',
}) => {
  'day': dia,
  'entries': entries,
  'notes': '',
  'mistakes': fallos,
  'seconds': 60,
  'jugadas': jugadas,
  'completa': completa,
};

/// La nube, fingida: un documento por cuenta.
///
/// **Lee como Firestore**: con el `updatedAt` que pone el servidor, un
/// `Timestamp`. Sin él, esta nube era más amable que la de verdad, y todas
/// estas pruebas pasaban mientras ningún teléfono adoptaba nada (10-10-2026).
class _Nube implements AlmacenDePartida {
  final docs = <String, Map<String, dynamic>>{};
  int escrituras = 0;
  final pasos = <String>[];

  @override
  Future<Map<String, dynamic>?> leer(String uid) async {
    pasos.add('leer:$uid');
    final d = docs[uid];
    return d == null ? null : {...d, 'updatedAt': Timestamp.now()};
  }

  @override
  Future<void> escribir(String uid, Map<String, dynamic> p) async {
    pasos.add('escribir:$uid');
    escrituras++;
    docs[uid] = Map.of(p);
  }
}

/// Una nube que falla siempre: sin red, sin permiso, o un dato que no cabe.
class _NubeRota implements AlmacenDePartida {
  @override
  Future<Map<String, dynamic>?> leer(String uid) async => throw 'no leo';

  @override
  Future<void> escribir(String uid, Map<String, dynamic> p) async =>
      throw 'no subo';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final p = generate(seed: 5, target: Difficulty.easy)!;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      hoy: {
        'givens': p.givens,
        'solution': p.solution,
        'difficulty': 'easy',
        'clues': p.clueCount,
      },
    });
  });

  Future<DailyController> diaria() async {
    final c = DailyController(
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 8, 18, 10),
    );
    await c.load();
    return c;
  }

  /// Las casillas vacías del puzle, en orden.
  List<int> vacias(DailyController c) => [
    for (var i = 0; i < cellCount; i++)
      if (!c.board!.isGiven(i)) i,
  ];

  void poner(DailyController c, int casilla, {bool bien = true}) {
    c.select(casilla);
    final s = c.board!.solution[casilla];
    c.tapDigit(bien ? s : (s % 9) + 1);
  }

  group('qué partida se queda', () {
    test('solo la de hoy', () {
      expect(
        partidaQueSeAdopta(
          local: null,
          remota: partida(dia: '2026-08-17', jugadas: 9),
          hoy: hoy,
        ),
        isNull,
      );
    });

    test('sin partida aquí, o con la de ayer, la de la nube', () {
      expect(
        partidaQueSeAdopta(local: null, remota: partida(jugadas: 3), hoy: hoy),
        isNotNull,
      );
      expect(
        partidaQueSeAdopta(
          local: partida(dia: '2026-08-17', jugadas: 40),
          remota: partida(jugadas: 3),
          hoy: hoy,
        ),
        isNotNull,
      );
    });

    test('la que lleve más jugadas; con las mismas o menos, la de aquí', () {
      expect(
        partidaQueSeAdopta(
          local: partida(jugadas: 5),
          remota: partida(jugadas: 6),
          hoy: hoy,
        ),
        isNotNull,
      );
      for (final n in [5, 4]) {
        expect(
          partidaQueSeAdopta(
            local: partida(jugadas: 5),
            remota: partida(jugadas: n),
            hoy: hoy,
          ),
          isNull,
        );
      }
    });

    test('terminada aquí no se cambia; terminada allí se adopta siempre', () {
      expect(
        partidaQueSeAdopta(
          local: partida(jugadas: 50, completa: true),
          remota: partida(jugadas: 60),
          hoy: hoy,
        ),
        isNull,
      );
      expect(
        partidaQueSeAdopta(
          local: partida(jugadas: 50),
          remota: partida(jugadas: 30, completa: true),
          hoy: hoy,
        ),
        isNotNull,
      );
    });

    test('los fallos nunca bajan al cambiar de teléfono', () {
      final elegida = partidaQueSeAdopta(
        local: partida(jugadas: 5, fallos: 4),
        remota: partida(jugadas: 9, fallos: 2),
        hoy: hoy,
      );
      expect(elegida!['mistakes'], 4);
      expect(elegida['jugadas'], 9);
    });
  });

  group('lo que llega de Firestore', () {
    test('se adopta con el updatedAt del servidor dentro', () async {
      // El documento de verdad lleva un `Timestamp`, que `jsonEncode` no sabe
      // escribir. Copiado tal cual, `adoptar` lanzaba con cada partida real y
      // el sincronizador se lo tragaba: ningún teléfono adoptaba nunca.
      final c = await diaria();
      final remota = {
        ...partida(jugadas: 5, entries: '.' * cellCount),
        'updatedAt': Timestamp.now(),
      };
      expect(await c.adoptar(remota), isTrue);
      expect(c.estadoGuardado!['jugadas'], 5);
    });

    test('viaja todo lo que la diaria guarda, y nada más', () async {
      // Una clave nueva en `estadoGuardado` que no esté en la lista subiría,
      // pero el otro teléfono no la adoptaría.
      final c = await diaria();
      expect(clavesDeLaPartida, c.estadoGuardado!.keys.toSet());
    });
  });

  group('la diaria', () {
    test('cuenta las jugadas, y el contador se guarda', () async {
      final c = await diaria();
      final hueco = vacias(c);
      poner(c, hueco[0]);
      c.erase();
      c.undo();
      poner(c, hueco[1]);
      expect(c.estadoGuardado!['jugadas'], 4);
      final otra = await diaria();
      expect(otra.estadoGuardado!['jugadas'], 4, reason: 'tras recargar');
    });

    test(
      'adoptar pone el tablero de la nube y cuenta como carga nueva',
      () async {
        final c = await diaria();
        final hueco = vacias(c);
        final antes = c.generacion;
        // La partida de «otro teléfono»: tres casillas bien puestas.
        final otro = await diaria();
        for (final i in hueco.take(3)) {
          poner(otro, i);
        }
        final remota = otro.estadoGuardado!;
        SharedPreferences.setMockInitialValues({});
        var ahora = DateTime(2026, 8, 18, 10);
        final aqui = DailyController(
          await SharedPreferences.getInstance(),
          clock: () => ahora,
        );
        await aqui.load();
        aqui.startTimer();
        expect(await aqui.adoptar(remota), isTrue);
        // El reloj sigue corriendo con el tablero nuevo, desde lo que traía.
        ahora = ahora.add(const Duration(seconds: 10));
        expect(aqui.elapsed.inSeconds, (remota['seconds'] as int) + 10);
        for (final i in hueco.take(3)) {
          expect(aqui.board!.entries[i], aqui.board!.solution[i]);
        }
        expect(aqui.generacion, greaterThan(antes));
        expect(aqui.estadoGuardado!['jugadas'], 3);
      },
    );
  });

  group('el sincronizador', () {
    Future<(DailyController, _Nube, PartidaEnLaNube)> montar(
      WidgetTester tester, {
      String? uid = 'ana',
    }) async {
      late DailyController c;
      await tester.runAsync(() async => c = await diaria());
      final nube = _Nube();
      final sync = PartidaEnLaNube(daily: c, uidOf: () => uid, almacen: nube)
        ..start();
      addTearDown(sync.dispose);
      return (c, nube, sync);
    }

    testWidgets('sube un momento después de jugar, juntando las jugadas', (
      tester,
    ) async {
      final (c, nube, _) = await montar(tester);
      final hueco = vacias(c);
      poner(c, hueco[0]);
      poner(c, hueco[1]);
      await tester.pump(const Duration(milliseconds: 500));
      expect(nube.escrituras, 0, reason: 'todavía no');
      await tester.pump(const Duration(seconds: 2));
      expect(nube.escrituras, 1, reason: 'una, por las dos jugadas');
      expect(nube.docs['ana']!['jugadas'], 2);
      expect(nube.docs['ana']!['day'], hoy);
    });

    testWidgets('abrir la diaria y salir sin jugar no sube nada', (
      tester,
    ) async {
      // Ese tablero en blanco pisaba la partida del otro teléfono.
      final (c, nube, sync) = await montar(tester);
      c.startTimer();
      c.pauseTimer();
      await tester.pump(const Duration(seconds: 3));
      sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      expect(nube.escrituras, 0);
      // Y en cuanto hay una jugada, sí.
      poner(c, vacias(c).first);
      await tester.pump(const Duration(seconds: 2));
      expect(nube.escrituras, 1);
    });

    testWidgets('un fallo al subir o al traer se informa, no se traga', (
      tester,
    ) async {
      // Tragados sin rastro, adoptar falló con cada partida real durante
      // cinco días y nada lo dijo.
      late DailyController c;
      await tester.runAsync(() async => c = await diaria());
      final informados = <Object>[];
      final sync = PartidaEnLaNube(
        daily: c,
        uidOf: () => 'ana',
        almacen: _NubeRota(),
        informar: (e, _) => informados.add(e),
      )..start();
      addTearDown(sync.dispose);
      poner(c, vacias(c).first);
      await tester.pump(const Duration(seconds: 2));
      expect(informados, ['no subo']);
      await sync.traer('ana');
      expect(informados, ['no subo', 'no leo']);
    });

    testWidgets('terminada, sube en el acto', (tester) async {
      final (c, nube, _) = await montar(tester);
      for (final i in vacias(c)) {
        poner(c, i);
      }
      await tester.pump();
      expect(nube.docs['ana']!['completa'], isTrue);
    });

    testWidgets('sin sesión no sube nada', (tester) async {
      final (c, nube, _) = await montar(tester, uid: null);
      poner(c, vacias(c).first);
      await tester.pump(const Duration(seconds: 3));
      expect(nube.escrituras, 0);
    });

    testWidgets('irse al fondo sube lo pendiente', (tester) async {
      final (c, nube, _) = await montar(tester);
      poner(c, vacias(c).first);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(nube.escrituras, 1, reason: 'sin esperar al temporizador');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('volver a primer plano trae lo jugado en el otro teléfono', (
      tester,
    ) async {
      final (c, nube, _) = await montar(tester);
      final hueco = vacias(c);
      nube.docs['ana'] = {
        ...partida(jugadas: 7),
        'entries': _entradasCon(c, hueco.take(2)),
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(c.board!.entries[hueco[0]], c.board!.solution[hueco[0]]);
      expect(c.estadoGuardado!['jugadas'], 7);
    });

    testWidgets('al traer, lo de aquí que no había subido, sube antes', (
      tester,
    ) async {
      final (c, nube, sync) = await montar(tester);
      poner(c, vacias(c).first);
      await tester.runAsync(() => sync.traer('ana'));
      expect(nube.pasos, ['escribir:ana', 'leer:ana']);
    });
  });

  test('main la arranca con Firebase y se la pasa al sincronizador', () {
    // `main` no se puede montar sin Firebase: se mira el código, sin
    // comentarios. Sin esto, la clase existe, sus pruebas pasan, y en la app
    // no sube ni baja nada.
    final src = File('lib/main.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(src, contains('PartidaEnLaNube('));
    expect(src, contains('almacen: const AlmacenDePartidaFirestore()'));
    expect(src, contains(')..start();'));
    expect(src, contains('alEstrenarSesion: partida.traer'));
  });

  test('al estrenar sesión, se trae DESPUÉS de reclamar el aparato', () async {
    // Traída antes, el reclamo la borraría; sin reclamar, la cuenta nueva se
    // compararía con el tablero de la anterior.
    final prefs = await SharedPreferences.getInstance();
    final pasos = <String>[];
    final sesion = _Sesion();
    ProgressSync(
      prefs: prefs,
      progress: ProgressController(prefs),
      auth: sesion,
      uidOf: () => sesion.uid,
      store: _SinResumen(),
      session: SessionSync(
        prefs,
        ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
      ),
      onDeviceClaimed: () => pasos.add('reclamado'),
      alEstrenarSesion: (uid) async => pasos.add('traer:$uid'),
    ).start();
    sesion.entrar('ana');
    await pumpEventQueue();
    expect(pasos, ['reclamado', 'traer:ana']);
  });

  testWidgets('una diaria que llega RESUELTA de otro teléfono se ve como '
      'repetición: ni celebración ni anuncio', (tester) async {
    late DailyController c;
    late SharedPreferences prefs;
    await tester.runAsync(() async {
      prefs = await SharedPreferences.getInstance();
      c = await diaria();
    });
    final ads = _Anuncios(prefs);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: GameScreen(
            controller: c,
            progress: ProgressController(prefs),
            theme: ThemeController(prefs),
            friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
            purchases: PurchaseService(prefs, nonaConfig.iap),
            ads: ads,
            onExit: () {},
            onPractice: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    // Abierta y a medias aquí; en el otro teléfono, resuelta.
    final resuelta = {
      ...partida(jugadas: 60, completa: true),
      'entries': _entradasCon(c, vacias(c)),
    };
    await tester.runAsync(() => c.adoptar(resuelta));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(EscenasDelFinal), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget, reason: 'repetición');
    expect(
      ads.llamadas,
      isEmpty,
      reason: 'se resolvió allí: el anuncio no es de aquí',
    );
  });
}

/// Las entradas del tablero de [c] con las casillas [casillas] bien puestas,
/// como las guardaría el otro teléfono.
String _entradasCon(DailyController c, Iterable<int> casillas) {
  final e = List<int>.of(c.board!.entries);
  for (final i in casillas) {
    e[i] = c.board!.solution[i];
  }
  return encodeGrid(e);
}

class _Sesion extends ChangeNotifier {
  String? uid;
  void entrar(String u) {
    uid = u;
    notifyListeners();
  }
}

class _SinResumen implements ProgressStore {
  @override
  Future<ProgressSummary> readSummary(String uid) async =>
      const ProgressSummary();
  @override
  Future<void> writeSummary(String uid, ProgressSummary s) async {}
  @override
  Future<void> writeDay(String uid, String d, Map<String, dynamic> r) async {}
  @override
  Future<void> deleteAllDays(String uid) async {}
}

class _Anuncios extends AdManager {
  _Anuncios(SharedPreferences prefs)
    : super(ConsentManager(), prefs, nonaConfig.ads);
  final llamadas = <String>[];
  @override
  Future<void> deberElDelDia(String dayKey) async => llamadas.add('debe');
  @override
  Future<bool> maybeShowAfterPuzzle(
    String dayKey, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    llamadas.add('anuncio');
    return false;
  }
}
