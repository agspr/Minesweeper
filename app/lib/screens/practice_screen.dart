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

import 'package:flutter/material.dart';

import '../game/difficulty.dart';
import '../game/practice_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/haptics.dart';
import '../services/theme_controller.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/numpad.dart';
import '../widgets/puzzle_layout.dart';
import '../widgets/difficulty_label.dart';
import '../widgets/sudoku_board_view.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.controller,
    required this.theme,
    required this.onExit,
  });

  final PracticeController controller;

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

  @override
  Widget build(BuildContext context) {
    if (_choosing) {
      return _DifficultyScreen(
        current: widget.controller.difficulty,
        onExit: widget.onExit,
        onPick: (d) {
          // No se espera a que termine: `setDifficulty` corta en seco si el
          // nivel no cambia, y si cambia, el tablero enseña su propio
          // indicador de "generando" en la pantalla siguiente.
          widget.controller.setDifficulty(d);
          setState(() => _choosing = false);
        },
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
              header: GameHeader(
                title: l.menuPractice,
                onClose: widget.onExit,
                // Las pistas solo cuando las hay: aquí no se puntúa, así que un
                // "0 pistas" permanente sería un reproche por adelantado.
                trailing: c.hintsUsed > 0
                    ? HeaderChip(
                        icon: Icons.lightbulb_outline_rounded,
                        count: c.hintsUsed,
                        semanticsLabel: l.hintCount(c.hintsUsed),
                      )
                    : null,
              ),
              board: c.generating || c.board == null
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : SudokuBoardView(
                      board: c.board!,
                      selected: c.selected,
                      onTapCell: c.select,
                    ),
              // El modo libre mete su barra de acciones entre el tablero y el
              // numpad. Van juntos en la misma ranura: en tablet apaisada bajan
              // los dos a la columna de la derecha, que es donde deben estar
              // los controles.
              numpad: c.board == null || c.generating
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.isComplete)
                          _SolvedActions(
                            onKeepPlaying: c.newPuzzle,
                            onExit: widget.onExit,
                          )
                        else
                          _HintBar(onHint: c.hint),
                        const SizedBox(height: 10),
                        Numpad(
                          board: c.board!,
                          notesMode: c.notesMode,
                          enabled: !c.isComplete,
                          onDigit: c.tapDigit,
                          onErase: c.erase,
                          onToggleNotes: c.toggleNotesMode,
                          onUndo: c.undo,
                          boardColourOn: widget.theme.boardColour,
                          onToggleBoardColour: widget.theme.toggleBoardColour,
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Elegir nivel, antes de ver ningún tablero.
class _DifficultyScreen extends StatelessWidget {
  const _DifficultyScreen({
    required this.current,
    required this.onPick,
    required this.onExit,
  });

  final Difficulty current;
  final ValueChanged<Difficulty> onPick;
  final VoidCallback onExit;

  /// Qué cambia en cada nivel. Sin esto, "Fácil/Medio/Difícil" no dice QUÉ se
  /// pone difícil — y en un sudoku no es evidente: son las pistas que trae y
  /// las técnicas que exige, no el tamaño ni el tiempo.
  String _description(L l, Difficulty d) => switch (d) {
    Difficulty.easy => l.difficultyEasyDesc,
    Difficulty.medium => l.difficultyMediumDesc,
    Difficulty.hard => l.difficultyHardDesc,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
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
                        const SizedBox(height: 20),
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
                    ),
                  ),
                ),
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

/// Mientras se juega: solo la pista.
class _HintBar extends StatelessWidget {
  const _HintBar({required this.onHint});

  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return _Bar(
      icon: Icons.lightbulb_outline_rounded,
      label: L.of(context).hint,
      onTap: onHint,
    );
  }
}

/// Al terminar: seguir jugando o volver al menú, del mismo tamaño.
class _SolvedActions extends StatelessWidget {
  const _SolvedActions({required this.onKeepPlaying, required this.onExit});

  final VoidCallback onKeepPlaying;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.solved,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: NonaColors.accent,
          ),
        ),
        const SizedBox(height: 10),
        // Las dos ocupan lo mismo: seguir y salir son opciones legítimas, no
        // una principal y una secundaria.
        _Bar(
          icon: Icons.refresh_rounded,
          label: l.keepPlaying,
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
