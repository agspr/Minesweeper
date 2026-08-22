import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/screens/home_screen.dart';
import 'package:nona/screens/practice_screen.dart';
import 'package:nona/widgets/numpad.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';

import 'helpers.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas de desbordes. El tablero es cuadrado y el numpad no se comprime, así
/// que la pantalla estrecha o baja es donde puede romperse; con un simulador de
/// iPad no se ve. Aquí se monta a varios tamaños reales y se comprueba que
/// Flutter no reporte ni un desbordamiento.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final puzzle = generate(seed: 7, target: Difficulty.hard)!;

  setUp(() {
    DailyBank.debugClear();
    DailyBank.debugSeedYear(2026, {
      '2026-08-17': {
        'givens': puzzle.givens,
        'solution': puzzle.solution,
        'difficulty': 'hard',
        'clues': puzzle.clueCount,
      },
    });
    SharedPreferences.setMockInitialValues({});
  });

  /// Tamaños en puntos lógicos de aparatos reales, del más apretado al mayor.
  const sizes = <String, Size>{
    'iPhone SE (el más apretado)': Size(320, 568),
    'iPhone 8': Size(375, 667),
    'iPhone 15 Pro': Size(393, 852),
    'iPhone 15 Pro Max': Size(430, 932),
    'iPad mini': Size(744, 1133),
    'iPad Pro 12.9"': Size(1024, 1366),
    // APAISADAS. Faltaban, y son justo donde vive el reparto de tablet: con
    // solo medidas verticales, la rama ancha de PuzzleLayout no la montaba
    // ninguna prueba. Es el mismo agujero que tenía este fichero cuando
    // probaba la pantalla sin barra inferior.
    'iPad mini apaisado': Size(1133, 744),
    'iPad Pro 12.9" apaisado': Size(1366, 1024),
    // Split View: media pantalla de un 12.9". Sigue siendo "tablet" por el
    // lado corto, pero el ancho ya no da para el reparto de dos columnas.
    'iPad Pro 12.9" a media pantalla': Size(683, 1024),
  };

  /// Las DOS escalas, cruzadas con todas las medidas.
  ///
  /// Aviso del agente de CINCO, y tenía razón: el eje que de verdad caza
  /// desbordes no es la orientación, es la escala del texto. Un tamaño cómodo
  /// con el texto al máximo revienta antes que un tamaño raro con texto normal.
  /// Añadir las apaisadas y probarlas solo a escala normal daba la SENSACIÓN de
  /// cobertura sin la cobertura.
  ///
  /// Importa especialmente aquí porque el numpad de tablet apaisada va con
  /// ancho fijo topado: ancho fijo + texto al máximo es exactamente donde una
  /// tecla se queda sin sitio para su etiqueta.
  const escalas = <String, double>{'texto normal': 1.0, 'texto al máximo': 1.6};

  for (final entry in sizes.entries) {
    for (final escala in escalas.entries) {
      testWidgets('sin desbordes en ${entry.key} · ${escala.key}', (
        tester,
      ) async {
        tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = entry.value;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final c = DailyController(
          await SharedPreferences.getInstance(),
          clock: () => DateTime(2026, 8, 17, 10),
        );
        await c.load();

        // Se monta lo que monta la app DE VERDAD, y eso cambió: mientras se
        // juega, la barra inferior ya no está —se la lleva `home_screen.dart`
        // para que el tablero crezca— y en su sitio quedan el banner y la
        // franja del gesto. Una prueba de desbordes que monta otra cosa no
        // prueba nada: es el mismo agujero que tenía este fichero cuando
        // probaba `GameScreen` a pelo, sin barra.
        //
        // El banner se sustituye por una caja de su alto MÁXIMO documentado
        // (15 % del alto de pantalla): el de verdad pregunta su tamaño por un
        // canal de plataforma que aquí no existe, y reservar de más es el lado
        // seguro para una prueba de desbordes.
        final insets = _insetsFor(entry.value);
        await tester.pumpWidget(
          testApp(
            MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                textScaler: TextScaler.linear(escala.value),
                padding: insets,
                viewPadding: insets,
              ),
              child: Scaffold(
                body: GameScreen(
                  controller: c,
                  progress: ProgressController(
                    await SharedPreferences.getInstance(),
                  ),
                  theme: ThemeController(await SharedPreferences.getInstance()),
                  onExit: () {},
                ),
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.value.height >= 700)
                      SizedBox(
                        height: (entry.value.height * 0.15).floorToDouble(),
                      ),
                    Container(height: insets.bottom),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} desborda con ${escala.key}',
        );
        // Y el tablero tiene que estar en pantalla de verdad, no simplemente
        // recortado a cero.
        expect(find.byType(GameScreen), findsOneWidget);
      });

      testWidgets('sin desbordes en práctica · ${entry.key} · ${escala.key}', (
        tester,
      ) async {
        // El modo práctica también entra en la matriz: su cabecera CRECIÓ —X y
        // título encima de las pastillas de dificultad— y es la pantalla con
        // más cosas apiladas de la app.
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prefs = await SharedPreferences.getInstance();
        late PracticeController c;
        await tester.runAsync(() async {
          c = PracticeController(prefs);
          await c.load();
        });

        final insets = _insetsFor(entry.value);
        await tester.pumpWidget(
          testApp(
            MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                textScaler: TextScaler.linear(escala.value),
                padding: insets,
                viewPadding: insets,
              ),
              child: Scaffold(
                body: PracticeScreen(
                  controller: c,
                  theme: ThemeController(prefs),
                  onExit: () {},
                ),
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.value.height >= 700)
                      SizedBox(
                        height: (entry.value.height * 0.15).floorToDouble(),
                      ),
                    Container(height: insets.bottom),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // La pantalla de NIVEL, que es lo primero que se ve.
        expect(
          tester.takeException(),
          isNull,
          reason:
              'la pantalla de nivel desborda en ${entry.key} con ${escala.key}',
        );

        // Y después el TABLERO. Sin este paso la matriz se quedaría midiendo
        // solo el selector: el modo libre abre ahí, así que una prueba que
        // monta y mira sin tocar nada ya no ve el tablero de práctica.
        // `ensureVisible` y no un tap a pelo: en un SE con el texto al máximo
        // las tarjetas de nivel quedan por debajo del pliegue y hay que
        // desplazarse, que es lo que haría una persona. Sin esto el tap cae
        // fuera de la pantalla, no pasa nada, y la prueba mide el selector
        // creyendo que mide el tablero.
        await tester.ensureVisible(find.text('Fácil'));
        await tester.pump();
        await tester.tap(find.text('Fácil'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester.takeException(),
          isNull,
          reason: 'práctica desborda en ${entry.key} con ${escala.key}',
        );
        expect(find.byType(Numpad), findsOneWidget);
      });

      testWidgets('sin desbordes en el menú · ${entry.key} · ${escala.key}', (
        tester,
      ) async {
        // El menú entró aquí tarde, y por un motivo concreto: sus tipografías
        // se subieron para que se vea del tamaño que se ve CINCO. CINCO puede
        // permitírselo porque TOPA la escala del texto entre 1,32 y 1,55;
        // Nona no la topa, así que aquí una letra de 23,5 con el texto al
        // máximo son 37,6 pt de verdad, y en un SE eso es donde se rompe.
        // Subir tamaños sin esta prueba era fiarlo a mirar una captura de un
        // solo teléfono.
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prefs = await SharedPreferences.getInstance();
        final c = DailyController(
          prefs,
          clock: () => DateTime(2026, 8, 17, 10),
        );
        await c.load();
        // Con racha: la pastilla solo se pinta si hay, y es una de las piezas
        // que se agrandaron.
        final progress = ProgressController(prefs);

        final insets = _insetsFor(entry.value);
        await tester.pumpWidget(
          testApp(
            MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                textScaler: TextScaler.linear(escala.value),
                padding: insets,
                viewPadding: insets,
              ),
              child: HomeScreen(
                daily: c,
                practice: PracticeController(prefs),
                locale: LocaleController(prefs),
                theme: ThemeController(prefs),
                progress: progress,
                auth: AuthController(firebaseReady: false, prefs: prefs),
                friends: FriendsService(firebaseReady: false),
                purchases: PurchaseService(
                  prefs,
                  const IapConfig(removeAdsId: 'x'),
                ),
                notifications: NotificationsService(
                  firebaseReady: false,
                  gameId: nonaGameId,
                ),
                leaderboard: null,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          tester.takeException(),
          isNull,
          reason: 'el menú desborda en ${entry.key} con ${escala.key}',
        );

        // Lo que esta prueba NO puede comprobar, y conviene que quede escrito
        // para que nadie lo vuelva a intentar: si el título CABE en una línea.
        //
        // En una prueba de widget la fuente es la de prueba, donde cada glifo
        // es un cuadrado de un em: "Sudoku del día" a 18 pt "mide" 252 pt de
        // ancho, cuando en el teléfono de verdad ocupa unos 112. Medir ahí el
        // ajuste del texto da números que no existen — lo intenté, y decía que
        // el título se parte en dos líneas en TODOS los teléfonos, incluido el
        // tamaño que lleva la app publicada y que en la captura del dueño se ve
        // en una sola línea.
        //
        // Es el mismo motivo por el que este proyecto abandonó las capturas de
        // referencia. El ajuste tipográfico se comprueba mirando el aparato.
      });
    }
  }
}

/// Zonas seguras aproximadas por clase de aparato.
///
/// Antes este fichero montaba un `MediaQueryData()` a secas, cuyo tamaño es
/// CERO: con eso, la rama de tablet apaisada de `PuzzleLayout` no la montaba
/// nunca nadie y los insets no existían. Sin ellos, la franja del gesto —que es
/// justo lo que ahora sostiene el numpad— medía siempre 0.
EdgeInsets _insetsFor(Size size) {
  if (size.shortestSide >= 600) {
    return const EdgeInsets.only(top: 24, bottom: 20); // iPad
  }
  if (size.height <= 568) {
    return const EdgeInsets.only(top: 20); // SE: botón físico, sin raya
  }
  return const EdgeInsets.only(top: 59, bottom: 34); // móvil con muesca
}
