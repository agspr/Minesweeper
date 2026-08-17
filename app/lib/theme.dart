/// Identidad visual de Nona.
///
/// Los neutros oscuros son los de CINCO a propósito: son el aire de familia de
/// Juegos Senda, y cuando el paquete compartido esté extraído los pondrá él.
/// Lo que es de Nona y solo de Nona es el **acento** y los colores del
/// **tablero** — el reparto acordado es "el paquete trae el andamiaje, cada
/// juego trae su marca".
///
/// El acento es ámbar y no el menta de CINCO por dos razones: distingue las dos
/// apps de un vistazo en la pantalla de inicio, y un sudoku se mira mucho rato
/// seguido, así que un tono cálido y de brillo medio cansa menos que un verde
/// saturado.
///
/// El tablero necesita distinguir **seis** estados a la vez —pista, escrita,
/// equivocada, seleccionada, misma fila/columna/caja, mismo dígito— y eso no se
/// puede hacer solo con tonos: quien no distingue bien los colores vería lo
/// mismo. Así que cada estado se separa además por **brillo** o por **peso de
/// la tipografía**, nunca solo por color.
library;

import 'package:flutter/material.dart';

abstract final class NonaColors {
  // Neutros compartidos con CINCO.
  static const bg = Color(0xFF0C0C10);
  static const appBg = Color(0xFF131318);
  static const surface = Color(0xFF1F1F26);
  static const sheet = Color(0xFF1B1B22);
  static const text = Color(0xFFF2F0F7);
  static const muted = Color(0xFF6E6E7D);

  // Acento de Nona: ámbar miel.
  static const accent = Color(0xFFFFC46B);
  static const accentDeep = Color(0xFF33240C);
  static const accentChip = Color(0xFF3A2C14);

  // ── Tablero ────────────────────────────────────────────
  /// Fondo de una casilla normal.
  static const cell = Color(0xFF17171D);

  /// Casilla de la fila/columna/caja de la seleccionada. Un paso más clara,
  /// para orientar sin gritar.
  static const cellPeer = Color(0xFF1E1E26);

  /// Casilla seleccionada.
  static const cellSelected = Color(0xFF3A2C14);

  /// Casillas con el MISMO dígito que la seleccionada: ayuda a barrer el
  /// tablero buscando dónde falta ese número.
  static const cellSameDigit = Color(0xFF262029);

  /// Fondo de una casilla equivocada. La comprobación automática va activa
  /// (§1), así que esto se ve en el acto.
  static const cellWrong = Color(0xFF3A1218);

  /// Pista: la más brillante y en negrita. No se puede tocar, y se nota.
  static const given = Color(0xFFF2F0F7);

  /// Dígito escrito por el jugador: en el acento, más ligero que una pista.
  static const entered = accent;

  /// Dígito equivocado.
  static const wrong = Color(0xFFFF7A8A);

  /// Anotaciones a lápiz.
  static const note = Color(0xFF7B7B8C);

  static const gridThin = Color(0xFF26262E);
  static const gridThick = Color(0xFF4A4A58);

  // ── Numpad ─────────────────────────────────────────────
  static const keyBg = Color(0xFF23232B);
  static const keyFg = Color(0xFFECEAF2);
  static const keyDone = Color(0xFF1A1A20);
  static const keyDoneFg = Color(0xFF44444E);
}

ThemeData nonaTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: NonaColors.appBg,
    colorScheme: const ColorScheme.dark(
      primary: NonaColors.accent,
      onPrimary: NonaColors.accentDeep,
      surface: NonaColors.appBg,
      onSurface: NonaColors.text,
    ),
    useMaterial3: true,
  );
  return base;
}
