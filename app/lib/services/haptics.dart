/// Vibraciones propias del sudoku, con nombre de lo que significan.
///
/// Las compartidas con CINCO —pestañas, elecciones de ajustes— viven en
/// `Haptics`, dentro de `juegos_senda`. Aquí van solo las que no tienen
/// sentido fuera de un tablero, para no tener que publicar el paquete cada vez
/// que Nona aprende a vibrar por algo nuevo. La regla es la misma que allí:
/// los eventos que importan no pueden sentirse igual, o la háptica deja de
/// informar.
///
/// ## Los tres escalones
///
/// Cada uno usa una primitiva DISTINTA del sistema, no la misma con otro
/// nombre, así que no hay forma de confundirlos con el teléfono en el bolsillo:
///
/// | escalón      | primitiva        | cuándo                              |
/// |--------------|------------------|-------------------------------------|
/// | [select]     | `selectionClick` | mover la selección por el tablero    |
/// | [tap]        | `lightImpact`    | cualquier BOTÓN                      |
/// | [mistake]    | `vibrate`        | escribir un dígito equivocado        |
///
/// El de la selección es más tenue que el de los botones a propósito: se
/// dispara al pasear el dedo por 81 casillas buscando dónde escribir, y con el
/// golpe de un botón en cada una, barrer el tablero se sentiría como teclear.
///
/// Que solo el fallo sea LARGO es lo que hace legible el resto: deshacer,
/// borrar, notas, paleta y la X no pueden producirlo ni por error, porque
/// [mistake] solo se llama desde `tapDigit` cuando `SudokuBoard.place`
/// devuelve que ha contado un fallo.
///
/// Los botones vibran en `onTapDown` y no al soltar (igual que el teclado de
/// CINCO): así la vibración acompaña al dedo bajando, y en un dígito
/// equivocado se siente como PULSACIÓN y luego VEREDICTO en vez de dos
/// vibraciones encimadas.
///
/// No hace falta interruptor propio: HapticFeedback respeta los ajustes de
/// vibración del sistema en iOS y en Android. Y `SystemChannels.platform` es un
/// `OptionalMethodChannel`, así que en una prueba sin simulador de plataforma
/// esto no falla: simplemente no hace nada.
library;

import 'package:flutter/services.dart';

abstract final class NonaHaptics {
  /// Cualquier botón: dígitos, deshacer, borrar, notas, paleta, la X, las
  /// pastillas de dificultad y los botones del resultado.
  ///
  /// `lightImpact` y no `selectionClick`: el tic de selección en iPhone es tan
  /// leve que un pulgar apoyado en el cristal se lo pierde, y lo que se pide de
  /// un botón es notar que ha entrado.
  static void tap() => HapticFeedback.lightImpact();

  /// La selección del tablero CAMBIA de casilla.
  ///
  /// Lo disparan los controladores y no el widget, porque son el único sitio
  /// que sabe si la selección ha cambiado de verdad: volver a tocar la casilla
  /// ya seleccionada no mueve nada y no debe vibrar.
  static void select() => HapticFeedback.selectionClick();

  /// Fallo: la vibración LARGA del sistema.
  ///
  /// Larga y no un golpe, porque el aviso visual puede no bastar. Con Coral,
  /// una pista y un dígito equivocado llevan el mismo color y el mismo peso;
  /// lo que los separa es el fondo rojo de la casilla, y un fondo se puede
  /// pasar por alto con el dedo encima. Un zumbido largo no. Y es distinta de
  /// cualquier golpe de acierto: `vibrate` es el único patrón sostenido.
  static void mistake() => HapticFeedback.vibrate();
}
