/// El final de la diaria, en escenas a pantalla completa.
///
/// Copiado de CINCO 1.9 (`escenas_del_final.dart` allí), que sustituyó su
/// tarjeta de siempre; aquí sustituye a la tarjeta del resultado. Hasta cuatro
/// escenas, cada una solo si tiene algo que enseñar, como en Duolingo (el vídeo
/// de André, 24-9-2026):
///
/// 1. **El resultado**: el sudoku, resuelto o no, los errores, los puntos y su
///    desglose.
/// 2. **La racha**: la llama que prende, el número que sube y la semana.
/// 3. **El hito**, el día que toca (10, 25, 50…).
/// 4. **Las rachas de amigos**, si tienes alguna: quién ya jugó —y sube
///    contigo— y quién falta, con «Recordar».
///
/// **Lo que cambia respecto a CINCO, y por qué:**
///
/// - **El desglose se queda** en el resultado. Es decisión del dueño para Nona
///   (la penalización por errores solo educa si se ve de dónde sale), y la
///   tarjeta que esto sustituye ya la llevaba.
/// - **Un día a medias no alarga la racha** (§1), cuando en CINCO jugar ya la
///   mantiene. Así que la llama no prende y el pie dice por qué, en vez de
///   «tu racha sigue viva», que aquí sería falso.
/// - **«Recordar» manda el empujón de NONA**, sin el `origen` que CINCO pone al
///   evento: la política de Nona declara el empujón, no ese campo. Llegó un día
///   después que el resto: hasta el 25-9-2026 el servidor solo sabía de
///   empujones de CINCO —miraba si quien empuja había jugado a CINCO—, y aquí
///   habría sido un botón que no hace nada (paquete 0.70.0).
/// - Los textos salen del ARB: Nona es bilingüe y CINCO no.
///
/// **El botón principal está en el mismo sitio en todas**, y se enciende a
/// media escena: se toca «Continuar» varias veces seguidas, y un toque de más
/// no puede caer en otra cosa ni saltarse una escena sin verla.
///
/// **Material 3 Expressive**, con las piezas de CINCO: movimiento de muelle
/// ([Resorte]), botones que cambian de forma al pulsarlos, contenedores
/// tonales, la lista agrupada y la forma festoneada detrás de la llama.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../game/difficulty.dart';
import '../game/scoring.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'difficulty_label.dart';
import 'sin_anuncios.dart';

// ── Los datos ──────────────────────────────────────────────────────────

/// Qué eligió el jugador al salir del final.
enum AccionDelFinal { practica, menu }

/// Un amigo con racha, como lo pinta la escena. El número es **el del
/// servidor**: quien la monte no lo deduce.
class RachaEnLaEscena {
  const RachaEnLaEscena({
    required this.pairId,
    required this.nombre,
    required this.usuario,
    required this.avatar,
    required this.n,
    required this.subioHoy,
    required this.falta,
    this.contada = true,
    this.recordado = false,
  });

  final String pairId;
  final String nombre;
  final String usuario;
  final String avatar;

  /// Los días de la racha, tal como los tiene el servidor.
  final int n;

  /// Los dos jugaron hoy y el servidor ya lo contó: [n] incluye hoy.
  final bool subioHoy;

  /// El amigo no ha jugado hoy: si no juega, la racha se rompe.
  final bool falta;

  /// El servidor ya apuntó MI partida de hoy en esta racha. Mientras no, [n]
  /// es el de antes y la escena no lo sube por su cuenta.
  final bool contada;

  /// Ya le mandaste el empujón hoy.
  final bool recordado;
}

/// Las rachas de amigos de este juego, listas para la escena. **Pura**: todo
/// sale de lo que [friends] ya tiene leído.
///
/// Solo las amistades activas con racha. Del servidor salen el número y quién
/// jugó hoy (`ultimoDiaDe`, que el servidor apunta al guardarse el día);
/// «subió» exige además que haya contado hoy como día conjunto.
List<RachaEnLaEscena> rachasParaLaEscena(
  FriendsService friends, {
  required String? yo,
  required String hoy,
}) {
  final out = <RachaEnLaEscena>[];
  for (final f in friends.friendships) {
    if (!f.isActive) continue;
    final r = friends.rachaCon(f.id);
    if (r == null) continue;
    final perfil = friends.profiles[f.otherUid];
    final miDia = yo != null && r.jugoHoy(yo, hoy);
    final suDia = r.jugoHoy(f.otherUid, hoy);
    final avatar = perfil?.avatar ?? '';
    final usuario = perfil?.username ?? '';
    out.add(
      RachaEnLaEscena(
        pairId: f.id,
        nombre: (perfil?.displayName.isNotEmpty ?? false)
            ? perfil!.displayName
            : '@$usuario',
        usuario: usuario,
        avatar: avatar.isEmpty ? Avatars.defaultFor(f.otherUid) : avatar,
        n: r.n,
        subioHoy: miDia && suDia && r.ultimoDia == hoy,
        falta: !suDia,
        contada: miDia,
        recordado: friends.nudgedToday(f.otherUid),
      ),
    );
  }
  return out;
}

/// Relee las rachas hasta que el servidor haya contado la partida de hoy en
/// todas, o hasta [intentos] veces: lo hace un segundo o dos después de
/// guardarse. Devuelve lo último leído, contado o no.
Future<List<RachaEnLaEscena>> releerHastaQueCuente({
  required Future<void> Function() recargar,
  required List<RachaEnLaEscena> Function() leer,
  Duration espera = const Duration(milliseconds: 1200),
  int intentos = 3,
}) async {
  for (var i = 0; i < intentos; i++) {
    if (i > 0) await Future<void>.delayed(espera);
    await recargar();
    final amigos = leer();
    if (amigos.every((a) => a.contada)) return amigos;
  }
  return leer();
}

/// El hito que se celebra hoy, o null. **Pura.** Solo el día que la racha
/// LLEGA al número: una repetición o un día que no la alargó no celebran
/// nada, aunque la racha siga en ese número.
int? hitoDeHoy({
  required DailyScore score,
  required int racha,
  required List<int> hitos,
}) => score.extendsStreak && hitos.contains(racha) ? racha : null;

/// Las escenas que tocan, en orden. **Pura.**
List<EscenaDelFinal> escenasQueTocan({
  required bool hito,
  required bool amigos,
}) => [
  EscenaDelFinal.resultado,
  EscenaDelFinal.racha,
  if (hito) EscenaDelFinal.hito,
  if (amigos) EscenaDelFinal.amigos,
];

enum EscenaDelFinal { resultado, racha, hito, amigos }

/// El color de la racha: el naranja de la llama, el mismo de CINCO. No el
/// acento del tema: la racha es la misma en todos los temas y en los dos
/// juegos.
const kColorDeRacha = Color(0xFFFFB454);
const _tintaSobreRacha = Color(0xFF2A1A04);

// ── El movimiento: muelles de M3 Expressive ────────────────────────────

/// Una curva de muelle, con la rigidez y el amortiguamiento del sistema de
/// física de Material 3 Expressive. Se estira al tramo que le toca, así que
/// lo que conserva del muelle es su carácter: cuánto se pasa y cómo vuelve.
class Resorte extends Curve {
  const Resorte(this.amortiguamiento, this.rigidez);

  /// Espacial rápido de M3E: el que rebota, para lo que entra de golpe.
  static const rapido = Resorte(.6, 800);

  /// Espacial por omisión de M3E.
  static const normal = Resorte(.8, 380);

  final double amortiguamiento;
  final double rigidez;

  static final Map<(double, double), (SpringSimulation, double)> _cache = {};

  (SpringSimulation, double) get _muelle =>
      _cache[(amortiguamiento, rigidez)] ??= () {
        final sim = SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: rigidez,
            ratio: amortiguamiento,
          ),
          0,
          1,
          0,
          tolerance: const Tolerance(distance: .001, velocity: .01),
        );
        var t = 0.0;
        while (!sim.isDone(t) && t < 3) {
          t += 1 / 240;
        }
        return (sim, t);
      }();

  @override
  double transformInternal(double t) {
    final (sim, duracion) = _muelle;
    return sim.x(t * duracion);
  }
}

// ── La entrada ─────────────────────────────────────────────────────────

/// Abre el final. Devuelve lo que eligió el jugador, o null si lo cerró con
/// la X de una repetición (o con el gesto de volver).
Future<AccionDelFinal?> mostrarEscenasDelFinal(
  BuildContext context, {
  required DailyScore score,
  required Difficulty difficulty,
  required Duration elapsed,

  /// La racha DESPUÉS de esta partida.
  required int racha,
  required List<bool> weekDone,
  required int todayIndex,
  required PurchaseService purchases,
  required Future<void> Function() onShare,

  /// El hito que se celebra hoy ([hitoDeHoy]), o null.
  int? hito,

  /// Las rachas tal como están leídas ahora. Deciden si hay escena de amigos.
  List<RachaEnLaEscena> amigos = const [],

  /// Las mismas, releídas del servidor. Se pide al abrir y la escena de
  /// amigos espera a que llegue (un rato, no para siempre): el servidor mueve
  /// las rachas un segundo después de guardarse la partida.
  Future<List<RachaEnLaEscena>> Function()? recargarAmigos,

  /// «Recordar»: el empujón a un amigo que aún no ha jugado hoy.
  Future<void> Function(String pairId)? onRecordar,

  /// Volver a verlas al abrir una diaria ya terminada: con una X para irse en
  /// cualquier momento, y sin el hito ni vibraciones.
  bool repeticion = false,
}) {
  // En el navegador RAÍZ, encima de todo, banner incluido. La tarjeta de antes
  // vivía en el hueco de encima del banner grande, y con la letra algo grande
  // «Menú principal» se quedaba fuera de la pantalla (2d21a2e). Aquí no puede
  // pasar mientras esto diga raíz.
  return Navigator.of(context, rootNavigator: true).push<AccionDelFinal>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => EscenasDelFinal(
        score: score,
        difficulty: difficulty,
        elapsed: elapsed,
        racha: racha,
        weekDone: weekDone,
        todayIndex: todayIndex,
        purchases: purchases,
        onShare: onShare,
        hito: repeticion ? null : hito,
        amigos: amigos,
        recargarAmigos: recargarAmigos,
        onRecordar: onRecordar,
        repeticion: repeticion,
      ),
      transitionsBuilder: (_, a, _, hijo) =>
          FadeTransition(opacity: a, child: hijo),
    ),
  );
}

class EscenasDelFinal extends StatefulWidget {
  const EscenasDelFinal({
    super.key,
    required this.score,
    required this.difficulty,
    required this.elapsed,
    required this.racha,
    required this.weekDone,
    required this.todayIndex,
    required this.purchases,
    required this.onShare,
    this.hito,
    this.amigos = const [],
    this.recargarAmigos,
    this.onRecordar,
    this.repeticion = false,
  });

  final DailyScore score;
  final Difficulty difficulty;
  final Duration elapsed;
  final int racha;
  final List<bool> weekDone;
  final int todayIndex;
  final PurchaseService purchases;
  final Future<void> Function() onShare;
  final int? hito;
  final List<RachaEnLaEscena> amigos;
  final Future<List<RachaEnLaEscena>> Function()? recargarAmigos;
  final Future<void> Function(String pairId)? onRecordar;
  final bool repeticion;

  /// Lo que espera la escena de amigos a la relectura antes de enseñar lo que
  /// ya había.
  static const esperaDeLosAmigos = Duration(seconds: 3);

  @override
  State<EscenasDelFinal> createState() => _EscenasDelFinalState();
}

class _EscenasDelFinalState extends State<EscenasDelFinal>
    with SingleTickerProviderStateMixin {
  late final List<EscenaDelFinal> _escenas = escenasQueTocan(
    hito: widget.hito != null,
    amigos: widget.amigos.isNotEmpty,
  );
  late final AnimationController _c = AnimationController(vsync: this);
  late List<RachaEnLaEscena> _amigos = widget.amigos;
  Future<void>? _recarga;
  bool _recargaHecha = false;
  bool _esperando = false;
  int _i = 0;

  EscenaDelFinal get _escena => _escenas[_i];
  bool get _ultima => _i == _escenas.length - 1;

  static const _duraciones = {
    EscenaDelFinal.resultado: Duration(milliseconds: 1300),
    EscenaDelFinal.racha: Duration(milliseconds: 2600),
    EscenaDelFinal.hito: Duration(milliseconds: 900),
    EscenaDelFinal.amigos: Duration(milliseconds: 1500),
  };

  @override
  void initState() {
    super.initState();
    final recargar = widget.recargarAmigos;
    if (recargar != null && _escenas.contains(EscenaDelFinal.amigos)) {
      _recarga = recargar()
          .then((l) {
            // Si entre tanto la racha desapareció, se queda lo que había: una
            // escena de amigos vacía no dice nada.
            if (mounted && l.isNotEmpty) setState(() => _amigos = l);
          })
          .catchError((Object _) {})
          .whenComplete(() => _recargaHecha = true);
    }
    _empezar();
  }

  void _empezar() {
    _c.duration = _duraciones[_escena];
    _c.forward(from: 0);
    if (_escena == EscenaDelFinal.hito) Haptics.milestone();
  }

  Future<void> _siguiente() async {
    if (_ultima || _esperando) return;
    final recarga = _recarga;
    if (_escenas[_i + 1] == EscenaDelFinal.amigos &&
        recarga != null &&
        !_recargaHecha) {
      setState(() => _esperando = true);
      await recarga.timeout(
        EscenasDelFinal.esperaDeLosAmigos,
        onTimeout: () {},
      );
      if (!mounted) return;
      _esperando = false;
    }
    setState(() => _i++);
    _empezar();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final escena = switch (_escena) {
      EscenaDelFinal.resultado => _Resultado(
        c: _c,
        score: widget.score,
        difficulty: widget.difficulty,
        elapsed: widget.elapsed,
      ),
      EscenaDelFinal.racha => _Racha(
        c: _c,
        score: widget.score,
        racha: widget.racha,
        weekDone: widget.weekDone,
        todayIndex: widget.todayIndex,
        repeticion: widget.repeticion,
      ),
      EscenaDelFinal.hito => EscenaDeHito(
        controller: _c,
        numero: widget.hito!,
        color: NonaColors.accent,
        titulo: l.sceneMilestoneTitle(widget.hito!),
        rotulo: l.sceneMilestoneLabel.toUpperCase(),
      ),
      EscenaDelFinal.amigos => _Amigos(
        c: _c,
        amigos: _amigos,
        onRecordar: widget.onRecordar,
      ),
    };

    // Se comparte el resultado, que ya lleva la racha: en el hito es el
    // número que se celebra.
    final compartir = switch (_escena) {
      EscenaDelFinal.resultado || EscenaDelFinal.hito => widget.onShare,
      _ => null,
    };

    return Scaffold(
      backgroundColor: NonaColors.appBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                // La barra de arriba mide lo mismo con X y sin ella, y con
                // «Compartir» y sin él. Compartir va aquí y no junto al botón
                // principal: a su lado lo estrechaba en unas escenas y no en
                // otras, y un toque de más en «Continuar» caía en compartir.
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        if (widget.repeticion)
                          IconButton(
                            tooltip: SendaL.of(context).close,
                            icon: const Icon(Icons.close_rounded),
                            color: NonaColors.muted,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        const Spacer(),
                        if (compartir != null)
                          _BotonDeCompartir(
                            tooltip: l.share,
                            onPressed: compartir,
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (hijo, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(.06, 0),
                          end: Offset.zero,
                        ).animate(a),
                        child: hijo,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_i),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: escena,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: _Botones(
                    c: _c,
                    ultima: _ultima,
                    esperando: _esperando,
                    onContinuar: _siguiente,
                    // «Jugar sin anuncios» solo en la primera: una oferta en
                    // cada escena sería insistir.
                    sinAnuncios: _escena == EscenaDelFinal.resultado
                        ? widget.purchases
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Los botones, fijos abajo ───────────────────────────────────────────

/// Alto del botón principal: el tamaño mediano de los botones de M3E.
const kAltoDelPrincipal = 56.0;

/// Dos filas de alto fijo: la del botón principal y la de debajo. Lo que
/// cambia entre escenas es lo que dicen, nunca dónde están.
class _Botones extends StatelessWidget {
  const _Botones({
    required this.c,
    required this.ultima,
    required this.esperando,
    required this.onContinuar,
    required this.sinAnuncios,
  });

  final AnimationController c;
  final bool ultima;
  final bool esperando;
  final VoidCallback onContinuar;
  final PurchaseService? sinAnuncios;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: kAltoDelPrincipal,
          child: Row(
            children: [
              Expanded(
                // Se enciende a media escena: ni se salta sin verla, ni un
                // toque de más cae en la siguiente.
                child: AnimatedBuilder(
                  animation: c,
                  builder: (context, _) {
                    final listo =
                        (c.value >= .5 || c.isCompleted) && !esperando;
                    return BotonExpresivo(
                      key: const ValueKey('principal'),
                      texto: ultima ? l.closeGame : l.sceneContinue,
                      girando: esperando,
                      onPressed: !listo
                          ? null
                          : ultima
                          ? () => Navigator.of(context).pop(AccionDelFinal.menu)
                          : onContinuar,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: EnlaceSinAnuncios.alto,
          child: ultima
              ? TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(AccionDelFinal.practica),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.keepPlayingPractice,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: NonaColors.accent,
                      ),
                    ),
                  ),
                )
              : sinAnuncios == null
              ? null
              : EnlaceSinAnuncios(compras: sinAnuncios!),
        ),
      ],
    );
  }
}

/// El botón principal de M3 Expressive: redondo del todo, y **al pulsarlo se
/// cuadra** (el cambio de forma que M3E usa para decir «te he oído»).
class BotonExpresivo extends StatelessWidget {
  const BotonExpresivo({
    super.key,
    required this.texto,
    required this.onPressed,
    this.girando = false,
  });

  final String texto;
  final VoidCallback? onPressed;

  /// Esperando a algo: el botón se queda, con un indicador dentro.
  final bool girando;

  /// El radio pulsado. Suelto es la mitad del alto: redondo del todo.
  static const radioPulsado = 14.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: kAltoDelPrincipal,
      child: FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? NonaColors.accent.withValues(alpha: .35)
                : NonaColors.accent,
          ),
          foregroundColor: WidgetStatePropertyAll(NonaColors.accentDeep),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          animationDuration: const Duration(milliseconds: 180),
          shape: WidgetStateProperty.resolveWith(
            (s) => RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                s.contains(WidgetState.pressed)
                    ? radioPulsado
                    : kAltoDelPrincipal / 2,
              ),
            ),
          ),
        ),
        child: girando
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: NonaColors.accentDeep,
                ),
              )
            // Con la letra grande se encoge hasta caber en el alto fijo, en
            // vez de partirse y cortarse: el alto es lo que mantiene el botón
            // en el mismo sitio en todas las escenas.
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  texto,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: NonaColors.accentDeep,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Compartir: el botón de icono tonal de M3E, arriba a la derecha. Cuadrado de
/// esquinas grandes, y más cuadrado al pulsarlo.
class _BotonDeCompartir extends StatelessWidget {
  const _BotonDeCompartir({required this.tooltip, required this.onPressed});

  final String tooltip;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(iconoDeCompartir()),
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(NonaColors.accentChip),
          foregroundColor: WidgetStatePropertyAll(NonaColors.accent),
          animationDuration: const Duration(milliseconds: 180),
          shape: WidgetStateProperty.resolveWith(
            (s) => RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                s.contains(WidgetState.pressed) ? 8 : 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un tramo de la escena. **Topado en 1**: los escalonados por fila se
/// alargan con cada amigo, y con cinco el último acababa pasado el final de
/// la escena, que es una aserción de `Interval` en vez de una fila tardía.
Animation<double> _tramo(
  AnimationController c,
  double desde,
  double hasta, [
  Curve curva = Curves.easeOut,
]) {
  final h = math.min(hasta, 1.0);
  return CurvedAnimation(
    parent: c,
    curve: Interval(math.min(desde, h - .05), h, curve: curva),
  );
}

// ── 1. El resultado ────────────────────────────────────────────────────

class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.c,
    required this.score,
    required this.difficulty,
    required this.elapsed,
  });

  final AnimationController c;
  final DailyScore score;
  final Difficulty difficulty;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final datos = _tramo(c, .55, 1, Resorte.normal);
    final errores = score.countedMistakes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.sceneTodaysSudoku.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: NonaColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        // Una caja de 3×3 que entra casilla a casilla: el sitio que en CINCO
        // ocupan las letras de la palabra.
        _Caja(c: c, llena: score.completed),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: _tramo(c, .4, .7),
          child: Column(
            children: [
              Text(
                score.completed ? l.solved : l.unfinished,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: NonaColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${difficultyLabel(context, difficulty)} · ${_reloj(elapsed)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: NonaColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: _tramo(c, .55, .8),
          child: ScaleTransition(
            scale: Tween(begin: .85, end: 1.0).animate(datos),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _Dato(
                    rotulo: l.sceneMistakes.toUpperCase(),
                    valor: '$errores',
                    color: errores > 0 ? NonaColors.wrong : NonaColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: _Dato(
                    rotulo: l.scenePoints.toUpperCase(),
                    valor: '+${score.points}',
                    color: NonaColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: _tramo(c, .7, 1),
          child: _Desglose(score: score),
        ),
      ],
    );
  }
}

String _reloj(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// La caja de 3×3 con sus nueve cifras, llena del acento si se resolvió.
class _Caja extends StatelessWidget {
  const _Caja({required this.c, required this.llena});

  final AnimationController c;
  final bool llena;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var fila = 0; fila < 3; fila++) ...[
          if (fila > 0) const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 6),
                ScaleTransition(
                  scale: _tramo(
                    c,
                    (fila * 3 + col) * .035,
                    .3 + (fila * 3 + col) * .035,
                    Resorte.rapido,
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: llena ? NonaColors.accent : NonaColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${fila * 3 + col + 1}',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: llena ? NonaColors.accentDeep : NonaColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Un dato en su contenedor tonal: el color de lo que cuenta, suave de fondo
/// y fuerte en el rótulo.
class _Dato extends StatelessWidget {
  const _Dato({required this.rotulo, required this.valor, required this.color});

  final String rotulo;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rotulo,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: NonaColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El desglose: base del día, lo que restaron los errores (o lo completado,
/// si quedó a medias) y el total. Suma exactamente el dato de arriba.
class _Desglose extends StatelessWidget {
  const _Desglose({required this.score});

  final DailyScore score;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: NonaColors.sheet,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _Linea(etiqueta: l.breakdownBase, valor: '${score.base}'),
          if (score.completed)
            if (score.countedMistakes > 0)
              _Linea(
                etiqueta:
                    l.mistakeCount(score.countedMistakes) +
                    (score.countedMistakes == maxCountedMistakes
                        ? l.mistakeCapSuffix
                        : ''),
                valor: '−${score.mistakePenalty}',
                negativa: true,
              )
            else
              _Linea(etiqueta: l.breakdownNoMistakes, valor: '−0')
          else
            _Linea(
              etiqueta: l.breakdownCompleted(score.completionPercent),
              valor: '×${(score.partialFraction ?? 0) * 100 ~/ 1}%',
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: NonaColors.surface),
          ),
          _Linea(
            etiqueta: l.breakdownTotal,
            valor: '${score.points}',
            fuerte: true,
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({
    required this.etiqueta,
    required this.valor,
    this.negativa = false,
    this.fuerte = false,
  });

  final String etiqueta;
  final String valor;
  final bool negativa;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // La etiqueta se parte en líneas y el número se queda entero: con la
          // letra grande, «Completaste el 60 %…» empujaba la cifra fuera.
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 14,
                fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
                color: fuerte ? NonaColors.text : NonaColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: negativa
                  ? NonaColors.wrong
                  : fuerte
                  ? NonaColors.accent
                  : NonaColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. La racha ────────────────────────────────────────────────────────

class _Racha extends StatefulWidget {
  const _Racha({
    required this.c,
    required this.score,
    required this.racha,
    required this.weekDone,
    required this.todayIndex,
    required this.repeticion,
  });

  final AnimationController c;
  final DailyScore score;
  final int racha;
  final List<bool> weekDone;
  final int todayIndex;
  final bool repeticion;

  @override
  State<_Racha> createState() => _RachaState();
}

class _RachaState extends State<_Racha> {
  bool _vibro = false;

  /// La llama prende si HOY alarga la racha. Un día a medias no (§1): la
  /// racha se enseña, pero apagada, y el pie dice por qué.
  bool get _prende => widget.score.extendsStreak;

  @override
  void initState() {
    super.initState();
    widget.c.addListener(_alPrender);
  }

  @override
  void dispose() {
    widget.c.removeListener(_alPrender);
    super.dispose();
  }

  /// Un golpe cuando la llama prende: el momento que se siente en la mano.
  void _alPrender() {
    if (_vibro || widget.repeticion || !_prende || widget.c.value < .24) {
      return;
    }
    _vibro = true;
    Haptics.submit();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = widget.c;
    final n = widget.racha;
    // Una repetición no vuelve a subir el número: ya subió.
    final desde = _prende && !widget.repeticion ? math.max(n - 1, 0) : n;
    // Apagada un momento después de entrar la escena (el cambio de escena
    // tarda 280 ms): si prende antes, no se la ve apagada.
    final prende = _tramo(c, .22, .44, Resorte.rapido);
    final sube = _tramo(c, .32, .52, Resorte.normal);
    final pie = _tramo(c, .75, .95);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Llama(
          prende: prende,
          tamano: 104,
          festoneada: true,
          gira: c,
          viva: _prende,
        ),
        const SizedBox(height: 4),
        _Contador(
          desde: desde,
          hasta: n,
          sube: sube,
          tamano: 96,
          color: _prende ? kColorDeRacha : NonaColors.muted,
        ),
        Text(
          l.sceneStreakDays(n),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _prende ? kColorDeRacha : NonaColors.muted,
          ),
        ),
        const SizedBox(height: 32),
        FilaDeLaSemana(
          seg: (a, b, [curva = Curves.easeOut]) =>
              _tramo(c, .4 + a * .4, .4 + b * .4, curva),
          todayFill: _tramo(c, .58, .78, Curves.easeOutBack),
          todayIndex: widget.todayIndex,
          hoyCuenta: _prende,
          weekDone: widget.weekDone,
        ),
        const SizedBox(height: 28),
        FadeTransition(
          opacity: pie,
          child: Text(
            _prende ? l.sceneStreakTomorrow(n + 1) : l.streakNeedsFinish,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: NonaColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// La semana de lunes a domingo, con hoy rellenándose. La de CINCO
/// (`semana.dart` allí), con las iniciales del paquete —las de cada idioma— y
/// los colores del tema de Nona.
///
/// Los días de antes salen de los REALMENTE jugados ([weekDone]), no de la
/// racha: deducirlos de la racha borraba los anteriores a un hueco.
class FilaDeLaSemana extends StatelessWidget {
  const FilaDeLaSemana({
    super.key,
    required this.seg,
    required this.todayFill,
    required this.todayIndex,
    required this.hoyCuenta,
    required this.weekDone,
  });

  final Animation<double> Function(double, double, [Curve]) seg;
  final Animation<double> todayFill;

  /// Qué posición es hoy (0 = lunes).
  final int todayIndex;

  /// Hoy cuenta para la racha: se rellena. Un día a medias se queda en anillo.
  final bool hoyCuenta;
  final List<bool> weekDone;

  @override
  Widget build(BuildContext context) {
    final letras = SendaL.of(context).weekdayInitials.split('');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          ScaleTransition(
            scale: seg(.15 + i * .04, .35 + i * .04, Curves.easeOutBack),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _punto(i),
                const SizedBox(height: 6),
                Text(
                  letras.length > i ? letras[i] : '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                    // Hoy destacado: la letra se repite (M, M o T, T), así
                    // que lo que distingue una casilla es su posición, y el
                    // destacado ayuda a encontrarse sin contar desde el lunes.
                    color: i == todayIndex
                        ? NonaColors.accent
                        : (i > todayIndex
                              ? SendaColors.mutedDeep
                              : NonaColors.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _punto(int i) {
    if (i == todayIndex) {
      if (!hoyCuenta) return _circulo(lleno: false, color: NonaColors.accent);
      // Se rellena en su fase, con anillo de pulso.
      return AnimatedBuilder(
        animation: todayFill,
        builder: (context, _) {
          final t = todayFill.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (t > 0 && t < 1)
                Container(
                  width: 34 + t * 22,
                  height: 34 + t * 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NonaColors.accent.withValues(alpha: (1 - t) * .6),
                      width: 2,
                    ),
                  ),
                ),
              Transform.scale(
                scale: t > 0 ? .9 + t * .1 : 1,
                child: _circulo(
                  lleno: t > .35,
                  color: Color.lerp(
                    NonaColors.surface,
                    NonaColors.accent,
                    t.clamp(0, 1),
                  )!,
                  check: t > .7,
                ),
              ),
            ],
          );
        },
      );
    }
    if (i < todayIndex && weekDone[i]) {
      return _circulo(
        lleno: true,
        color: NonaColors.accent.withValues(alpha: .85),
        check: true,
      );
    }
    return _circulo(
      lleno: false,
      color: i > todayIndex ? const Color(0xFF2B2B34) : const Color(0xFF232329),
    );
  }

  Widget _circulo({
    required bool lleno,
    required Color color,
    bool check = false,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lleno ? color : Colors.transparent,
        border: lleno ? null : Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: check
          ? Icon(Icons.check_rounded, size: 18, color: NonaColors.accentDeep)
          : null,
    );
  }
}

/// La llama: apagada —gris y pequeña— hasta que prende de golpe, con un
/// muelle que se pasa y vuelve.
class _Llama extends StatelessWidget {
  const _Llama({
    required this.prende,
    required this.tamano,
    this.viva = true,
    this.festoneada = false,
    this.gira,
  });

  final Animation<double> prende;
  final double tamano;

  /// Con false se queda apagada: la racha de un amigo que aún no ha jugado, o
  /// la tuya el día que no la alargaste.
  final bool viva;

  /// Con la forma festoneada de M3E detrás, que entra con la llama.
  final bool festoneada;

  /// Lo que la hace girar despacio mientras está la escena.
  final Animation<double>? gira;

  static const _gris = ColorFilter.matrix([
    .33, .33, .33, 0, 0, //
    .33, .33, .33, 0, 0, //
    .33, .33, .33, 0, 0, //
    0, 0, 0, .55, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([prende, ?gira]),
      builder: (context, _) {
        final t = viva ? prende.value : 0.0;
        final encendida = t > .02;
        final llama = Text(
          '🔥',
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: tamano, height: 1),
        );
        return SizedBox(
          width: tamano * (festoneada ? 1.7 : 1.1),
          height: tamano * (festoneada ? 1.5 : 1.1),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (festoneada && encendida)
                Transform.rotate(
                  angle: (gira?.value ?? 0) * math.pi / 3,
                  child: Transform.scale(
                    scale: t,
                    child: CustomPaint(
                      size: Size.square(tamano * 1.45),
                      painter: const _Festoneada(puntas: 12),
                    ),
                  ),
                ),
              Transform.scale(
                scale: .8 + .2 * t,
                child: encendida
                    ? llama
                    : ColorFiltered(colorFilter: _gris, child: llama),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// La forma «cookie» de M3 Expressive: un círculo festoneado de [puntas]
/// ondas suaves, una superficie de la app con el calor de la llama en el
/// centro. De naranja liso, sobre el fondo casi negro, quedaba una mancha
/// marrón.
class _Festoneada extends CustomPainter {
  const _Festoneada({required this.puntas});

  final int puntas;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    final camino = Path();
    const pasos = 240;
    for (var i = 0; i <= pasos; i++) {
      final a = i / pasos * 2 * math.pi;
      final r = radio * (.93 + .07 * math.cos(puntas * a));
      final p = centro + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        camino.moveTo(p.dx, p.dy);
      } else {
        camino.lineTo(p.dx, p.dy);
      }
    }
    final luz = RadialGradient(
      colors: [
        Color.alphaBlend(
          kColorDeRacha.withValues(alpha: .22),
          NonaColors.sheet,
        ),
        NonaColors.sheet,
      ],
      stops: const [.15, 1],
    ).createShader(Rect.fromCircle(center: centro, radius: radio));
    canvas.drawPath(camino..close(), Paint()..shader = luz);
  }

  @override
  bool shouldRepaint(_Festoneada old) => old.puntas != puntas;
}

/// El número que sube: el de ayer se va hacia arriba y entra el de hoy.
class _Contador extends StatelessWidget {
  const _Contador({
    required this.desde,
    required this.hasta,
    required this.sube,
    required this.tamano,
    this.color = kColorDeRacha,
  });

  final int desde;
  final int hasta;
  final Animation<double> sube;
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: tamano,
      fontWeight: FontWeight.w800,
      height: 1.05,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (desde == hasta) return Text('$hasta', style: estilo);
    return AnimatedBuilder(
      animation: sube,
      builder: (context, _) {
        // El muelle se pasa de 1: el número de hoy sube un poco de más y
        // vuelve. El de ayer se va sin rebote.
        final t = sube.value;
        // Asentado, solo el de hoy: el de ayer ya no pinta nada.
        if (t == 1.0) return Text('$hasta', style: estilo);
        final ida = t.clamp(0.0, 1.0);
        return ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Mide lo que el más ancho, para que nada baile al cambiar.
              Opacity(
                opacity: 0,
                child: Text('${math.max(desde, hasta)}', style: estilo),
              ),
              FractionalTranslation(
                translation: Offset(0, -ida),
                child: Opacity(
                  opacity: 1 - ida,
                  child: Text('$desde', style: estilo),
                ),
              ),
              FractionalTranslation(
                translation: Offset(0, 1 - t),
                child: Opacity(
                  opacity: ida,
                  child: Text('$hasta', style: estilo),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 3. El hito ─────────────────────────────────────────────────────────

/// La celebración de un hito de racha: el número, los rayos y una frase. La
/// escena de CINCO (`hito_escena.dart` allí).
class EscenaDeHito extends StatelessWidget {
  const EscenaDeHito({
    super.key,
    required this.controller,
    required this.numero,
    required this.color,
    required this.titulo,
    required this.rotulo,
  });

  final AnimationController controller;

  /// El número grande: los días de la racha.
  final int numero;
  final Color color;
  final String titulo;

  /// El rótulo en versalitas.
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(parent: controller, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(
      parent: controller,
      curve: const Interval(.4, 1, curve: Curves.easeOut),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _RayosDeHito(progress: controller, color: color),
              ScaleTransition(
                scale: pop,
                // Se encoge si no cabe: con la letra al máximo, la llama y el
                // número pasaban de los 150 pt.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 37)),
                      Text(
                        '$numero',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: NonaColors.text,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FadeTransition(
          opacity: fade,
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: NonaColors.text,
            ),
          ),
        ),
        const SizedBox(height: 6),
        FadeTransition(
          opacity: fade,
          child: Text(
            rotulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: NonaColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rayos radiales que giran despacio tras el número del hito.
class _RayosDeHito extends StatelessWidget {
  const _RayosDeHito({required this.progress, required this.color});

  final Animation<double> progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => Opacity(
        opacity: (progress.value * 1.4).clamp(0, .35),
        child: Transform.rotate(
          angle: progress.value * .4,
          child: CustomPaint(
            size: const Size(150, 150),
            painter: _Rayos(color),
          ),
        ),
      ),
    );
  }
}

class _Rayos extends CustomPainter {
  const _Rayos(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..color = color;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final path = Path()
        ..moveTo(
          center.dx + math.cos(angle - .06) * 40,
          center.dy + math.sin(angle - .06) * 40,
        )
        ..lineTo(
          center.dx + math.cos(angle) * 75,
          center.dy + math.sin(angle) * 75,
        )
        ..lineTo(
          center.dx + math.cos(angle + .06) * 40,
          center.dy + math.sin(angle + .06) * 40,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Rayos old) => old.color != color;
}

// ── 4. Las rachas de amigos ────────────────────────────────────────────

class _Amigos extends StatelessWidget {
  const _Amigos({
    required this.c,
    required this.amigos,
    required this.onRecordar,
  });

  final AnimationController c;
  final List<RachaEnLaEscena> amigos;
  final Future<void> Function(String pairId)? onRecordar;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Primero los que faltan: son los que piden algo.
    final orden = [...amigos]
      ..sort((a, b) {
        if (a.falta != b.falta) return a.falta ? -1 : 1;
        return b.n.compareTo(a.n);
      });
    final faltan = orden.where((a) => a.falta).toList();
    final subtitulo = switch (faltan.length) {
      0 => l.sceneFriendsAllPlayed,
      1 => l.sceneFriendsOneMissing(faltan.first.nombre),
      final k => l.sceneFriendsManyMissing(k),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _tramo(c, 0, .3),
          child: Column(
            children: [
              Text(
                l.sceneFriendsTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: NonaColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: NonaColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // La lista agrupada de M3E: una sola pieza, esquinas grandes por
        // fuera y pequeñas entre filas, con un respiro de 3 pt.
        for (var i = 0; i < orden.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          _FilaDeRacha(
            key: ValueKey(orden[i].pairId),
            amigo: orden[i],
            forma: BorderRadius.vertical(
              top: Radius.circular(i == 0 ? 24 : 6),
              bottom: Radius.circular(i == orden.length - 1 ? 24 : 6),
            ),
            entra: _tramo(c, .12 + i * .07, .5 + i * .07, Resorte.normal),
            sube: _tramo(c, .5 + i * .07, .75 + i * .07, Resorte.rapido),
            onRecordar: onRecordar,
          ),
        ],
      ],
    );
  }
}

class _FilaDeRacha extends StatelessWidget {
  const _FilaDeRacha({
    super.key,
    required this.amigo,
    required this.forma,
    required this.entra,
    required this.sube,
    required this.onRecordar,
  });

  final RachaEnLaEscena amigo;
  final BorderRadius forma;
  final Animation<double> entra;
  final Animation<double> sube;
  final Future<void> Function(String pairId)? onRecordar;

  @override
  Widget build(BuildContext context) {
    final viva = !amigo.falta;
    return FadeTransition(
      opacity: _Tope(entra),
      child: AnimatedBuilder(
        animation: entra,
        builder: (context, hijo) => Transform.translate(
          offset: Offset(0, 18 * (1 - entra.value)),
          child: hijo,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: NonaColors.sheet,
            borderRadius: forma,
          ),
          child: Row(
            children: [
              SendaAvatar(id: amigo.avatar, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amigo.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: NonaColors.text,
                      ),
                    ),
                    if (amigo.usuario.isNotEmpty)
                      Text(
                        '@${amigo.usuario}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NonaColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: viva ? 1 : .45,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Llama(prende: sube, tamano: 22, viva: viva),
                    const SizedBox(width: 2),
                    _Contador(
                      desde: amigo.subioHoy ? amigo.n - 1 : amigo.n,
                      hasta: amigo.n,
                      sube: sube,
                      tamano: 20,
                      color: viva ? kColorDeRacha : NonaColors.muted,
                    ),
                  ],
                ),
              ),
              if (amigo.falta) ...[
                const SizedBox(width: 10),
                _Recordar(amigo: amigo, onRecordar: onRecordar),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Una opacidad no puede pasar de 1, y un muelle sí.
class _Tope extends Animation<double> with AnimationWithParentMixin<double> {
  _Tope(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}

/// «Recordar»: el empujón de siempre, uno por amigo y día. Es un botón de
/// alternar de M3E: al tocarlo **cambia de forma y de color** —de píldora
/// naranja a tonal y más cuadrado, con su marca— y **no cambia de ancho**.
class _Recordar extends StatefulWidget {
  const _Recordar({required this.amigo, required this.onRecordar});

  final RachaEnLaEscena amigo;
  final Future<void> Function(String pairId)? onRecordar;

  static const ancho = 112.0;

  @override
  State<_Recordar> createState() => _RecordarState();
}

class _RecordarState extends State<_Recordar> {
  late bool _hecho = widget.amigo.recordado;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final recordar = widget.onRecordar;
    return SizedBox(
      width: _Recordar.ancho,
      height: 40,
      child: FilledButton(
        key: ValueKey('recordar-${widget.amigo.pairId}'),
        onPressed: _hecho || recordar == null
            ? null
            : () {
                Haptics.nudged();
                setState(() => _hecho = true);
                unawaited(recordar(widget.amigo.pairId));
              },
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10),
          ),
          animationDuration: const Duration(milliseconds: 220),
          backgroundColor: WidgetStatePropertyAll(
            _hecho ? kColorDeRacha.withValues(alpha: .16) : kColorDeRacha,
          ),
          shape: WidgetStateProperty.resolveWith(
            (s) => RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                _hecho || s.contains(WidgetState.pressed) ? 12 : 20,
              ),
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: _hecho
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: kColorDeRacha,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l.sceneReminded,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kColorDeRacha,
                      ),
                    ),
                  ],
                )
              : Text(
                  l.sceneRemind,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _tintaSobreRacha,
                  ),
                ),
        ),
      ),
    );
  }
}
