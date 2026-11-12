import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/home_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **«Hay una versión nueva», y que «Actualizar» lleve a NONA.**
///
/// El aviso llega con el paquete, pero cada juego pone lo que el paquete no
/// puede comprobar: las fichas de SU tienda, el sitio donde se ve y cuándo
/// entra. Todo falla en silencio. Sin tiendas el aviso no sale nunca; con las
/// de CINCO copiadas, sale y manda a instalar el otro juego; si nadie llama a
/// `comprobar()`, no se entera nadie de que hay algo nuevo.
///
/// Y **cuándo entra** importa tanto como que entre: la comprobación va por red
/// y contesta con el menú ya pintado. Un aviso que aparece entonces empuja las
/// tarjetas bajo el dedo de quien va a tocarlas, y el toque acaba abriendo la
/// tienda (lo vio el agente de CINCO, 19-9-2026). Por eso sale si ya se sabía
/// al pintarse, y si se entera tarde, en el siguiente arranque.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('las fichas son las de Minesweeper', () {
    test('Android: la de com.sendallc.minesweeper', () {
      expect(
        nonaConfig.tiendaAndroid.toString(),
        'https://play.google.com/store/apps/details?id=com.sendallc.minesweeper',
      );
    });

    test('iOS: la de Minesweeper, por su id, y sin país fijo', () {
      final ios = nonaConfig.tiendaIos!;
      expect(ios.host, 'apps.apple.com');
      // El id de la ficha de Minesweeper en App Store Connect.
      expect(ios.path, '/app/id6830734481');
      // Un `/us/` o un `/es/` delante fija la tienda de un país.
      expect(
        ios.pathSegments.first,
        'app',
        reason: 'el enlace lleva un país fijo: $ios',
      );
    });
  });

  test('main lee la versión instalada ANTES de pintar, y la pasa al menú', () {
    // Sin ella el paquete no sabe en el primer fotograma si hay aviso, así que
    // no saldría nunca al abrir: solo al volver al menú después de que la red
    // contestara. Se comprueba sobre el texto porque `main` no se puede montar
    // sin Firebase. Sin comentarios, para que nombrarlo no baste.
    final main_ = File('lib/main.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final leer = main_.indexOf('SendaVersionActual.leer()');
    expect(leer, isNonNegative, reason: 'main no lee la versión instalada');
    expect(
      leer,
      lessThan(main_.indexOf('runApp(')),
      reason: 'leída después de runApp llega tarde al primer fotograma',
    );
    expect(
      RegExp('versionActual: versionActual').allMatches(main_).length,
      2,
      reason: 'tiene que llegar a NonaApp y de ahí a HomeScreen',
    );
  });

  group('el aviso en el menú', () {
    final p = generate(seed: 5, target: Difficulty.easy)!;
    const aviso = 'Hay una versión nueva';
    const diaria = 'Reto diario';
    const esta = SendaVersionActual(nombre: '1.0.3', build: 31);

    /// Lo que el paquete guardó de la última vez que miró: la publicada.
    Future<SharedPreferences> prefsCon({int? publicadaVista}) async {
      SharedPreferences.setMockInitialValues({
        'version.publicada': ?publicadaVista,
      });
      return SharedPreferences.getInstance();
    }

    /// La comprobación, con la red que se le diga. Por omisión NO contesta
    /// nunca: así lo que se ve es solo lo que se sabía al pintarse.
    SendaVersiones versiones(
      SharedPreferences prefs, {
      Future<Map<String, dynamic>?> Function()? red,
    }) => SendaVersiones(
      gameId: nonaGameId,
      firebaseReady: true,
      prefs: prefs,
      tiendaAndroid: nonaConfig.tiendaAndroid,
      tiendaIos: nonaConfig.tiendaIos,
      esIos: false,
      fuente: red ?? () => Completer<Map<String, dynamic>?>().future,
      actual: () async => esta,
      actualConocida: esta,
    );

    /// Monta el menú. Con `key` nueva cada vez: montar otra vez es arrancar
    /// otra vez, no reconstruir el que había.
    Future<void> montar(
      WidgetTester tester,
      SharedPreferences prefs, {
      SendaVersiones? v,
      SendaVersionActual? versionActual,
      ProgressController? progreso,
      Size pantalla = const Size(402, 874),
      double letra = 1.0,
    }) async {
      DailyBank.debugClear();
      DailyBank.debugSeedYear(2026, {
        '2026-08-18': {
          'givens': p.givens,
          'solution': p.solution,
          'difficulty': 'easy',
          'clues': p.clueCount,
        },
      });
      tester.view.physicalSize = pantalla;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = letra;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final daily = DailyController(
        prefs,
        clock: () => DateTime(2026, 8, 18, 10),
      );
      await daily.load();

      await tester.pumpWidget(
        testApp(
          HomeScreen(
            key: UniqueKey(),
            daily: daily,
            practice: PracticeController(prefs),
            locale: LocaleController(prefs),
            theme: ThemeController(prefs),
            progress: progreso ?? ProgressController(prefs),
            auth: AuthController(
              gameId: nonaGameId,
              firebaseReady: false,
              prefs: prefs,
            ),
            friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
            notifications: NotificationsService(
              firebaseReady: false,
              gameId: nonaGameId,
            ),
            prefs: prefs,
            leaderboard: null,
            purchases: PurchaseService(
              prefs,
              const IapConfig(removeAdsId: 'x'),
            ),
            banner: null,
            versiones: v,
            versionActual: versionActual,
          ),
        ),
      );
    }

    testWidgets('si ya se sabía, está desde el primer fotograma, encima de la '
        'diaria', (tester) async {
      final prefs = await prefsCon(publicadaVista: 33);
      final v = versiones(prefs);
      addTearDown(v.dispose);
      await montar(tester, prefs, v: v);

      // Sin `pumpAndSettle` y con la red sin contestar: el primer fotograma.
      expect(find.text(aviso), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
      expect(
        tester.getRect(find.text(aviso)).top,
        lessThan(tester.getRect(find.text(diaria)).top),
      );
    });

    testWidgets('si se entera tarde, no entra empujando las tarjetas; sale en '
        'el siguiente arranque', (tester) async {
      final prefs = await prefsCon();
      final red = Completer<Map<String, dynamic>?>();
      final v = versiones(prefs, red: () => red.future);
      addTearDown(v.dispose);
      await montar(tester, prefs, v: v);
      await tester.pump();
      final antes = tester.getRect(find.text(diaria));

      // La red contesta con el menú ya en pantalla.
      red.complete({
        nonaGameId: {'android': 33},
      });
      await tester.pumpAndSettle();
      expect(find.text(aviso), findsNothing);
      expect(
        tester.getRect(find.text(diaria)),
        antes,
        reason: 'la tarjeta se movió bajo el dedo',
      );

      // Y como el menú sí preguntó, el siguiente arranque ya lo sabe. Si nadie
      // llamara a `comprobar()`, esto no saldría nunca.
      final otra = versiones(prefs);
      addTearDown(otra.dispose);
      await montar(tester, prefs, v: otra);
      expect(find.text(aviso), findsOneWidget);
    });

    testWidgets('ni cuando el menú se repinta por otra cosa', (tester) async {
      // El menú se repinta con cada cambio de la diaria o del progreso: al
      // volver de segundo plano, a medianoche, al aparecer la racha. Si el
      // aviso se decidiera en cada repintado y no una vez, entraría tarde en
      // cualquiera de ellos. Aquí aparece la racha, que además cambia lo que
      // hay encima del aviso.
      final prefs = await prefsCon();
      final red = Completer<Map<String, dynamic>?>();
      final v = versiones(prefs, red: () => red.future);
      addTearDown(v.dispose);
      final progreso = ProgressController(prefs);
      await montar(tester, prefs, v: v, progreso: progreso);
      await tester.pump();
      red.complete({
        nonaGameId: {'android': 33},
      });
      await tester.pumpAndSettle();

      final hoy = DateTime.now();
      progreso.record(
        scoreDaily(
          DailyOutcome(
            dayKey: dayKeyFor(hoy),
            difficulty: Difficulty.easy,
            completed: true,
            mistakes: 0,
            completionPercent: 100,
            seconds: 0,
          ),
        ),
        hoy,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('🔥 1 día de racha'),
        findsOneWidget,
        reason: 'la racha no apareció: el menú no se repintó',
      );
      expect(find.text(aviso), findsNothing);
    });

    testWidgets('con la misma build, o solo con una más nueva de CINCO, no', (
      tester,
    ) async {
      final prefs = await prefsCon();
      final v = versiones(
        prefs,
        red: () async => {
          nonaGameId: {'android': 31},
          // Del documento se lee lo de ESTE juego: que CINCO publique su 99
          // no le dice nada a quien juega Minesweeper.
          'cinco': {'android': 99},
        },
      );
      addTearDown(v.dispose);
      await montar(tester, prefs, v: v);
      await tester.pumpAndSettle();

      final otra = versiones(prefs);
      addTearDown(otra.dispose);
      await montar(tester, prefs, v: otra);
      expect(find.text(diaria), findsOneWidget);
      expect(find.text(aviso), findsNothing);
    });

    testWidgets('sin red, lo que ya estaba no se retira solo', (tester) async {
      final prefs = await prefsCon(publicadaVista: 33);
      final v = versiones(prefs, red: () async => throw Exception('sin red'));
      addTearDown(v.dispose);
      await montar(tester, prefs, v: v);
      final antes = tester.getRect(find.text(diaria));
      await tester.pumpAndSettle();

      expect(find.text(aviso), findsOneWidget);
      expect(tester.getRect(find.text(diaria)), antes);
    });

    testWidgets('sin ficha de tienda no sale', (tester) async {
      // Decir que hay algo nuevo sin poder decir dónde está es peor que
      // callarse: «Actualizar» no haría nada.
      final prefs = await prefsCon(publicadaVista: 33);
      final v = SendaVersiones(
        gameId: nonaGameId,
        firebaseReady: true,
        prefs: prefs,
        esIos: false,
        fuente: () => Completer<Map<String, dynamic>?>().future,
        actualConocida: esta,
      );
      addTearDown(v.dispose);
      expect(v.hayNueva, isTrue, reason: 'sin esto la prueba no mira nada');
      await montar(tester, prefs, v: v);
      expect(find.text(diaria), findsOneWidget);
      expect(find.text(aviso), findsNothing);
    });

    testWidgets('«Actualizar» abre la ficha de Nona fuera de la app', (
      tester,
    ) async {
      final abiertas = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (llamada) async {
          abiertas.add(llamada.arguments as Map<Object?, Object?>);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      final prefs = await prefsCon(publicadaVista: 33);
      final v = versiones(prefs);
      addTearDown(v.dispose);
      await montar(tester, prefs, v: v);

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();

      expect(abiertas, hasLength(1));
      expect(
        abiertas.single['url'],
        'https://play.google.com/store/apps/details?id=com.sendallc.minesweeper',
      );
      // En la app de la tienda, no en un navegador dentro de Nona: desde una
      // vista web no se instala nada.
      expect(abiertas.single['useWebView'], isFalse);
      expect(abiertas.single['useSafariVC'], isFalse);
    });

    testWidgets('la X lo quita, y no vuelve hasta que haya otra más nueva', (
      tester,
    ) async {
      final prefs = await prefsCon(publicadaVista: 33);
      final v = versiones(prefs);
      addTearDown(v.dispose);
      await montar(tester, prefs, v: v);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text(aviso), findsNothing);

      // Del aparato: sobrevive al siguiente arranque.
      final otra = versiones(prefs);
      addTearDown(otra.dispose);
      await montar(tester, prefs, v: otra);
      expect(find.text(aviso), findsNothing);
    });

    testWidgets('el que monta la app lleva la versión que le dio main', (
      tester,
    ) async {
      // Sin versiones inyectadas: el que construye HomeScreen, sin Firebase.
      // Lo guardado y la versión de `main` bastan para decidir; si HomeScreen
      // no le pasara la versión al paquete, no sabría con qué comparar.
      final prefs = await prefsCon(publicadaVista: 33);
      await montar(tester, prefs, versionActual: esta);
      expect(find.text(aviso), findsOneWidget);
    });

    testWidgets('en el teléfono más pequeño y con la letra al máximo, cabe '
        'entero y la X se alcanza', (tester) async {
      // Nona no topa la escala del texto en el menú, así que el aviso recibe
      // la del sistema entera. La fila de CINCO tal cual se salía por la
      // derecha, y con ella la X: un aviso que no se puede cerrar.
      final prefs = await prefsCon(publicadaVista: 33);
      final v = versiones(prefs);
      addTearDown(v.dispose);
      await montar(
        tester,
        prefs,
        v: v,
        pantalla: const Size(320, 568),
        letra: 3.1,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(aviso), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
      final x = find.byTooltip('Cerrar');
      await tester.ensureVisible(x);
      await tester.pump();
      final caja = tester.getRect(x);
      expect(
        caja.left >= 0 &&
            caja.right <= 320 &&
            caja.top >= 0 &&
            caja.bottom <= 568,
        isTrue,
        reason: 'la X queda fuera de la pantalla: $caja',
      );
    });
  });
}
