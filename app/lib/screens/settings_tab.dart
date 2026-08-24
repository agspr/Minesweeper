/// La pestaña Más de Nona: la pantalla compartida, rellena con lo de Nona.
///
/// Aquí se ve el reparto funcionando: la forma —orden de secciones, tarjetas,
/// espacios— la pone el paquete y es idéntica a la de CINCO; el contenido lo
/// pone Nona. CINCO cuenta partidas ganadas y promedio de intentos; Nona
/// cuenta rachas, terminados y fallos por día. La página se siente la misma.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../nona_config.dart';
import '../theme.dart';
import '../services/progress_controller.dart';
import '../services/theme_controller.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.auth,
    required this.friends,
    required this.purchases,
    required this.notifications,
    required this.prefs,
    required this.locale,
    required this.theme,
    required this.progress,
  });

  final AuthController auth;
  final FriendsService friends;
  final PurchaseService purchases;
  final NotificationsService notifications;

  /// Para poder LIMPIAR lo que Nona guarda al salirse de la cuenta.
  final SharedPreferences prefs;
  final LocaleController locale;
  final ThemeController theme;
  final ProgressController progress;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // Se crea aquí y no en `main`: sale entero de `auth` más el gameId, y su
  // vida es la de esta pestaña. Pasarlo por main → NonaApp → HomeScreen serían
  // tres ficheros tocados para no ganar nada.
  late final SendaAccountDeletion _deletion = SendaAccountDeletion(
    auth: widget.auth,
    gameId: nonaGameId,
    // Sin esto, borrar Nona de la cuenta se deshace solo: el servidor borra, el
    // teléfono conserva la racha y los puntos, y el sincronizador los vuelve a
    // subir en cuanto se termine un puzle. El servidor no puede impedirlo.
    session: SessionSync(
      widget.prefs,
      ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
    ),
  );

  @override
  void dispose() {
    _deletion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = widget.progress;
    final avg = progress.averageMistakes;

    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => SendaSettingsScreen(
        config: nonaConfig,
        auth: widget.auth,
        friends: widget.friends,
        purchases: widget.purchases,
        locale: widget.locale,
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
        selectedTheme: widget.theme.palette.name,
        // El fallback no debería usarse nunca —el nombre sale de la propia
        // lista— pero obligarlo es lo que hizo aparecer esta línea al cambiar
        // la API: antes caía en Menta en silencio.
        onPickTheme: (option) => widget.theme.select(
          SendaPalettes.byName(
            option.name,
            fallback: NonaColors.defaultPalette,
          ),
        ),
        // La lista de bloqueados no se enseña por ahora. El FILTRO sigue
        // vivo: quien busca por @usuario no encuentra a quien bloqueó, porque
        // la pantalla de Amigos carga la lista por su cuenta.
        notifications: widget.notifications,
        showBlocked: false,
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
        // La fila de borrar cuenta la pinta el paquete al recibir esto, y
        // lleva a su pantalla. Obligatoria para publicar (Apple 5.1.1(v)).
        deletion: _deletion,
      ),
    );
  }
}
