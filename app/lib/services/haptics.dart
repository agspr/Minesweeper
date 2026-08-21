/// Vibraciones propias del sudoku, con nombre de lo que significan.
///
/// Las compartidas con CINCO —teclado, pestañas, elecciones— viven en
/// `Haptics`, dentro de `juegos_senda`. Aquí van solo las que no tienen
/// sentido fuera de un tablero, para no tener que publicar el paquete cada vez
/// que Nona aprende a vibrar por algo nuevo. La regla es la misma que allí:
/// los eventos que importan no pueden sentirse igual, o la háptica deja de
/// informar.
///
/// No hace falta interruptor propio: HapticFeedback respeta los ajustes de
/// vibración del sistema en iOS y en Android.
library;

import 'package:flutter/services.dart';

abstract final class NonaHaptics {
  /// Fallo: la vibración LARGA del sistema.
  ///
  /// Larga y no un golpe, porque el aviso visual puede no bastar. Con Coral,
  /// una pista y un dígito equivocado llevan el mismo color y el mismo peso;
  /// lo que los separa es el fondo rojo de la casilla, y un fondo se puede
  /// pasar por alto con el dedo encima. Un zumbido largo no. Y es distinta de
  /// cualquier golpe de acierto: `vibrate` es el único patrón sostenido.
  static void mistake() => HapticFeedback.vibrate();
}
