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
import '../otros_juegos.dart';
import '../theme.dart';
import '../game/difficulty.dart';
import '../game/practice_controller.dart';
import '../services/progress_controller.dart';
import '../widgets/difficulty_label.dart';
import '../services/theme_controller.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.practice,
    required this.auth,
    required this.friends,
    required this.purchases,
    required this.notifications,
    required this.prefs,
    required this.locale,
    required this.theme,
    required this.progress,
    this.consent,
    this.resenas,
  });

  final PracticeController practice;
  final AuthController auth;
  final FriendsService friends;
  final PurchaseService purchases;
  final NotificationsService notifications;

  /// Para poder LIMPIAR lo que Nona guarda al salirse de la cuenta.
  final SharedPreferences prefs;
  final LocaleController locale;
  final ThemeController theme;
  final ProgressController progress;

  /// «Privacidad de los anuncios»: la fila sale solo donde Google dice que
  /// hace falta. Null en las pruebas.
  final ConsentManager? consent;

  /// «Califica Nona». Null en las pruebas.
  final SendaResenas? resenas;

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
  void initState() {
    super.initState();
    // Para saber si hay a quién desbloquear: la sección «Bloqueados» sale solo
    // si la lista no está vacía, como en CINCO.
    widget.friends.loadBlocked();
  }

  @override
  void dispose() {
    _deletion.dispose();
    super.dispose();
  }

  SendaStatTable? _practiceTable(L l) {
    final stats = {
      for (final d in Difficulty.values) d: widget.practice.statsFor(d),
    };
    if (stats.values.every((s) => s.played == 0)) return null;
    String mejor(PracticeLevelStats s) {
      final b = s.bestSeconds;
      if (b == null) return '—';
      final m = b ~/ 60, sec = b % 60;
      return '$m:${sec.toString().padLeft(2, '0')}';
    }

    // TRANSPUESTA a propósito: de cabecera van las dificultades —cortas y de
    // largo parejo— y las métricas van al carril izquierdo, donde el texto
    // cabe. "Completadas" de cabecera partió dos versiones de esta tarjeta.
    return SendaStatTable(
      title: l.statsPracticeByLevel,
      columns: [for (final d in Difficulty.values) _difficultyName(d)],
      rows: [
        SendaStatTableRow(
          label: l.statsPlayedShort,
          values: [for (final d in Difficulty.values) '${stats[d]!.played}'],
        ),
        SendaStatTableRow(
          label: l.statsCompletedShort,
          values: [for (final d in Difficulty.values) '${stats[d]!.completed}'],
        ),
        SendaStatTableRow(
          label: l.statsBestTime,
          values: [for (final d in Difficulty.values) mejor(stats[d]!)],
        ),
      ],
      // El mejor tiempo es la fila protagonista: la cifra por la que se
      // vuelve a esta tarjeta. Sale en el acento del tema.
      accentRow: 2,
    );
  }

  String _difficultyName(Difficulty d) => difficultyLabel(context, d);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = widget.progress;
    final avg = progress.averageMistakes;

    return ListenableBuilder(
      listenable: Listenable.merge([progress, widget.practice, widget.friends]),
      builder: (context, _) => SendaSettingsScreen(
        // Con el nombre en el idioma de la pantalla: de aquí lo sacan
        // «Califica…», «¡Gracias por apoyar a…!» y el borrado de cuenta
        // (ver `nonaConfigNamed`).
        config: nonaConfigNamed(l.appName),
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
        // La práctica por nivel (pedido de André): mejor tiempo, jugadas y
        // completadas de cada dificultad, en la tarjeta-tabla de la familia.
        // Solo si hay algo que contar — las cifras existen desde el 26-8-2026
        // y una tabla de ceros es ruido, igual que la de intentos de CINCO se
        // esconde vacía.
        statsChart: _practiceTable(l),
        // Los cuatro temas de la familia, con Cobalto (Azul + Rojo del icono de
        // Buscaminas) en primer lugar como tema principal y las muestras de
        // color adaptadas a la tríada de Buscaminas (acento, rojo mina / azul
        // contraste y pizarra oscura) en vez del amarillo de CINCO.
        themes: [
          for (final p in const [
            SendaPalettes.cobalto,
            SendaPalettes.menta,
            SendaPalettes.lavanda,
            SendaPalettes.coral,
          ])
            SendaThemeOption(
              id: p.id,
              label: sendaPaletteLabel(SendaL.of(context), p),
              brand: p.brand,
              swatches: [
                p.brand.accent,
                p.id == 'coral'
                    ? const Color(0xFF4FA8FF)
                    : const Color(0xFFFF5252),
                const Color(0xFF242632),
              ],
            ),
        ],
        selectedTheme: widget.theme.palette.id,
        // El fallback no debería usarse nunca —el nombre sale de la propia
        // lista— pero obligarlo es lo que hizo aparecer esta línea al cambiar
        // la API: antes caía en Menta en silencio.
        onPickTheme: (option) => widget.theme.select(
          SendaPalettes.byId(option.id, fallback: NonaColors.defaultPalette),
        ),
        notifications: widget.notifications,
        // «Bloqueados», solo si hay alguien bloqueado, como en CINCO (André,
        // 5-10-2026). Estuvo apagada del todo, y entonces quien solo tiene
        // Nona y bloqueaba a alguien no podía deshacerlo desde Nona —y el
        // aviso de bloquear del paquete le manda a «Bloqueados»—.
        showBlocked: widget.friends.blocked.isNotEmpty,
        consent: widget.consent,
        resenas: widget.resenas,
        otrosJuegos: kOtrosJuegosDeNona,
        aboutTitle: l.aboutNona,
        aboutSubtitle: l.aboutSubtitle,
        onAbout: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SendaAboutScreen(
              config: nonaConfigNamed(l.appName),
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
