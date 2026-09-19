import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/home_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **«Hay una versión nueva», y que «Actualizar» lleve a NONA.**
///
/// El aviso llega con el paquete 0.66, pero cada juego pone dos cosas que el
/// paquete no puede comprobar: las fichas de SU tienda y el sitio donde se ve.
/// Las dos fallan en silencio. Sin tiendas el aviso no sale nunca; con las de
/// CINCO copiadas, sale y manda a instalar el otro juego. Y si nadie llama a
/// `comprobar()`, no se entera nadie de que hay algo nuevo, que es lo mismo
/// que no tenerlo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('las fichas son las de Nona', () {
    test('Android: la de com.nonaapp.nona', () {
      expect(
        nonaConfig.tiendaAndroid.toString(),
        'https://play.google.com/store/apps/details?id=com.nonaapp.nona',
      );
    });

    test('iOS: la de Nona, por su id, y sin país fijo', () {
      final ios = nonaConfig.tiendaIos!;
      expect(ios.host, 'apps.apple.com');
      // El id de la ficha de Nona en App Store Connect. El de CINCO es otro,
      // y un copia-pega pasaría la mirada rápida.
      expect(ios.path, '/app/id6802670347');
      // Un `/us/` o un `/es/` delante fija la tienda de un país, y Nona no
      // está en todas: en `/es/` su ficha da 404.
      expect(
        ios.pathSegments.first,
        'app',
        reason: 'el enlace lleva un país fijo: $ios',
      );
    });
  });

  group('el aviso en el menú', () {
    final p = generate(seed: 5, target: Difficulty.easy)!;

    /// La versión de este teléfono y la publicada, sin Firebase ni binario.
    Future<SendaVersiones> versiones({
      required int mia,
      required Map<String, dynamic> publicada,
    }) async => SendaVersiones(
      gameId: nonaGameId,
      firebaseReady: true,
      prefs: await SharedPreferences.getInstance(),
      tiendaAndroid: nonaConfig.tiendaAndroid,
      tiendaIos: nonaConfig.tiendaIos,
      esIos: false,
      fuente: () async => publicada,
      actual: () async => SendaVersionActual(nombre: '1.0.3', build: mia),
    );

    Future<void> montar(
      WidgetTester tester,
      SendaVersiones v, {
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

      final prefs = await SharedPreferences.getInstance();
      final daily = DailyController(
        prefs,
        clock: () => DateTime(2026, 8, 18, 10),
      );
      await daily.load();

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
          ),
        ),
      );
      // La prueba NO llama a `comprobar()`: si el menú no lo hace al montarse,
      // el aviso no sale y la primera prueba cae.
      await tester.pumpAndSettle();
    }

    const aviso = 'Hay una versión nueva';

    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('con una build publicada más nueva, sale encima de la diaria', (
      tester,
    ) async {
      final v = await versiones(
        mia: 31,
        publicada: {
          'nona': {'android': 33},
        },
      );
      addTearDown(v.dispose);
      await montar(tester, v);

      expect(find.text(aviso), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
      // Encima de las tarjetas, que es lo que se ve al abrir.
      expect(
        tester.getRect(find.text(aviso)).top,
        lessThan(tester.getRect(find.text('Sudoku del día')).top),
      );
    });

    testWidgets('en el teléfono más pequeño y con la letra al máximo, cabe '
        'entero y la X se alcanza', (tester) async {
      // Nona no topa la escala del texto en el menú, así que el aviso recibe
      // la del sistema entera. La fila de CINCO tal cual se salía por la
      // derecha, y con ella la X: un aviso que no se puede cerrar.
      final v = await versiones(
        mia: 31,
        publicada: {
          'nona': {'android': 33},
        },
      );
      addTearDown(v.dispose);
      await montar(tester, v, pantalla: const Size(320, 568), letra: 3.1);

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

    testWidgets('con la misma build, o solo con una más nueva de CINCO, no', (
      tester,
    ) async {
      final v = await versiones(
        mia: 31,
        publicada: {
          'nona': {'android': 31},
          // Del documento se lee lo de ESTE juego: que CINCO publique su 99
          // no le dice nada a quien juega Nona.
          'cinco': {'android': 99},
        },
      );
      addTearDown(v.dispose);
      await montar(tester, v);

      expect(find.text('Sudoku del día'), findsOneWidget);
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
      final v = await versiones(
        mia: 31,
        publicada: {
          'nona': {'android': 33},
        },
      );
      addTearDown(v.dispose);
      await montar(tester, v);

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();

      expect(abiertas, hasLength(1));
      expect(
        abiertas.single['url'],
        'https://play.google.com/store/apps/details?id=com.nonaapp.nona',
      );
      // En la app de la tienda, no en un navegador dentro de Nona: desde una
      // vista web no se instala nada.
      expect(abiertas.single['useWebView'], isFalse);
      expect(abiertas.single['useSafariVC'], isFalse);
    });

    testWidgets('la X lo calla hasta que se publique otra más nueva', (
      tester,
    ) async {
      final v = await versiones(
        mia: 31,
        publicada: {
          'nona': {'android': 33},
        },
      );
      addTearDown(v.dispose);
      await montar(tester, v);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text(aviso), findsNothing);

      // Del aparato: se queda en `prefs` y sobrevive al siguiente arranque.
      await v.comprobar();
      await tester.pumpAndSettle();
      expect(find.text(aviso), findsNothing);
    });
  });
}
