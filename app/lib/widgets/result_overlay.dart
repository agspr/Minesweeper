/// Pantalla de resultado del día.
///
/// Muestra el **desglose**, no solo el número: base del día, lo que salió y lo
/// que restaron los fallos. Lo pide el diseño §4 ("mantenerlo legible") y hay
/// una razón de producto detrás: la penalización por fallos solo educa si el
/// jugador ve de dónde sale. Un "+70" a secas no enseña nada.
library;

import 'package:flutter/material.dart';

import '../game/difficulty.dart';
import '../l10n/app_localizations.dart';
import '../game/scoring.dart';
import '../services/haptics.dart';
import '../theme.dart';

class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.score,
    required this.elapsed,
    required this.onClose,
    required this.onShare,
  });

  final DailyScore score;
  final Duration elapsed;
  final VoidCallback onClose;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final difficulty = switch (score.base) {
      50 => l.difficultyEasy,
      100 => l.difficultyMedium,
      _ => l.difficultyHard,
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: NonaColors.sheet,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.completed ? l.solved : l.unfinished,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: NonaColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$difficulty · ${_clock(elapsed)}',
                style: const TextStyle(fontSize: 13, color: NonaColors.muted),
              ),
              const SizedBox(height: 22),
              Text(
                '+${score.points}',
                style: TextStyle(
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: NonaColors.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.points,
                style: const TextStyle(fontSize: 13, color: NonaColors.muted),
              ),
              const SizedBox(height: 22),
              // El desglose. Suma exactamente lo de arriba, a la vista.
              _Line(label: l.breakdownBase, value: '${score.base}'),
              if (score.completed) ...[
                if (score.countedMistakes > 0)
                  _Line(
                    label:
                        l.mistakeCount(score.countedMistakes) +
                        (score.countedMistakes == 5 ? l.mistakeCapSuffix : ''),
                    value: '−${score.mistakePenalty}',
                    negative: true,
                  )
                else
                  _Line(label: l.breakdownNoMistakes, value: '−0'),
              ] else
                _Line(
                  label: l.breakdownCompleted(score.completionPercent),
                  value: '×${(score.partialFraction ?? 0) * 100 ~/ 1}%',
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: NonaColors.surface),
              ),
              _Line(
                label: l.breakdownTotal,
                value: '${score.points}',
                strong: true,
              ),
              const SizedBox(height: 18),
              // La racha solo la da terminar (§1); decirlo aquí evita que
              // alguien crea que el crédito parcial se la mantiene.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: score.extendsStreak
                      ? NonaColors.accentChip
                      : NonaColors.surface,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  score.extendsStreak ? l.streakKept : l.streakNeedsFinish,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: score.extendsStreak
                        ? NonaColors.accent
                        : NonaColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {
                    NonaHaptics.tap();
                    onShare();
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 17),
                  label: Text(
                    l.share,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NonaColors.text,
                    side: const BorderSide(color: NonaColors.surface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    NonaHaptics.tap();
                    onClose();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: NonaColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    l.done,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: NonaColors.accentDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.negative = false,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool negative;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              color: strong ? NonaColors.text : NonaColors.muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: negative
                  ? NonaColors.wrong
                  : strong
                  ? NonaColors.accent
                  : NonaColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

String _clock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Etiqueta de dificultad, traducida. Vive aquí porque la usan varias
/// pantallas y no merece un fichero propio.
String difficultyLabel(BuildContext context, Difficulty d) {
  final l = L.of(context);
  return switch (d) {
    Difficulty.easy => l.difficultyEasy,
    Difficulty.medium => l.difficultyMedium,
    Difficulty.hard => l.difficultyHard,
  };
}
