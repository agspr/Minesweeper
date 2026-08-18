/// La pestaña Más de Nona: la pantalla compartida, rellena con lo de Nona.
///
/// Aquí se ve el reparto funcionando: la forma —orden de secciones, tarjetas,
/// espacios— la pone el paquete y es idéntica a la de CINCO; el contenido lo
/// pone Nona. CINCO cuenta partidas ganadas y promedio de intentos; Nona
/// cuenta rachas, terminados y fallos por día. La página se siente la misma.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../l10n/app_localizations.dart';
import '../nona_config.dart';
import '../services/progress_controller.dart';
import '../services/theme_controller.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    required this.auth,
    required this.friends,
    required this.purchases,
    required this.locale,
    required this.theme,
    required this.progress,
  });

  final AuthController auth;
  final FriendsService friends;
  final PurchaseService purchases;
  final LocaleController locale;
  final ThemeController theme;
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final avg = progress.averageMistakes;

    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => SendaSettingsScreen(
        config: nonaConfig,
        auth: auth,
        friends: friends,
        purchases: purchases,
        locale: locale,
        title: l.more,
        statRows: [
          SendaStatRow(
            tiles: [
              SendaStatTile(
                emoji: '🔥',
                // La racha VIGENTE, no el contador guardado: si el último día
                // terminado no es ni hoy ni ayer ya está rota, y hay que
                // enseñarla rota.
                value: '${progress.streakAsOf(DateTime.now())}',
                label: l.statsStreak,
              ),
              SendaStatTile(
                emoji: '🏆',
                value: '${progress.bestStreak}',
                label: l.statsBestStreak,
              ),
              SendaStatTile(
                emoji: '⭐',
                value: '${progress.totalPoints}',
                label: l.statsTotalPoints,
              ),
            ],
          ),
          SendaStatRow(
            tiles: [
              SendaStatTile(
                emoji: '🎯',
                value: '${progress.daysPlayed}',
                label: l.statsDaysPlayed,
              ),
              SendaStatTile(
                emoji: '✅',
                value: '${progress.daysCompleted}',
                label: l.statsDaysCompleted,
              ),
              SendaStatTile(
                emoji: '❌',
                value: avg == null ? '—' : avg.toStringAsFixed(1),
                label: l.statsAvgMistakes,
              ),
            ],
          ),
        ],
        // Los CUATRO de la familia, los mismos que CINCO y en el mismo orden.
        // No son "los temas de Nona": son los de Juegos Senda, y por eso los
        // define el paquete. Que las dos apps ofrezcan lo mismo aquí es el
        // motivo de que esta pantalla se sienta la misma en las dos.
        themes: [
          for (final p in SendaPalettes.all)
            SendaThemeOption(
              name: p.name,
              brand: p.brand,
              swatches: p.swatches,
            ),
        ],
        selectedTheme: theme.palette.name,
        onPickTheme: (option) =>
            theme.select(SendaPalettes.byName(option.name)),
        aboutTitle: l.aboutNona,
        aboutSubtitle: l.aboutSubtitle,
        onAbout: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SendaAboutScreen(
              config: nonaConfig,
              aboutTitle: l.aboutNona,
              aboutBody: l.aboutBody,
              website: Uri.parse('https://sendapr.com'),
              contactEmail: 'support@sendapr.com',
              footer: 'SENDA LLC · Hecho en Puerto Rico',
            ),
          ),
        ),
        // onDeleteAccount va nulo a propósito: el borrado de cuenta es de la
        // fase B y sus textos dependen de la republicación de las políticas.
        // Es OBLIGATORIO antes de publicar (Apple 5.1.1(v)).
      ),
    );
  }
}
