import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_bank.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/screens/game_screen.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:nona/widgets/escenas_del_final.dart';
import 'package:nona/widgets/sin_anuncios.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// El final de la diaria en escenas, copiado de CINCO 1.9.
///
/// Lo que se vigila aquí es lo que hace que funcione en la mano: que el botón
/// principal no se mueva entre escenas ni se pueda tocar antes de tiempo, que
/// cada escena salga solo cuando tiene algo que decir, que lo propio de Nona
/// (el desglose, el día a medias sin racha, sin «Recordar») siga así, y que
/// todo quepa y se toque en los teléfonos de verdad — que es donde la tarjeta
/// de antes dejó a alguien sin salida.
DailyScore puntuar({bool terminado = true, int errores = 0}) => scoreDaily(
  DailyOutcome(
    dayKey: '2026-09-24',
    difficulty: Difficulty.medium,
    completed: terminado,
    mistakes: errores,
    completionPercent: terminado ? 100 : 60,
    seconds: 774,
  ),
);

/// Lo que devolvió el final al cerrarse, si se cerró.
class Salida {
  bool cerrada = false;
  AccionDelFinal? accion;
}

/// Monta un botón que abre el final y lo toca.
Future<Salida> abrir(
  WidgetTester tester, {
  DailyScore? score,
  int racha = 12,
  int? hito,
  List<RachaEnLaEscena> amigos = const [],
  Future<List<RachaEnLaEscena>> Function()? recargarAmigos,
  bool repeticion = false,
  PurchaseService? compras,
  Future<void> Function()? onShare,
  Locale idioma = const Locale('es'),

  /// Abre desde un navegador anidado encima de un banner de 127 pt, que es
  /// donde la tarjeta de antes se quedaba sin sitio.
  bool bajoUnBanner = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final salida = Salida();
  Widget pagina(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          salida.accion = await mostrarEscenasDelFinal(
            context,
            score: score ?? puntuar(),
            difficulty: Difficulty.medium,
            elapsed: const Duration(minutes: 12, seconds: 54),
            racha: racha,
            weekDone: const [false, true, true, true, false, false, false],
            todayIndex: 3,
            purchases: compras ?? PurchaseService(prefs, nonaConfig.iap),
            onShare: onShare ?? () async {},
            hito: hito,
            amigos: amigos,
            recargarAmigos: recargarAmigos,
            repeticion: repeticion,
          );
          salida.cerrada = true;
        },
        child: const Text('abrir'),
      ),
    ),
  );
  await tester.pumpWidget(
    testApp(
      bajoUnBanner
          ? Column(
              children: [
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: pagina),
                  ),
                ),
                const SizedBox(key: ValueKey('banner'), height: 127),
              ],
            )
          : Builder(builder: pagina),
      locale: idioma,
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return salida;
}

final principal = find.byKey(const ValueKey('principal'));

bool principalListo(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.descendant(of: principal, matching: find.byType(FilledButton)),
        )
        .onPressed !=
    null;

/// Deja que la escena llegue a encender el botón, y lo toca.
Future<void> continuar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.tap(principal);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

RachaEnLaEscena amigo(
  String u, {
  int n = 5,
  bool falta = false,
  bool subio = false,
}) => RachaEnLaEscena(
  pairId: 'par-$u',
  nombre: 'Nombre de $u',
  usuario: u,
  avatar: 'perro',
  n: n,
  subioHoy: subio,
  falta: falta,
);

/// Una tienda de mentira: lo que la de verdad cuenta por `notifyListeners`,
/// aquí se cuenta a mano.
class Tienda extends PurchaseService {
  Tienda(SharedPreferences prefs, {this.disponible = true})
    : super(prefs, nonaConfig.iap);

  bool disponible;
  bool comprada = false;
  bool ocupada = false;
  String? fallo;
  int compras = 0;
  int restauraciones = 0;

  @override
  bool get available => disponible;
  @override
  String? get price => disponible ? r'$1.99' : null;
  @override
  bool get adsRemoved => comprada;
  @override
  bool get busy => ocupada;
  @override
  String? get error => fallo;

  @override
  Future<void> buy() async {
    compras++;
    ocupada = true;
    notifyListeners();
  }

  @override
  Future<void> restore() async {
    restauraciones++;
    ocupada = true;
    notifyListeners();
  }

  /// La tienda contesta: con la compra, o sin nada.
  void contesta({bool conCompra = false}) {
    ocupada = false;
    comprada = conCompra;
    notifyListeners();
  }

  /// Cambia lo que ofrece, avisando como la de verdad al llegar el producto.
  void ofrece(bool si) {
    disponible = si;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('lo que decide qué se enseña', () {
    test('resultado y racha siempre; hito y amigos cuando los hay', () {
      expect(escenasQueTocan(hito: false, amigos: false), [
        EscenaDelFinal.resultado,
        EscenaDelFinal.racha,
      ]);
      expect(escenasQueTocan(hito: true, amigos: true), [
        EscenaDelFinal.resultado,
        EscenaDelFinal.racha,
        EscenaDelFinal.hito,
        EscenaDelFinal.amigos,
      ]);
    });

    test('el hito, solo el día que la racha LLEGA al número', () {
      const hitos = [10, 25];
      expect(hitoDeHoy(score: puntuar(), racha: 10, hitos: hitos), 10);
      expect(hitoDeHoy(score: puntuar(), racha: 11, hitos: hitos), isNull);
      // Un día a medias no alarga la racha: no llega a nada, aunque el número
      // que queda sea un hito.
      expect(
        hitoDeHoy(score: puntuar(terminado: false), racha: 10, hitos: hitos),
        isNull,
      );
    });

    test('las rachas de amigos salen del servidor, y solo las activas', () {
      final f = FriendsService(gameId: nonaGameId, firebaseReady: false)
        ..friendships = [
          Friendship(
            id: 'par-ana',
            otherUid: 'uid-ana',
            status: 'active',
            requestedByMe: true,
          ),
          Friendship(
            id: 'par-leo',
            otherUid: 'uid-leo',
            status: 'active',
            requestedByMe: true,
          ),
          Friendship(
            id: 'par-sin',
            otherUid: 'uid-sin',
            status: 'active',
            requestedByMe: true,
          ),
          Friendship(
            id: 'par-pen',
            otherUid: 'uid-pen',
            status: 'pending',
            requestedByMe: true,
          ),
        ]
        ..ready = true;
      f.profiles['uid-ana'] = FriendProfile.from('uid-ana', {
        'username': 'ana',
        'displayName': 'Ana',
        'avatar': 'gato',
      });
      f.profiles['uid-leo'] = FriendProfile.from('uid-leo', {
        'username': 'leo',
        'displayName': 'Leo',
      });
      const hoy = '2026-09-24';
      // Ana y yo jugamos hoy y el servidor ya lo contó.
      f.sembrarRacha(
        'par-ana',
        const RachaDeAmigo(
          n: 6,
          ultimoDia: hoy,
          ultimoDiaDe: {'yo': hoy, 'uid-ana': hoy},
        ),
      );
      // Leo todavía no ha jugado.
      f.sembrarRacha(
        'par-leo',
        const RachaDeAmigo(
          n: 3,
          ultimoDia: '2026-09-23',
          ultimoDiaDe: {'yo': hoy, 'uid-leo': '2026-09-23'},
        ),
      );
      f.sembrarRacha('par-sin', null);
      f.sembrarRacha('par-pen', const RachaDeAmigo(n: 9));

      final l = rachasParaLaEscena(f, yo: 'yo', hoy: hoy);
      expect(l.map((a) => a.pairId), ['par-ana', 'par-leo']);
      final ana = l.first;
      expect(
        (ana.nombre, ana.n, ana.subioHoy, ana.falta, ana.contada),
        ('Ana', 6, true, false, true),
      );
      final leo = l.last;
      expect((leo.nombre, leo.usuario), ('Leo', 'leo'));
      expect((leo.subioHoy, leo.falta), (false, true));
    });

    test('la semana sale de los días jugados, no del contador', () async {
      // Lunes, martes, miércoles… jueves NO… viernes. La racha vale 1, y aun
      // así los cuatro días jugados siguen en la fila.
      final progress = ProgressController(
        await SharedPreferences.getInstance(),
      );
      for (final d in [17, 18, 19, 21]) {
        final dia = DateTime(2026, 8, d);
        progress.record(
          scoreDaily(
            DailyOutcome(
              dayKey: dayKeyFor(dia),
              difficulty: Difficulty.easy,
              completed: true,
              mistakes: 0,
              completionPercent: 100,
              seconds: 0,
            ),
          ),
          dia,
        );
      }
      final ahora = DateTime(2026, 8, 21, 10);
      expect(progress.weekDoneAsOf(ahora), [
        true,
        true,
        true,
        false,
        true,
        false,
        false,
      ]);
      expect(progress.streakAsOf(ahora), 1);
    });
  });

  group('las escenas', () {
    testWidgets('el botón principal no se mueve, y no se enciende antes de '
        'media escena', (tester) async {
      await abrir(tester, hito: 10, amigos: [amigo('ana')]);
      final sitios = <Rect>[];
      for (var i = 0; i < 4; i++) {
        // Recién entrada, apagado: un toque de más no se salta la escena.
        expect(principalListo(tester), isFalse, reason: 'escena $i');
        sitios.add(tester.getRect(principal));
        if (i < 3) await continuar(tester);
      }
      expect(sitios.toSet(), hasLength(1), reason: 'se movió: $sitios');
    });

    testWidgets('la última dice «Menú principal» y lleva al menú', (
      tester,
    ) async {
      final salida = await abrir(tester);
      expect(find.text('Continuar'), findsOneWidget);
      await continuar(tester);
      expect(find.text('Menú principal'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(principal);
      await tester.pumpAndSettle();
      expect(salida.accion, AccionDelFinal.menu);
    });

    testWidgets('y «Seguir jugando (Práctica)» lleva a la práctica', (
      tester,
    ) async {
      final salida = await abrir(tester);
      await continuar(tester);
      await tester.tap(find.text('Seguir jugando (Práctica)'));
      await tester.pumpAndSettle();
      expect(salida.accion, AccionDelFinal.practica);
    });

    testWidgets('el desglose se queda en el resultado', (tester) async {
      // Decisión del dueño para Nona: la penalización por errores solo educa
      // si se ve de dónde sale. CINCO no lo tiene.
      await abrir(tester, score: puntuar(errores: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Base del día'), findsOneWidget);
      expect(find.text('2 errores'), findsOneWidget);
      expect(
        find.text('−${puntuar(errores: 2).mistakePenalty}'),
        findsOneWidget,
      );
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('resuelta: la llama prende y se dice cuánto será mañana', (
      tester,
    ) async {
      await abrir(tester, racha: 12);
      await continuar(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Juega mañana y serán 13.'), findsOneWidget);
      expect(find.text('La racha pide terminarlo'), findsNothing);
    });

    testWidgets('a medias: la racha no sube, y se dice por qué', (
      tester,
    ) async {
      // En CINCO jugar ya mantiene la racha; aquí un día a medias no (§1).
      // Decir «juega mañana y serán 13» sería mentir.
      await abrir(tester, score: puntuar(terminado: false), racha: 12);
      await continuar(tester);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('11'), findsNothing, reason: 'el número no sube');
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('La racha pide terminarlo'), findsOneWidget);
      expect(find.textContaining('Juega mañana'), findsNothing);
      // Y hoy no se marca en la semana: los dos días jugados antes, sin hoy.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('resuelta, hoy se marca en la semana', (tester) async {
      await abrir(tester);
      await continuar(tester);
      await tester.pump(const Duration(seconds: 3));
      // Martes y miércoles jugados, y hoy (jueves) recién hecho.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });

    testWidgets('el hito sale solo si lo hay', (tester) async {
      await abrir(tester, hito: 10);
      await continuar(tester);
      await continuar(tester);
      expect(find.text('¡10 días seguidos!'), findsOneWidget);
      expect(find.text('UN HITO DE RACHA'), findsOneWidget);
    });

    testWidgets('la repetición lleva X, no celebra el hito, y cerrarla no '
        'elige nada', (tester) async {
      final salida = await abrir(tester, hito: 10, repeticion: true);
      await continuar(tester);
      expect(find.text('Menú principal'), findsOneWidget, reason: 'sin hito');
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(salida.cerrada, isTrue);
      expect(salida.accion, isNull);
    });

    testWidgets('la celebración no lleva X: se sale por sus botones', (
      tester,
    ) async {
      await abrir(tester);
      expect(find.byTooltip('Cerrar'), findsNothing);
    });

    testWidgets('compartir, arriba, en el resultado', (tester) async {
      var compartido = 0;
      await abrir(tester, onShare: () async => compartido++);
      await tester.tap(find.byTooltip('Compartir'));
      expect(compartido, 1);
      await continuar(tester);
      expect(
        find.byTooltip('Compartir'),
        findsNothing,
        reason: 'en la racha no',
      );
    });

    testWidgets('amigos: quién falta, y sin «Recordar»', (tester) async {
      // El servidor solo manda el empujón si quien lo envía terminó la diaria
      // de CINCO: desde Nona sería un botón que no hace nada.
      await abrir(
        tester,
        amigos: [amigo('ana', subio: true), amigo('leo', falta: true)],
      );
      await continuar(tester);
      await continuar(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Rachas de amigos'), findsOneWidget);
      expect(find.text('Nombre de leo aún no ha jugado hoy.'), findsOneWidget);
      expect(find.text('@ana'), findsOneWidget);
      expect(find.textContaining('Record'), findsNothing);
      // Solo el principal: ningún otro botón relleno en la escena.
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('amigos: espera a la relectura del servidor, un rato', (
      tester,
    ) async {
      var leidas = 0;
      await abrir(
        tester,
        amigos: [amigo('ana', n: 5)],
        recargarAmigos: () async {
          leidas++;
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return [amigo('ana', n: 6, subio: true)];
        },
      );
      expect(leidas, 1, reason: 'se pide al abrir');
      await continuar(tester);
      await continuar(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('6'), findsOneWidget, reason: 'el número releído');
    });

    testWidgets('va encima de todo: también del banner', (tester) async {
      // La tarjeta de antes vivía encima del banner grande, y ahí se quedaba
      // sin sitio. Abierta desde un navegador anidado —como el de cualquier
      // pestaña—, la ruta tiene que ser la raíz y taparlo.
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrir(tester, bajoUnBanner: true);
      expect(
        tester.getRect(principal).bottom,
        greaterThan(874 - 127),
        reason: 'el final se pintó en el hueco de encima del banner',
      );
    });
  });

  group('en los teléfonos de verdad, con Figtree', () {
    setUpAll(() async {
      final figtree = FontLoader('packages/juegos_senda/Figtree');
      for (final peso in [300, 400, 500, 600, 700, 800]) {
        figtree.addFont(
          rootBundle.load(
            'packages/juegos_senda/assets/fonts/Figtree-$peso.ttf',
          ),
        );
      }
      await figtree.load();
    });

    const telefonos = {
      'iPhone 16 Pro': (Size(402, 874), EdgeInsets.only(top: 62, bottom: 34)),
      'iPhone SE': (Size(375, 667), EdgeInsets.only(top: 20)),
    };

    for (final MapEntry(key: nombre, value: (pantalla, margen))
        in telefonos.entries) {
      for (final letra in [1.0, 1.35, 3.1]) {
        for (final idioma in const [Locale('es'), Locale('en')]) {
          testWidgets(
            '$nombre, letra ×$letra, ${idioma.languageCode}: cada escena cabe '
            'y su botón se toca',
            (tester) async {
              tester.view.physicalSize = pantalla;
              tester.view.devicePixelRatio = 1;
              tester.view.padding = FakeViewPadding(
                top: margen.top,
                bottom: margen.bottom,
              );
              tester.platformDispatcher.textScaleFactorTestValue = letra;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(tester.view.resetPadding);
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );

              final salida = await abrir(
                tester,
                score: puntuar(errores: 5),
                hito: 10,
                amigos: [
                  for (final u in ['ana', 'leo', 'mar', 'sol', 'rio'])
                    amigo(u, falta: u == 'leo'),
                ],
                compras: Tienda(await SharedPreferences.getInstance()),
                idioma: idioma,
              );
              final zona = (Offset.zero & pantalla);
              for (var i = 0; i < 4; i++) {
                await tester.pump(const Duration(seconds: 3));
                expect(tester.takeException(), isNull, reason: 'escena $i');
                final caja = tester.getRect(principal);
                expect(
                  zona.contains(caja.topLeft) &&
                      zona.contains(caja.bottomRight - const Offset(1, 1)) &&
                      caja.bottom <= pantalla.height - margen.bottom,
                  isTrue,
                  reason: 'escena $i: el botón se sale de la pantalla: $caja',
                );
                final texto = find.descendant(
                  of: principal,
                  matching: find.byType(RichText),
                );
                final parrafo = tester.renderObject<RenderParagraph>(texto);
                expect(
                  parrafo.getMaxIntrinsicHeight(parrafo.size.width),
                  lessThanOrEqualTo(parrafo.size.height + 0.5),
                  reason: 'escena $i: el texto del botón no cabe entero',
                );
                await tester.tap(principal);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));
              }
              await tester.pumpAndSettle();
              expect(salida.accion, AccionDelFinal.menu);
            },
          );
        }
      }
    }
  });

  group('«Quitar anuncios» en el final', () {
    testWidgets('sin producto no se ofrece', (tester) async {
      final t = Tienda(
        await SharedPreferences.getInstance(),
        disponible: false,
      );
      expect(sePuedeOfrecerSinAnuncios(t), isFalse);
      await abrir(tester, compras: t);
      expect(find.textContaining('Jugar sin anuncios'), findsNothing);
    });

    testWidgets(
      'se decide al abrir: si el producto llega después, no aparece',
      (tester) async {
        final t = Tienda(
          await SharedPreferences.getInstance(),
          disponible: false,
        );
        await abrir(tester, compras: t);
        final antes = tester.getRect(principal);
        t.ofrece(true);
        // Y aunque la escena se vuelva a construir por otra cosa —girar el
        // teléfono, cambiar el tema—: sin forzarlo, nada la reconstruye aquí
        // y la prueba pasaría decida el enlace cuando decida.
        tester.element(find.byType(EscenasDelFinal)).markNeedsBuild();
        await tester.pump();
        expect(find.textContaining('Jugar sin anuncios'), findsNothing);
        expect(tester.getRect(principal), antes);
      },
    );

    testWidgets('abre la hoja, no compra; y la hoja compra, y se cierra sola', (
      tester,
    ) async {
      final t = Tienda(await SharedPreferences.getInstance());
      await abrir(tester, compras: t);
      await tester.tap(find.text(r'Jugar sin anuncios · $1.99'));
      await tester.pumpAndSettle();
      expect(t.compras, 0, reason: 'un toque en el enlace no cobra');
      expect(find.byType(HojaSinAnuncios), findsOneWidget);
      await tester.tap(find.text(r'Quitar anuncios · $1.99'));
      await tester.pump();
      expect(t.compras, 1);
      t.contesta(conCompra: true);
      await tester.pumpAndSettle();
      expect(find.byType(HojaSinAnuncios), findsNothing);
      expect(find.text('Listo: ya no verás anuncios'), findsOneWidget);
    });

    testWidgets('restaurar sin nada que restaurar lo dice', (tester) async {
      final t = Tienda(await SharedPreferences.getInstance());
      await abrir(tester, compras: t);
      await tester.tap(find.text(r'Jugar sin anuncios · $1.99'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar compras'));
      await tester.pump();
      expect(t.restauraciones, 1);
      t.contesta();
      await tester.pump();
      expect(
        find.text('No encontramos ninguna compra que restaurar.'),
        findsOneWidget,
      );
    });

    testWidgets('solo en la primera escena', (tester) async {
      await abrir(
        tester,
        compras: Tienda(await SharedPreferences.getInstance()),
      );
      expect(find.byType(EnlaceSinAnuncios), findsOneWidget);
      await continuar(tester);
      expect(find.byType(EnlaceSinAnuncios), findsNothing);
    });
  });

  group('la diaria abre el final', () {
    final p = generate(seed: 5, target: Difficulty.easy)!;

    Future<(DailyController, List<String>)> montar(
      WidgetTester tester,
      SharedPreferences prefs,
    ) async {
      DailyBank.debugClear();
      DailyBank.debugSeedYear(2026, {
        '2026-08-18': {
          'givens': p.givens,
          'solution': p.solution,
          'difficulty': 'easy',
          'clues': p.clueCount,
        },
      });
      final daily = DailyController(
        prefs,
        clock: () => DateTime(2026, 8, 18, 10),
      );
      await daily.load();
      final salidas = <String>[];
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: GameScreen(
              controller: daily,
              progress: ProgressController(prefs),
              theme: ThemeController(prefs),
              friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
              purchases: PurchaseService(prefs, nonaConfig.iap),
              onExit: () => salidas.add('menú'),
              onPractice: () => salidas.add('práctica'),
            ),
          ),
        ),
      );
      await tester.pump();
      return (daily, salidas);
    }

    void resolver(DailyController c) {
      for (var i = 0; i < cellCount; i++) {
        if (c.board!.isGiven(i)) continue;
        c.select(i);
        c.tapDigit(c.board!.solution[i]);
      }
    }

    testWidgets('al terminarla, la celebración entera, y el menú al salir', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final (daily, salidas) = await montar(tester, prefs);
      expect(find.byType(EscenasDelFinal), findsNothing);
      resolver(daily);
      // Un fotograma para verla terminada (y abrir el final tras él), otro en
      // que la ruta nueva se monta fuera de escena, y el de la transición.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(EscenasDelFinal), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsNothing, reason: 'es celebración');
      await continuar(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(principal);
      await tester.pumpAndSettle();
      expect(salidas, ['menú']);
    });

    testWidgets('abrir una ya hecha enseña la repetición, y cerrarla deja el '
        'tablero', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final (daily, _) = await montar(tester, prefs);
      resolver(daily);
      await tester.pumpAndSettle();
      // Otra vez, como al volver a la diaria desde el menú.
      await tester.pumpWidget(const SizedBox());
      final (_, salidas) = await montar(tester, prefs);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(EscenasDelFinal), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(EscenasDelFinal), findsNothing);
      expect(salidas, isEmpty, reason: 'cerrar la repetición no se va');
    });
  });
}
