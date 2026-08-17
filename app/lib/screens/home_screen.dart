/// Menú: la diaria y el modo libre.
///
/// La diaria va primero y ocupa más: es el juego. El modo libre está debajo, a
/// mano para quien ya hizo la de hoy o quiere practicar sin que cuente.
library;

import 'package:flutter/material.dart';

import '../game/daily_controller.dart';
import '../game/practice_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_controller.dart';
import '../services/progress_controller.dart';
import '../theme.dart';
import '../widgets/result_overlay.dart' show difficultyLabel;
import 'game_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.daily,
    required this.practice,
    required this.locale,
    required this.progress,
  });

  final DailyController daily;
  final PracticeController practice;
  final LocaleController locale;
  final ProgressController progress;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _View { menu, daily, practice }

class _HomeScreenState extends State<HomeScreen> {
  _View _view = _View.menu;

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _View.daily => GameScreen(
        controller: widget.daily,
        progress: widget.progress,
      ),
      _View.practice => PracticeScreen(
        controller: widget.practice,
        onExit: () => setState(() => _view = _View.menu),
      ),
      _View.menu => _Menu(
        daily: widget.daily,
        locale: widget.locale,
        progress: widget.progress,
        onDaily: () => setState(() => _view = _View.daily),
        onPractice: () {
          // Se carga al entrar, no al arrancar la app: generar un puzle en el
          // arranque en frío retrasaría la diaria, que es a lo que viene la
          // gente.
          if (widget.practice.board == null) widget.practice.load();
          setState(() => _view = _View.practice);
        },
      ),
    };
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.daily,
    required this.locale,
    required this.progress,
    required this.onDaily,
    required this.onPractice,
  });

  final DailyController daily;
  final LocaleController locale;
  final ProgressController progress;
  final VoidCallback onDaily;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListenableBuilder(
              listenable: daily,
              builder: (context, _) {
                final done = daily.isComplete;
                final l = L.of(context);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 40, 22, 24),
                  children: [
                    Text(
                      l.appName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: NonaColors.accent,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.appTagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: NonaColors.muted,
                      ),
                    ),
                    const SizedBox(height: 44),
                    _Card(
                      title: l.menuDaily,
                      subtitle: daily.difficulty == null
                          ? l.menuLoading
                          : done
                          ? l.menuDailyDone(
                              difficultyLabel(context, daily.difficulty!),
                            )
                          : l.menuDailyToday(
                              difficultyLabel(context, daily.difficulty!),
                            ),
                      icon: done
                          ? Icons.check_circle_rounded
                          : Icons.today_rounded,
                      primary: true,
                      onTap: onDaily,
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      title: l.menuPractice,
                      subtitle: l.menuPracticeSubtitle,
                      icon: Icons.all_inclusive_rounded,
                      onTap: onPractice,
                    ),
                    const SizedBox(height: 26),
                    _Stats(progress: progress, l: l),
                    const SizedBox(height: 22),
                    // Un ciclo sistema → ES → EN y no un desplegable: con dos
                    // idiomas, un menú sería más ceremonia de la que merece.
                    // Mucha gente tiene el teléfono en un idioma y prefiere
                    // jugar en otro, así que seguir solo al sistema no basta.
                    Center(
                      child: GestureDetector(
                        onTap: locale.cycle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: NonaColors.surface,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.language_rounded,
                                size: 15,
                                color: NonaColors.muted,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                locale.labelFor(l.languageSystem),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: NonaColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: primary ? NonaColors.accentChip : NonaColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: primary
              ? Border.all(color: NonaColors.accent.withValues(alpha: 0.35))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: primary ? NonaColors.accent : NonaColors.muted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: primary ? NonaColors.accent : NonaColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: NonaColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: NonaColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Franja de números personales. Vive en el menú y no en una pantalla aparte
/// porque son cuatro cifras: esconderlas detrás de otro toque sería fingir que
/// hay más de lo que hay.
class _Stats extends StatelessWidget {
  const _Stats({required this.progress, required this.l});

  final ProgressController progress;
  final L l;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        if (progress.daysPlayed == 0) {
          return Text(
            l.statsNone,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: NonaColors.muted),
          );
        }
        final avg = progress.averageMistakes;
        return Column(
          children: [
            Row(
              children: [
                _Stat(
                  // La racha VIGENTE, no el contador guardado: si el último día
                  // terminado no es ni hoy ni ayer, ya está rota y hay que
                  // enseñarla rota.
                  value: '${progress.streakAsOf(DateTime.now())}',
                  label: l.statsStreak,
                ),
                _Stat(
                  value: '${progress.bestStreak}',
                  label: l.statsBestStreak,
                ),
                _Stat(
                  value: '${progress.totalPoints}',
                  label: l.statsTotalPoints,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  value: '${progress.daysCompleted}',
                  label: l.statsDaysCompleted,
                ),
                _Stat(
                  value: '${progress.daysPlayed}',
                  label: l.statsDaysPlayed,
                ),
                _Stat(
                  value: avg == null ? '—' : avg.toStringAsFixed(1),
                  label: l.statsAvgMistakes,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                color: NonaColors.text,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: NonaColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
