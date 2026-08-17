/// Menú: la diaria y el modo libre.
///
/// La diaria va primero y ocupa más: es el juego. El modo libre está debajo, a
/// mano para quien ya hizo la de hoy o quiere practicar sin que cuente.
library;

import 'package:flutter/material.dart';

import '../game/daily_controller.dart';
import '../game/practice_controller.dart';
import '../theme.dart';
import '../widgets/result_overlay.dart' show difficultyLabel;
import 'game_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.daily, required this.practice});

  final DailyController daily;
  final PracticeController practice;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _View { menu, daily, practice }

class _HomeScreenState extends State<HomeScreen> {
  _View _view = _View.menu;

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _View.daily => GameScreen(controller: widget.daily),
      _View.practice => PracticeScreen(
        controller: widget.practice,
        onExit: () => setState(() => _view = _View.menu),
      ),
      _View.menu => _Menu(
        daily: widget.daily,
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
    required this.onDaily,
    required this.onPractice,
  });

  final DailyController daily;
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
                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 40, 22, 24),
                  children: [
                    const Text(
                      'Nona',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: NonaColors.accent,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sudoku del día',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: NonaColors.muted),
                    ),
                    const SizedBox(height: 44),
                    _Card(
                      title: 'La diaria',
                      subtitle: daily.difficulty == null
                          ? 'Cargando…'
                          : done
                          ? 'Hecha · ${difficultyLabel(daily.difficulty!)}'
                          : '${difficultyLabel(daily.difficulty!)} · hoy',
                      icon: done
                          ? Icons.check_circle_rounded
                          : Icons.today_rounded,
                      primary: true,
                      onTap: onDaily,
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      title: 'Modo libre',
                      subtitle: 'Puzles infinitos · no puntúa',
                      icon: Icons.all_inclusive_rounded,
                      onTap: onPractice,
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
