/// Identidad visual de Nona.
///
/// Los neutros oscuros y **los cuatro temas** los pone ahora el paquete: son el
/// aire de familia de Juegos Senda. Nona ofrece los mismos cuatro que CINCO
/// —Menta, Lavanda, Coral y Cobalto— porque la página "Más" es la misma
/// pantalla en las dos apps y tenía que verse igual, con los mismos nombres y
/// los mismos tonos.
///
/// **Esto sustituye al ámbar propio que tenía Nona.** El ámbar se eligió para
/// separar las dos apps de un vistazo en la pantalla de inicio y por ser un
/// tono cálido y de brillo medio, más llevadero en las sentadas largas que
/// invita un sudoku. Se cambia por decisión de producto —que las dos apps se
/// vean hermanas pesa más—, no porque aquel razonamiento fuera malo. Si algún
/// día se quiere recuperar, cabe como QUINTO tema junto a los cuatro de la
/// familia; lo que no cabe es que Nona tenga cuatro temas distintos a los de
/// CINCO en la misma pantalla compartida.
///
/// Lo que sigue siendo de Nona y solo de Nona es el **tablero**: necesita
/// distinguir **seis** estados a la vez —pista, escrita, equivocada,
/// seleccionada, misma fila/columna/caja, mismo dígito— y eso no se puede hacer
/// solo con tonos: quien no distingue bien los colores vería lo mismo. Así que
/// cada estado se separa además por **brillo** o por **peso de la tipografía**,
/// nunca solo por color. Por eso casi todo el tablero es neutro y solo la
/// casilla seleccionada y el dígito escrito siguen al acento.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

abstract final class NonaColors {
  /// Tema activo. No es `const` a propósito: se elige en ajustes y toda la app
  /// se reconstruye con el nuevo tono. Mismo patrón que `CincoColors.current`.
  ///
  /// Quien lo cambia es `ThemeController`, que además lo guarda; asignarlo a
  /// mano desde otro sitio dejaría la pantalla y el disco diciendo cosas
  /// distintas.
  static SendaPalette current = SendaPalettes.menta;

  // Neutros compartidos con CINCO.
  static const bg = SendaColors.bg;
  static const appBg = SendaColors.appBg;
  static const surface = SendaColors.surface;
  static const sheet = SendaColors.sheet;
  static const text = SendaColors.text;
  static const muted = SendaColors.muted;

  // Acento: el del tema elegido.
  static Color get accent => current.brand.accent;
  static Color get accentDeep => current.brand.accentDeep;
  static Color get accentChip => current.brand.accentChip;

  // ── Tablero ────────────────────────────────────────────
  /// Fondo de una casilla normal.
  static const cell = Color(0xFF17171D);

  /// Casilla de la fila/columna/caja de la seleccionada. Un paso más clara,
  /// para orientar sin gritar.
  static const cellPeer = Color(0xFF1E1E26);

  /// Casilla seleccionada. Es el chip del tema: el mismo tinte que usan las
  /// pastillas del resto de la app, para que "seleccionado" signifique lo
  /// mismo en el tablero y fuera de él.
  static Color get cellSelected => current.brand.accentChip;

  /// Casillas con el MISMO dígito que la seleccionada: ayuda a barrer el
  /// tablero buscando dónde falta ese número.
  ///
  /// Neutro y no teñido del acento a propósito: si esto siguiera al tema,
  /// con Coral quedaría a un paso de [cellWrong] y "hay otro 7 aquí" se leería
  /// como "esto está mal".
  static const cellSameDigit = Color(0xFF262029);

  /// Fondo de una casilla equivocada. La comprobación automática va activa
  /// (§1), así que esto se ve en el acto.
  static const cellWrong = Color(0xFF3A1218);

  /// Pista: la más brillante y en negrita. No se puede tocar, y se nota.
  static const given = Color(0xFFF2F0F7);

  /// Dígito escrito por el jugador: en el acento, más ligero que una pista.
  static Color get entered => accent;

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

/// El tema de la app.
///
/// Delega en el del paquete en vez de montar uno propio: así la tipografía
/// —Figtree— y el esquema de color salen del MISMO sitio en los dos juegos.
/// Cuando esto se construía aparte, Nona se quedó sin Figtree sin que nadie lo
/// notara: compilaba, pasaba las pruebas, y la misma pantalla compartida se
/// veía con dos letras distintas según la app.
ThemeData nonaTheme() => sendaTheme(NonaColors.current.brand);
