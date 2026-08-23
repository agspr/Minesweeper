/// Pantalla de resultado del día.
///
/// ## Quién es el protagonista
///
/// **La racha**, no los puntos. Es la decisión del dueño al reconciliar esta
/// pantalla con la de CINCO, y tiene detrás lo que hace volver al día
/// siguiente: los puntos son el resultado de HOY y la racha es lo que se puede
/// perder mañana. Antes esta pantalla abría con "+90" en grande y mandaba la
/// racha a una pastilla de 12,5 puntos al fondo.
///
/// Encima de la racha va la semana, de lunes a domingo, con los días ya
/// jugados marcados. Es del paquete a propósito: contesta "qué días he jugado",
/// no "cuántos llevo", y confundirlas es un fallo que la familia ya cometió una
/// vez (ver `SendaWeekStreak`).
///
/// ## Y por qué el desglose se queda
///
/// Base del día, lo que salió y lo que restaron los fallos. Lo pide el diseño
/// §4 ("mantenerlo legible") y hay una razón de producto detrás: la
/// penalización por fallos solo educa si el jugador ve de dónde sale. Un "+70"
/// a secas no enseña nada. CINCO no lo tiene y no pasa nada — nace de la
/// naturaleza del juego, que es de las cosas que el §PARIDAD deja diferir.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

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
    required this.onShare,
    required this.onPractice,
    required this.onMenu,
    required this.streak,
    required this.weekDone,
    required this.todayIndex,
  });

  final DailyScore score;
  final Duration elapsed;
  final VoidCallback onShare;

  /// Seguir jugando en el modo práctica. Es la salida de CINCO: quien acaba de
  /// terminar quiere seguir, y mandarlo al menú a buscar dónde es un paso de
  /// más.
  final VoidCallback onPractice;
  final VoidCallback onMenu;

  final int streak;
  final List<bool> weekDone;
  final int todayIndex;

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
              const SizedBox(height: 20),
              SendaWeekStreak(done: weekDone, todayIndex: todayIndex),
              const SizedBox(height: 18),
              // El protagonista.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: NonaColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                l.streakDays,
                style: const TextStyle(fontSize: 14, color: NonaColors.muted),
              ),
              const SizedBox(height: 20),
              // Los puntos bajan a una pastilla: siguen a la vista y siguen
              // teniendo su desglose debajo, pero ya no mandan.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: NonaColors.accentChip,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '+${score.points} ${l.points}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: NonaColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
              // Un día a medias da puntos pero NO racha (§1). Decirlo aquí evita
              // que alguien crea que el crédito parcial se la mantiene, ahora
              // que la racha es lo primero que se lee.
              if (!score.extendsStreak) ...[
                const SizedBox(height: 14),
                Text(
                  l.streakNeedsFinish,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: NonaColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _Boton(texto: l.share, onTap: onShare, principal: false),
              const SizedBox(height: 10),
              _Boton(
                texto: l.keepPlayingPractice,
                onTap: onPractice,
                principal: true,
              ),
              const SizedBox(height: 10),
              _Boton(texto: l.closeGame, onTap: onMenu, principal: true),
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

/// Los tres botones del fondo, con la forma de CINCO: mismo alto, mismo radio
/// total, apilados y a todo el ancho. Compartir va en secundario porque no es
/// lo que se hace al terminar; las dos salidas van en el color del tema.
class _Boton extends StatelessWidget {
  const _Boton({
    required this.texto,
    required this.onTap,
    required this.principal,
  });

  final String texto;
  final VoidCallback onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: FilledButton(
      onPressed: () {
        NonaHaptics.tap();
        onTap();
      },
      style: FilledButton.styleFrom(
        backgroundColor: principal ? NonaColors.accent : NonaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
          color: principal ? NonaColors.accentDeep : NonaColors.text,
        ),
      ),
    ),
  );
}
