import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/screens/home_screen.dart';
import 'package:nona/screens/practice_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **Pasada la medianoche, la diaria de ayer seguía saliendo como hecha.**
///
/// Lo vio André el sábado 12-9-2026 y no le dejaba jugar la de hoy. El día solo
/// se releía desde `GameScreen`, y solo al volver de segundo plano mientras
/// estuviera montada. Con el menú delante no lo hacía nadie. Y como el menú
/// enseñaba la diaria como hecha, no invitaba a entrar en la única pantalla que
/// la habría recargado: un callejón sin salida que solo abría cerrar la app.
///
/// Dos caminos, y hacen falta los dos: volver a la app al día siguiente (la
/// vuelta de segundo plano), y quedarse con la app ABIERTA mientras cruza la
/// medianoche, donde no hay vuelta de la que enterarse.
///
/// Estas pruebas usan `testWidgets` también para el controlador suelto, y no
/// por gusto: es lo que controla el reloj falso de los `Timer`. `fakeAsync` no
/// lo exporta `flutter_test` y Nona no lo declara, y meter una dependencia para
/// una prueba cuando el binding ya lo hace sería peor trato.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final viernes = generate(seed: 11, target: Difficulty.easy)!;
  final sabado = generate(seed: 12, target: Difficulty.easy)!;
  final domingo = generate(seed: 13, target: Difficulty.easy)!;

  Map<String, dynamic> dia(p) => {
    'givens': p.givens,
    'solution': p.solution,
    'difficulty': 'easy',
    'clues': p.clueCount,
  };

  late DateTime ahora;
  DateTime reloj() => ahora;

  setUp(() {
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      '2026-09-11': dia(viernes),
      '2026-09-12': dia(sabado),
      '2026-09-13': dia(domingo),
    });
    SharedPreferences.setMockInitialValues({});
  });

  void resolver(DailyController c) {
    for (var i = 0; i < cellCount; i++) {
      if (c.board!.isGiven(i)) continue;
      c.select(i);
      c.tapDigit(c.board!.solution[i]);
    }
  }

  group('la próxima medianoche local', () {
    test('es el principio del día siguiente', () {
      expect(
        nextLocalMidnight(DateTime(2026, 9, 11, 23, 59, 30)),
        DateTime(2026, 9, 12),
      );
      expect(
        nextLocalMidnight(DateTime(2026, 9, 12)),
        DateTime(2026, 9, 13),
        reason: 'justo EN la medianoche, la siguiente es la de mañana: si fuera '
            'la de ahora, el aviso se reprogramaría a cero en bucle',
      );
    });

    test('cruza fin de mes y fin de año', () {
      expect(nextLocalMidnight(DateTime(2026, 8, 31, 12)), DateTime(2026, 9, 1));
      expect(nextLocalMidnight(DateTime(2026, 12, 31, 12)), DateTime(2027, 1, 1));
    });

    test('es el primer minuto del día siguiente, todo el año, con cambio de hora', () {
      // Lo que justifica `DateTime(y, m, d + 1)` en vez de sumar 24 h. Sumar
      // 24 h el día de otoño deja la «medianoche» a las 23:00 del mismo día, y
      // el rearme salta en bucle durante una hora; en primavera llega una hora
      // tarde.
      //
      // Se asierta «primer minuto del día siguiente» y no «a las 00:00» a
      // propósito: hay zonas donde el cambio de hora ocurre A medianoche y ese
      // día las 00:00 no existen; ahí lo correcto son las 01:00.
      //
      // En la zona de André no hay cambio de hora, así que en su máquina esta
      // prueba no puede ponerse roja: muerde con TZ de una zona que lo tenga
      // (comprobado con TZ=America/New_York y la versión de sumar 24 h).
      for (var t = DateTime(2026, 1, 1, 0, 30);
          t.year == 2026;
          t = t.add(const Duration(hours: 1))) {
        final m = nextLocalMidnight(t);
        expect(m.isAfter(t), isTrue, reason: '$t → $m');
        expect(dayKeyFor(m), isNot(dayKeyFor(t)), reason: '$t → $m');
        expect(
          dayKeyFor(m.subtract(const Duration(minutes: 1))),
          dayKeyFor(t),
          reason: '$t → $m no es el primer minuto del día siguiente',
        );
      }
    });
  });

  group('el controlador, con la app delante', () {
    Future<DailyController> cargado() async {
      final c = DailyController(
        await SharedPreferences.getInstance(),
        clock: reloj,
      );
      await c.load();
      return c;
    }

    testWidgets('a medianoche pasa solo al día nuevo', (tester) async {
      ahora = DateTime(2026, 9, 11, 23, 59, 30);
      final c = await cargado();
      c.watchMidnight();

      ahora = DateTime(2026, 9, 12, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();

      expect(c.dayKey, '2026-09-12');
      c.dispose();
    });

    testWidgets('y se vuelve a armar para la noche siguiente', (tester) async {
      // Un aviso que se dispara una vez sirve una noche. Quien deja la app
      // abierta dos días seguidos se volvería a quedar con la de ayer.
      ahora = DateTime(2026, 9, 11, 23, 59, 30);
      final c = await cargado();
      c.watchMidnight();

      ahora = DateTime(2026, 9, 12, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(c.dayKey, '2026-09-12');

      ahora = DateTime(2026, 9, 13, 0, 0, 1);
      await tester.pump(const Duration(hours: 24));
      await tester.pump();
      expect(c.dayKey, '2026-09-13');
      c.dispose();
    });

    testWidgets('dejar de vigilar lo apaga de verdad', (tester) async {
      // Quien desmonta el menú lo suelta. Si no lo cancelara, además de
      // recargar en segundo plano sin nadie mirando, esta prueba acabaría con
      // un temporizador colgando, y el propio binding la pondría en rojo.
      ahora = DateTime(2026, 9, 11, 23, 59, 30);
      final c = await cargado();
      c.watchMidnight();
      c.stopWatchingMidnight();

      ahora = DateTime(2026, 9, 12, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();

      expect(c.dayKey, '2026-09-11');
    });
  });

  group('el menú', () {
    Future<DailyController> montarMenu(
      WidgetTester tester, {
      bool terminarLaDeHoy = false,
      DailyController? diaria,
      NotificationsService? avisos,
    }) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = await SharedPreferences.getInstance();
      final daily = diaria ?? DailyController(prefs, clock: reloj);
      if (diaria == null) await daily.load();
      if (terminarLaDeHoy) resolver(daily);

      await tester.pumpWidget(
        testApp(
          HomeScreen(
            daily: daily,
            practice: PracticeController(prefs),
            locale: LocaleController(prefs),
            theme: ThemeController(prefs),
            progress: ProgressController(prefs),
            auth: AuthController(
              gameId: nonaGameId,
              firebaseReady: false,
              prefs: prefs,
            ),
            friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
            notifications: avisos ??
                NotificationsService(firebaseReady: false, gameId: nonaGameId),
            prefs: prefs,
            leaderboard: null,
            purchases: PurchaseService(prefs, const IapConfig(removeAdsId: 'x')),
            banner: null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      return daily;
    }

    void volverALaApp(WidgetTester tester) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    testWidgets(
      'volver a la app al día siguiente: la de ayer deja de salir hecha',
      (tester) async {
        // El caso exacto de André: terminó la del viernes, el proceso sobrevivió
        // a la noche, y el sábado el menú seguía diciendo «Hecha».
        ahora = DateTime(2026, 9, 11, 21, 0);
        final daily = await montarMenu(tester, terminarLaDeHoy: true);
        expect(find.textContaining('Hecha'), findsOneWidget);

        ahora = DateTime(2026, 9, 12, 9, 30);
        volverALaApp(tester);
        await tester.pump();
        await tester.pump();

        expect(daily.dayKey, '2026-09-12');
        expect(
          find.textContaining('Hecha'),
          findsNothing,
          reason: 'el sábado el menú sigue dando por hecha la diaria del viernes',
        );
        expect(find.textContaining('· hoy'), findsOneWidget);
      },
    );

    testWidgets(
      'a medianoche con el menú delante, la de ayer deja de salir hecha',
      (tester) async {
        // Sin volver de ningún sitio: la app abierta mientras cruza la noche.
        ahora = DateTime(2026, 9, 11, 23, 59, 30);
        final daily = await montarMenu(tester, terminarLaDeHoy: true);
        expect(find.textContaining('Hecha'), findsOneWidget);

        ahora = DateTime(2026, 9, 12, 0, 0, 1);
        await tester.pump(const Duration(seconds: 31));
        await tester.pump();

        expect(daily.dayKey, '2026-09-12');
        expect(find.textContaining('Hecha'), findsNothing);
      },
    );

    testWidgets(
      'si estaba resolviendo la de ayer, al cambiar el día vuelve al menú',
      (tester) async {
        // Si no, el tablero se cambiaría por otro puzle bajo los dedos de quien
        // lo estaba resolviendo.
        ahora = DateTime(2026, 9, 11, 22, 0);
        final daily = await montarMenu(tester);
        await tester.tap(find.text('Sudoku del día'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(GameScreen), findsOneWidget);

        ahora = DateTime(2026, 9, 12, 8, 0);
        volverALaApp(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(daily.dayKey, '2026-09-12');
        expect(
          find.byType(GameScreen),
          findsNothing,
          reason: 'sigue en la pantalla de juego con el puzle cambiado debajo',
        );
      },
    );

    testWidgets(
      'tras cambiar el día, la diaria nueva se juega sin que el menú te saque',
      (tester) async {
        // La prueba que faltaba, y la más importante (la encontró la revisión):
        // nada comprobaba lo contrario de volver al menú. Borrar la línea que
        // recuerda el día nuevo hacía que cada toque en la diaria de hoy te
        // devolviera al menú —«no me deja hacer la de hoy», otra vez— con las
        // 89 pruebas del menú en verde.
        ahora = DateTime(2026, 9, 11, 22, 0);
        final daily = await montarMenu(tester);
        await tester.tap(find.text('Sudoku del día'));
        await tester.pump(const Duration(milliseconds: 300));

        ahora = DateTime(2026, 9, 12, 8, 0);
        volverALaApp(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(GameScreen), findsNothing);

        await tester.tap(find.text('Sudoku del día'));
        await tester.pump(const Duration(milliseconds: 300));
        final vacia = [
          for (var i = 0; i < cellCount; i++)
            if (!daily.board!.isGiven(i)) i,
        ].first;
        daily.select(vacia);
        daily.tapDigit(daily.board!.solution[vacia]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byType(GameScreen),
          findsOneWidget,
          reason: 'jugar la diaria del día nuevo te devuelve al menú',
        );
      },
    );

    testWidgets('con la práctica delante, el cambio de día no la cierra', (
      tester,
    ) async {
      ahora = DateTime(2026, 9, 11, 22, 0);
      final daily = await montarMenu(tester);
      await tester.tap(find.text('Modo práctica'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PracticeScreen), findsOneWidget);

      ahora = DateTime(2026, 9, 12, 8, 0);
      volverALaApp(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(daily.dayKey, '2026-09-12');
      expect(
        find.byType(PracticeScreen),
        findsOneWidget,
        reason: 'el cambio de día sacó a quien estaba en práctica',
      );
    });

    testWidgets(
      'al volver a tu cuenta el mismo día, el menú la da por hecha aunque no haya tablero',
      (tester) async {
        // Cambiar de cuenta borra el tablero guardado, pero la nube dice que
        // esta cuenta ya la terminó hoy. Ofrecerla sin hacer invitaría a
        // repetirla, y la repetición es justo lo que la guardia de `record` no
        // deja anotar.
        ahora = DateTime(2026, 9, 11, 10, 0);
        ProgressController(await SharedPreferences.getInstance()).adoptCloud(
          const ProgressSummary(
            totalPoints: 50,
            streak: 1,
            bestStreak: 1,
            lastPlayedDay: '2026-09-11',
          ),
        );
        final daily = await montarMenu(tester);

        expect(daily.isComplete, isFalse,
            reason: 'no hay tablero de hoy en este teléfono');
        expect(find.textContaining('Hecha'), findsOneWidget);
      },
    );

    testWidgets(
      'tras borrar la cuenta, el menú que se vuelve a montar no enseña su diaria como hecha',
      (tester) async {
        // Borrar la cuenta o quitar Nona vacía lo guardado y cierra sesión, y la
        // puerta vuelve a montar el menú como invitado, sin estreno de sesión
        // que avise. Sin la recarga al montar, el invitado veía como hecha la
        // diaria de la cuenta borrada, y abrirla la anotaba en un progreso que
        // la siguiente cuenta subía a su nube (medido en la revisión).
        ahora = DateTime(2026, 9, 11, 10, 0);
        final prefs = await SharedPreferences.getInstance();
        final daily = DailyController(prefs, clock: reloj);
        await daily.load();
        resolver(daily);
        SessionSync(
          prefs,
          ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
        ).wipeOwned();

        await montarMenu(tester, diaria: daily);
        await tester.pump();

        expect(daily.isComplete, isFalse);
        expect(find.textContaining('Hecha'), findsNothing);
      },
    );

    testWidgets('si el menú se monta cuando el día ya cambió, no enseña la de ayer', (
      tester,
    ) async {
      // El menú no siempre está montado al cruzar la medianoche: la puerta de
      // sesión lo desmonta mientras enseña la entrada o la espera del perfil.
      ahora = DateTime(2026, 9, 11, 21, 0);
      final prefs = await SharedPreferences.getInstance();
      final daily = DailyController(prefs, clock: reloj);
      await daily.load();
      resolver(daily);

      ahora = DateTime(2026, 9, 12, 9, 0);
      await montarMenu(tester, diaria: daily);
      await tester.pump();

      expect(daily.dayKey, '2026-09-12');
      expect(find.textContaining('Hecha'), findsNothing);
    });

    testWidgets(
      'a medianoche con la partida de ayer delante no te la quita; al salir, el menú ya es de hoy',
      (tester) async {
        // Lo midió la revisión: con el aviso de medianoche armado también
        // durante la partida, quien estaba a medias con la de ayer a las 23:59
        // la perdía y ya no podía terminarla, ni salvar la racha. Antes del
        // arreglo, con la app delante, sí podía. El aviso solo vigila con el
        // menú a la vista: la partida se respeta, y el día se relee al volver
        // al menú.
        ahora = DateTime(2026, 9, 11, 23, 59, 30);
        final daily = await montarMenu(tester);
        await tester.tap(find.text('Sudoku del día'));
        await tester.pump(const Duration(milliseconds: 300));
        final vacia = [
          for (var i = 0; i < cellCount; i++)
            if (!daily.board!.isGiven(i)) i,
        ].first;
        daily.select(vacia);
        daily.tapDigit(daily.board!.solution[vacia]);

        ahora = DateTime(2026, 9, 12, 0, 0, 1);
        await tester.pump(const Duration(seconds: 31));
        await tester.pump();

        expect(
          find.byType(GameScreen),
          findsOneWidget,
          reason: 'a medianoche le quitó la partida a quien estaba jugando',
        );
        expect(daily.dayKey, '2026-09-11');
        expect(
          daily.board!.correctCount,
          1,
          reason: 'lo que llevaba escrito tiene que seguir ahí',
        );

        await tester.tap(find.byTooltip('Menú principal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(GameScreen), findsNothing);
        expect(
          daily.dayKey,
          '2026-09-12',
          reason: 'volver al menú no releyó el día: seguiría dando por buena la de ayer',
        );
      },
    );

    testWidgets(
      'si la diaria estaba abierta debajo de otra pestaña, el cambio de día no te saca de ella',
      (tester) async {
        // Tocar un aviso de amistad lleva a Social sin cerrar la partida. Volver
        // al menú con `_goPlay` al cambiar el día pondría además la pestaña en
        // Jugar: la app te sacaría de donde estabas sin que nadie lo pidiera
        // (lo midió la revisión).
        ahora = DateTime(2026, 9, 11, 22, 0);
        final avisos = NotificationsService(
          firebaseReady: false,
          gameId: nonaGameId,
        );
        await montarMenu(tester, avisos: avisos);
        await tester.tap(find.text('Sudoku del día'));
        await tester.pump(const Duration(milliseconds: 300));
        avisos.abrirAmigosPara.value = '';
        await tester.pump(const Duration(milliseconds: 300));
        SendaTab pestana() =>
            tester.widget<SendaBottomNav>(find.byType(SendaBottomNav)).current;
        expect(pestana(), SendaTab.social);

        ahora = DateTime(2026, 9, 12, 8, 0);
        volverALaApp(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          pestana(),
          SendaTab.social,
          reason: 'el cambio de día te sacó de Social a Jugar',
        );
      },
    );
  });
}
