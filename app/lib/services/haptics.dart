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
/// | escalón   | qué se le pide al sistema        | cuándo                    |
/// |-----------|----------------------------------|---------------------------|
/// | [select]  | `selectionClick`                 | mover la selección        |
/// | [tap]     | `lightImpact`                    | cualquier BOTÓN           |
/// | [mistake] | `errorNotification` + `vibrate`  | escribir un dígito malo   |
///
/// El de la selección es más tenue que el de los botones a propósito: se
/// dispara al pasear el dedo por 81 casillas buscando dónde escribir, y con el
/// golpe de un botón en cada una, barrer el tablero se sentiría como teclear.
///
/// Los dos primeros son un golpe suelto; el fallo es lo único que pide un
/// PATRÓN. Esa es la diferencia que se nota sin mirar, y [mistake] solo se
/// llama desde `tapDigit` cuando `SudokuBoard.place` devuelve que ha contado un
/// fallo: deshacer, borrar, notas, paleta y la X no pueden producirlo ni por
/// error.
///
/// Las teclas del numpad vibran y actúan al BAJAR el dedo (como el teclado de
/// CINCO desde el 28-9-2026; en Nona, el 5-10-2026): la cifra entra en el acto,
/// así que el veredicto también. Por eso **una cifra equivocada no da [tap]**,
/// solo [mistake]: los dos a la vez se encabalgarían. Un acierto da un golpe,
/// un fallo da el patrón, y se distinguen sin mirar (ver `numpad.dart`).
///
/// ## Lo que aquí NO se puede prometer
///
/// **No existe la vibración sostenida.** Los ocho métodos de `HapticFeedback`
/// acaban en el mismo método de canal y ninguno acepta duración; lo sostenido
/// de verdad es Core Haptics, que el engine no expone. Un comentario anterior
/// aquí llamaba a `vibrate` «el único patrón sostenido», y era falso: el propio
/// framework lo documenta como «for a short duration», y en Android es
/// `HapticFeedbackConstants.LONG_PRESS`, que se llama así por el GESTO y es un
/// tic único. Alargar el aviso solo se puede haciendo que se REPITA.
///
/// **Y puede no existir ninguna.** No es que respetemos el ajuste del sistema:
/// es que no podemos imponer nada. En Android los cuatro caminos pasan por
/// `performHapticFeedback`, que obedece el ajuste de retorno táctil. En un iPad
/// sin motor de vibración no hay absolutamente nada que sentir. Así que la
/// háptica REFUERZA el aviso de un fallo; no lo sustituye. El fondo rojo de la
/// casilla tiene que bastar por sí solo.
///
/// `SystemChannels.platform` es un `OptionalMethodChannel`, así que en una
/// prueba sin simulador de plataforma esto no falla: simplemente no hace nada.
library;

import 'package:flutter/foundation.dart';
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

  /// Fallo: el patrón de error del sistema, y encima el zumbido de alerta.
  ///
  /// Tiene que notarse porque el aviso visual puede no bastar: con Coral, una
  /// pista y un dígito equivocado llevan el mismo color y el mismo peso, y lo
  /// que los separa es el fondo rojo de la casilla — que se tapa con el dedo
  /// encima.
  ///
  /// **Dos llamadas, ninguna diferida, y ese es el diseño entero.** Secuenciar
  /// pulsos a mano con `Timer` es lo que parece obvio y es justo lo que no se
  /// puede hacer aquí, por una razón que no se ve hasta que se mide: para no
  /// encabalgar dos avisos habría que cancelar el anterior, y cancelarlo hace
  /// que dos fallos seguidos y tres se sientan IGUAL. En Nona el reloj no
  /// puntúa; el contador de fallos es lo único que puntúa. Un fallo tiene que
  /// seguir siendo un evento contable con el teléfono en el bolsillo, así que
  /// el patrón lo secuencia el sistema operativo y nosotros no guardamos
  /// estado. Sin `Timer` tampoco hay nada que sobreviva al desmontaje de la
  /// pantalla, ni que caiga dentro de la prueba siguiente.
  ///
  /// **`errorNotification` primero, y no por semántica sino por CAMINO.** En
  /// iOS es `UINotificationFeedbackGenerator` con
  /// `UINotificationFeedbackTypeError`: varios transitorios seguidos —un
  /// patrón de verdad, hecho por el sistema— y sobre todo la MISMA ruta de
  /// UIKit por la que ya se sienten las teclas del numpad. `vibrate` va por
  /// otra distinta (`AudioServicesPlaySystemSound`, el motor de alerta), y esa
  /// asimetría es la explicación candidata de que alguien sienta las teclas y
  /// no el fallo. Si es eso, esto lo cura.
  ///
  /// **Y `vibrate` se queda detrás a propósito.** Es lo que Nona lleva dando
  /// desde que existe, así que conservarlo garantiza que este cambio no puede
  /// sentirse MENOS que antes en un teléfono donde hoy sí se nota; y como
  /// cuelga de otra ruta, si una de las dos está muda queda la otra. Quitarlo
  /// es una línea; recuperar una sensación a la que alguien ya se acostumbró,
  /// no.
  ///
  /// En Android `errorNotification` es `HapticFeedbackConstants.REJECT`, pero
  /// **solo desde API 30**, y el mínimo de Flutter es 24: por debajo no hace
  /// nada y no avisa de nada. Por eso no puede ir sola. Ahí el aviso lo sigue
  /// sosteniendo `vibrate`, exactamente como hasta ahora — cero regresión.
  static void mistake() {
    // El orden importa poco entre dos llamadas síncronas, pero se deja el
    // patrón delante: es el que hay que sentir, y el zumbido es el refuerzo.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.errorNotification();
    }
    HapticFeedback.vibrate();
  }
}
