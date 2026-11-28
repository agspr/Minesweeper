/// Modo libre: elegir nivel, jugar, pedir pista, seguir o salir.
///
/// Sin reloj y sin contador de fallos, a propósito. No puntúa (§1), así que
/// enseñar fallos aquí sería regañar por nada; el rojo de la casilla ya avisa
/// de que ese número no va.
///
/// ## El nivel se elige ANTES, en su propia pantalla
///
/// Llevaba tres pastillas metidas en la cabecera, encima del tablero. El nivel
/// no es un ajuste que deba estorbar mientras juegas: es una decisión que se
/// toma al entrar, una vez, y después no se vuelve a mirar. En la cabecera
/// ocupaba sitio permanente para algo que se usa una vez por partida, y encima
/// invitaba a tocarlo sin querer con el pulgar apoyado.
///
/// Elegir el MISMO nivel que ya estaba no reinicia nada —`setDifficulty` corta
/// en seco si no cambia—, así que entrar, elegir igual y seguir con el puzle a
/// medias funciona. Es la misma pantalla y la misma promesa que en CINCO.
///
/// ## Al terminar: seguir o salir, del mismo tamaño
///
/// Antes había un "Otro puzle" siempre visible, también mientras jugabas. Uno
/// de los dos sobra: pedir otro puzle a mitad de uno es una salida de
/// emergencia, no una acción de cada día, y ocupaba la mitad de la barra. Ahora
/// las dos salidas —seguir jugando y volver al menú— aparecen SOLO al
/// terminar, y ocupan lo mismo: las dos son legítimas, no hay una principal.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart' show AdManager;

import '../game/difficulty.dart';
import '../game/practice_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/haptics.dart';
import '../services/theme_controller.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/puzzle_layout.dart';
import '../widgets/aviso_flotante.dart';
import '../widgets/difficulty_label.dart';
import '../widgets/sudoku_board_view.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.controller,
    required this.theme,
    required this.onExit,
    this.ads,
    this.clock = DateTime.now,
  });

  /// Tiempo mínimo de respiro desde que se cierra un anuncio a pantalla
  /// completa hasta que puede mostrarse el siguiente.
  static const Duration adCooldown = Duration(seconds: 15);

  static final Expando<DateTime> _lastAdDismissedAt = Expando<DateTime>(
    'lastAdDismissedAt',
  );

  /// Registra el instante en que el jugador cerró un anuncio intersticial.
  static void recordAdDismissed(AdManager ads, DateTime dismissedAt) {
    _lastAdDismissedAt[ads] = dismissedAt;
  }

  /// Devuelve `true` si ya pasó al menos [adCooldown] desde que se cerró el
  /// último anuncio en [ads].
  static bool canShowAd(AdManager ads, DateTime now) {
    final last = _lastAdDismissedAt[ads];
    if (last == null) return true;
    return now.difference(last) >= adCooldown;
  }

  final PracticeController controller;

  /// Los anuncios a pantalla completa: uno cada cuatro partidas terminadas, en
  /// la pausa entre una y otra. Null en las pruebas que no los miran.
  final AdManager? ads;

  /// Reloj inyectable para medir el enfriamiento entre anuncios en las pruebas.
  final DateTime Function() clock;

  /// Para la tecla de color del numpad.
  final ThemeController theme;

  /// Volver al menú. Obligatorio: con la barra inferior escondida mientras se
  /// juega, una pantalla de juego sin salida no tendría forma de abandonarse.
  final VoidCallback onExit;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  /// Al entrar SIEMPRE se elige nivel primero; el tablero viene después.
  bool _choosing = true;

  /// El tablero de delante ya se apuntó como partida terminada.
  bool _apuntada = false;
  Timer? _precarga;
  Timer? _anuncioTimer;
  bool _touchingCovered = false;

  MinesweeperFaceState _faceState(PracticeController c) {
    if (c.isComplete) return MinesweeperFaceState.won;
    if (c.isLost) return MinesweeperFaceState.lost;
    if (_touchingCovered) return MinesweeperFaceState.surprised;
    return MinesweeperFaceState.normal;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_alCambiar);
    _precarga = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        unawaited(widget.ads?.preloadPractice());
      }
    });
  }

  @override
  void dispose() {
    _precarga?.cancel();
    _anuncioTimer?.cancel();
    widget.controller.removeListener(_alCambiar);
    super.dispose();
  }

  /// Cada partida terminada se apunta UNA vez y muestra el anuncio de inmediato
  /// al terminar (ganar o perder), respetando el enfriamiento mínimo de 15 s.
  void _alCambiar() {
    final terminada = widget.controller.isFinished;
    if (terminada && !_apuntada) {
      _apuntada = true;
      final ads = widget.ads;
      if (ads != null) {
        unawaited(ads.anotarPartida());
        unawaited(_asegurarTocaCadaPartida(ads));
        _anuncioTimer?.cancel();
        _anuncioTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            unawaited(_mostrarAnuncioAlTerminar(ads));
          }
        });
      }
    } else if (!terminada) {
      _apuntada = false;
      _anuncioTimer?.cancel();
    }
  }

  Future<void> _mostrarAnuncioAlTerminar(AdManager ads) async {
    if (!mounted || !widget.controller.isFinished) return;
    if (!PracticeScreen.canShowAd(ads, widget.clock())) {
      await ads.partidas.reiniciar();
      return;
    }
    final mostro = await ads.mostrarSiToca();
    if (mostro) {
      PracticeScreen.recordAdDismissed(ads, widget.clock());
    }
  }

  Future<void> _asegurarTocaCadaPartida(AdManager ads) async {
    for (var i = 0; i < ads.partidas.cada && !ads.partidas.toca; i++) {
      await ads.partidas.anotar();
    }
  }

  /// La pausa entre una partida y la siguiente: si el anuncio no se pudo
  /// mostrar al terminar (por ejemplo, si tardó en cargar), se intenta aquí.
  Future<void> _siguiente() async {
    final ads = widget.ads;
    if (ads != null && ads.tocaEnLaPausa) {
      if (PracticeScreen.canShowAd(ads, widget.clock())) {
        final mostro = await ads.mostrarSiToca();
        if (mostro) {
          PracticeScreen.recordAdDismissed(ads, widget.clock());
        }
      } else {
        await ads.partidas.reiniciar();
      }
    }
    if (mounted) await widget.controller.newPuzzle();
  }

  @override
  Widget build(BuildContext context) {
    if (_choosing) {
      return ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _DifficultyScreen(
          current: widget.controller.difficulty,
          gameMode: widget.controller.gameMode,
          onPickMode: (m) => widget.controller.setGameMode(m),
          onExit: widget.onExit,
          onPick: (d) {
            // No se espera a que termine: `setDifficulty` corta en seco si el
            // nivel no cambia, y si cambia, el tablero enseña su propio
            // indicador de "generando" en la pantalla siguiente.
            widget.controller.setDifficulty(d);
            setState(() => _choosing = false);
          },
        ),
      );
    }

    return Scaffold(
      // Ver la nota de `game_screen.dart`: el hueco de abajo lo pone el armazón.
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            final l = L.of(context);
            return PuzzleLayout(
              // Dos avisos en el mismo hueco: nunca coinciden, porque antes de
              // abrir la salida no hay ningún número puesto que sobrescribir.
              aviso: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AvisoFlotante(
                    disparo: c.intentosDeSobrescribir,
                    texto: l.eraseFirst,
                    icono: Icons.backspace_outlined,
                    ocultarCon: c,
                  ),
                  AvisoFlotante(
                    disparo: c.avisosDeSalida,
                    texto: l.startOnMarkedCell,
                    icono: Icons.adjust_rounded,
                    ocultarCon: c,
                  ),
                ],
              ),
              header: GameHeader(
                title: l.menuPractice,
                onClose: widget.onExit,
                remainingMines: c.generating || c.board == null
                    ? null
                    : c.board!.remainingMines,
                faceState: _faceState(c),
                onReset: () => c.newPuzzle(),
                isRunning: c.isRunning,
                elapsedSeconds: c.elapsed.inSeconds,
                trailing: c.board == null || c.gameMode == PracticeGameMode.classic
                    ? null
                    : MinesweeperStrikesChip(
                        strikes: c.board!.detonatedCount,
                        maxStrikes: c.board!.maxStrikes,
                        semanticsLabel: c.board!.detonatedCount == 0
                            ? l.noMistakes
                            : l.mistakeCount(c.board!.detonatedCount) +
                                (c.board!.isLost ? ' (derrota)' : ''),
                      ),
              ),
              board: c.generating || c.board == null
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : SudokuBoardView(
                      board: c.board!,
                      selected: c.selected,
                      onTapCell: c.tapCellOnBoard,
                      onLongPressCell: c.longPressCellOnBoard,
                      onPointerDownCovered: () =>
                          setState(() => _touchingCovered = true),
                      onPointerUpCovered: () =>
                          setState(() => _touchingCovered = false),
                    ),
              numpad: c.isFinished
                  ? _SolvedActions(
                      isWon: c.isComplete,
                      onKeepPlaying: _siguiente,
                      onExit: widget.onExit,
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}

/// Elegir nivel y modo de juego, antes de ver ningún tablero.
class _DifficultyScreen extends StatelessWidget {
  const _DifficultyScreen({
    required this.current,
    required this.gameMode,
    required this.onPickMode,
    required this.onPick,
    required this.onExit,
  });

  final Difficulty current;
  final PracticeGameMode gameMode;
  final ValueChanged<PracticeGameMode> onPickMode;
  final ValueChanged<Difficulty> onPick;
  final VoidCallback onExit;

  String _description(L l, Difficulty d) => switch (d) {
    Difficulty.easy => l.difficultyEasyDesc,
    Difficulty.medium => l.difficultyMediumDesc,
    Difficulty.hard => l.difficultyHardDesc,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final isSenda = gameMode == PracticeGameMode.senda;

    final modeToggle = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2C2C3C),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                NonaHaptics.select();
                onPickMode(PracticeGameMode.senda);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSenda ? NonaColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  l.practiceModeSenda,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSenda ? NonaColors.accentDeep : NonaColors.muted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                NonaHaptics.select();
                onPickMode(PracticeGameMode.classic);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isSenda ? NonaColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  l.practiceModeClassic,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: !isSenda ? NonaColors.accentDeep : NonaColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final difficultyCards = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in Difficulty.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DifficultyCard(
              label: difficultyLabel(context, d),
              description: _description(l, d),
              selected: d == current,
              onTap: () => onPick(d),
            ),
          ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () {
                  NonaHaptics.tap();
                  onExit();
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: NonaColors.muted,
                ),
                tooltip: l.closeGame,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final isWide =
                      c.maxWidth >= 640 && c.maxWidth > c.maxHeight * 1.08;
                  if (isWide) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 10,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      l.practiceDifficultyTitle,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: NonaColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l.practiceDifficultySubtitle,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        height: 1.4,
                                        color: NonaColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    modeToggle,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 36),
                              Expanded(
                                flex: 11,
                                child: difficultyCards,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final maxWidth = c.maxWidth >= 540 ? 560.0 : 520.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.practiceDifficultyTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 23,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: NonaColors.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.practiceDifficultySubtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: NonaColors.muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            modeToggle,
                            const SizedBox(height: 16),
                            difficultyCards,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de nivel: ancho completo y apilada, como las del menú.
class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTapDown: (_) => NonaHaptics.tap(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: NonaColors.surface,
            borderRadius: BorderRadius.circular(18),
            // El nivel activo se marca con borde de acento, igual que la
            // tarjeta destacada del menú. Borde y color del texto: dos
            // canales, que el acento lo elige quien juega.
            border: Border.all(
              color: selected ? NonaColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: selected ? NonaColors.accent : NonaColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: NonaColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: selected ? NonaColors.accent : NonaColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Al terminar: seguir jugando o volver al menú, del mismo tamaño.
class _SolvedActions extends StatelessWidget {
  const _SolvedActions({
    required this.isWon,
    required this.onKeepPlaying,
    required this.onExit,
  });

  final bool isWon;
  final VoidCallback onKeepPlaying;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title = isWon
        ? l.solved
        : (l.localeName == 'es' ? 'Mina detonada' : 'Mine detonated');
    final color = isWon ? NonaColors.accent : const Color(0xFFFF5252);
    final keepPlayingLabel = isWon
        ? l.keepPlaying
        : (l.localeName == 'es' ? 'Reintentar' : 'Try again');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        // Las dos ocupan lo mismo: seguir y salir son opciones legítimas, no
        // una principal y una secundaria.
        _Bar(
          icon: Icons.refresh_rounded,
          label: keepPlayingLabel,
          onTap: onKeepPlaying,
          filled: true,
        ),
        const SizedBox(height: 8),
        _Bar(icon: Icons.home_rounded, label: l.closeGame, onTap: onExit),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? NonaColors.accentDeep : NonaColors.keyFg;
    return GestureDetector(
      onTapDown: (_) => NonaHaptics.tap(),
      onTap: onTap,
      child: Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: filled ? NonaColors.accent : NonaColors.keyBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
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
