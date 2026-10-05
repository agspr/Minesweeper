/// Numpad: los nueve dígitos y las cuatro acciones.
///
/// **Sin contador debajo de cada tecla.** Lo llevaba, y era información que ya
/// está en el tablero: quien quiere saber cuántos cincos faltan mira, no lee un
/// número diminuto. Quitarlo devuelve la tecla a lo que es —un dígito grande y
/// tocable— y baja el bloque entero. Cuando un dígito ya está las nueve veces,
/// la tecla se apaga por BRILLO (fondo y tinta más oscuros); apagarla en vez de
/// esconderla mantiene el numpad quieto, porque una fila de teclas que se
/// reordena sola hace fallar el dedo.
///
/// **Las acciones son solo iconos.** Deshacer, borrar, notas y color no
/// necesitan que se lo cuenten dos veces: el icono lo dice, y la etiqueta
/// costaba alto en la pantalla más apretada. El nombre sigue estando para quien
/// lo necesita —en el tooltip, que es además lo que leen los lectores de
/// pantalla— y el estado activo se dice por DOS canales, relleno del icono y
/// fondo, nunca solo por color: el acento lo elige quien juega y no puede ser
/// el único que distinga un modo de otro.
///
/// **Todas las teclas actúan al BAJAR el dedo**, no al soltarlo, y **los huecos
/// entre teclas son de la tecla más cercana** (André, 5-10-2026, el mismo
/// arreglo que CINCO hizo en su teclado: «me salto demasiadas letras»). Antes la
/// tecla vibraba al bajar pero la cifra entraba al LEVANTAR, y solo si el dedo
/// no se había deslizado: con prisa, el dedo se desliza, vibraba y no entraba
/// nada. Y los 4 puntos entre cifras, los 8 entre acciones y los 10 entre las
/// dos filas no eran de nadie. Ahora cada mitad de hueco es de la tecla de su
/// lado; se ven igual y el alto no cambia.
///
/// **Una cifra equivocada no da el golpe de la tecla, solo el de error.** Antes
/// eran dos momentos —golpe al bajar, veredicto al soltar—; con la cifra entrando
/// al bajar, los dos caerían a la vez, encabalgados. Así un acierto da un golpe
/// corto y un fallo da el patrón de error, y se distinguen sin mirar. Ver
/// `NonaHaptics`.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../game/grid.dart';
import '../game/sudoku_board.dart';
import '../services/haptics.dart';
import '../theme.dart';

class Numpad extends StatelessWidget {
  const Numpad({
    super.key,
    required this.board,
    required this.notesMode,
    required this.enabled,
    required this.onDigit,
    required this.onErase,
    required this.onToggleNotes,
    required this.onUndo,
    required this.boardColourOn,
    required this.onToggleBoardColour,
  });

  final SudokuBoard board;
  final bool notesMode;

  /// `false` con la partida ya terminada: las teclas siguen visibles pero
  /// apagadas, para que la pantalla no dé un salto al acabar.
  final bool enabled;

  /// Pone la cifra y dice si contó como fallo (ver `DailyController.tapDigit`).
  final bool Function(int digit) onDigit;
  final VoidCallback onErase;
  final VoidCallback onToggleNotes;
  final VoidCallback onUndo;

  /// Estado del color del tablero, para la cuarta tecla de acción.
  final bool boardColourOn;
  final VoidCallback onToggleBoardColour;

  /// Medio hueco entre dos cifras, entre dos acciones y entre las dos filas.
  /// Cada mitad es de la tecla de su lado.
  static const _medioEntreCifras = 2.0;
  static const _medioEntreAcciones = 4.0;
  static const _medioEntreFilas = 5.0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final acciones = <Widget Function(EdgeInsets)>[
      (m) => _ActionKey(
        margen: m,
        icon: Icons.undo_rounded,
        label: l.undo,
        enabled: enabled && board.canUndo,
        onTap: onUndo,
      ),
      (m) => _ActionKey(
        margen: m,
        icon: Icons.backspace_outlined,
        label: l.erase,
        enabled: enabled,
        onTap: onErase,
      ),
      (m) => _ActionKey(
        margen: m,
        // Relleno cuando está activo, contorno cuando no: el modo notas no
        // puede distinguirse solo por el color del fondo.
        icon: notesMode ? Icons.edit_rounded : Icons.edit_outlined,
        label: l.notes,
        enabled: enabled,
        active: notesMode,
        onTap: onToggleNotes,
      ),
      // Apagar o encender el color del tablero, sin salir del tablero.
      //
      // Va aquí y no en ajustes porque es una decisión que se toma MIRÁNDOLO:
      // quien lo encuentre chillón lo piensa jugando, y mandarle a otra
      // pantalla para volver a comprobar el efecto sería pedirle que recuerde
      // dos estados a la vez. Es el mismo criterio por el que el selector de
      // color SÍ vive en Más: allí se elige identidad, aquí se ajusta lo que
      // se está mirando.
      //
      // Sigue viva con la partida terminada: es una preferencia de VISTA, no
      // una jugada, y el tablero se sigue viendo debajo del resultado.
      (m) => _ActionKey(
        margen: m,
        // El icono dice en qué ESTADO está, no qué pasará al pulsarlo: un
        // icono que anuncia la acción obliga a deducir el estado actual por
        // descarte.
        icon: boardColourOn ? Icons.palette_rounded : Icons.palette_outlined,
        label: boardColourOn ? l.boardColourOn : l.boardColourOff,
        enabled: true,
        active: boardColourOn,
        onTap: onToggleBoardColour,
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            for (var digit = 1; digit <= boardSize; digit++)
              Expanded(
                child: _DigitKey(
                  digit: digit,
                  done: board.remainingOf(digit) <= 0,
                  notesMode: notesMode,
                  enabled: enabled,
                  onTap: () => onDigit(digit),
                  margen: const EdgeInsets.fromLTRB(
                    _medioEntreCifras,
                    0,
                    _medioEntreCifras,
                    _medioEntreFilas,
                  ),
                ),
              ),
          ],
        ),
        // Las cuatro acciones, iguales de ancho a la vista, con su hueco
        // repartido a medias. Con márgenes sueltos las de los extremos —que
        // solo tienen vecino por un lado— saldrían más anchas que las de en
        // medio; por eso se mide.
        LayoutBuilder(
          builder: (context, c) {
            const medio = _medioEntreAcciones;
            final tecla = (c.maxWidth - 6 * medio) / 4;
            return Row(
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    width: tecla + (i == 0 || i == 3 ? medio : 2 * medio),
                    child: acciones[i](
                      EdgeInsets.fromLTRB(
                        i == 0 ? 0 : medio,
                        _medioEntreFilas,
                        i == 3 ? 0 : medio,
                        0,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.done,
    required this.notesMode,
    required this.enabled,
    required this.onTap,
    required this.margen,
  });

  final int digit;

  /// Ese dígito ya está las nueve veces en el tablero.
  final bool done;

  final bool notesMode;
  final bool enabled;

  /// Pone la cifra y dice si contó como fallo.
  final bool Function() onTap;

  /// El medio hueco que es de esta tecla: se toca, pero no se pinta.
  final EdgeInsets margen;

  /// La cifra entra, y el golpe solo si NO fue un fallo: el fallo trae su
  /// propio patrón, y los dos a la vez se encabalgarían.
  void _pulsar() {
    if (!onTap()) NonaHaptics.tap();
  }

  @override
  Widget build(BuildContext context) {
    final live = enabled && !done;
    return _Pulsable(
      activa: live,
      onPulsar: _pulsar,
      margen: margen,
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? NonaColors.keyDone : NonaColors.keyBg,
          borderRadius: BorderRadius.circular(10),
          // En modo notas el numpad se enmarca en el acento: hay que poder
          // saber en qué modo estás sin probar una tecla.
          border: notesMode && live
              ? Border.all(color: NonaColors.accent, width: 1.5)
              : null,
        ),
        // Nueve teclas en una fila es lo más apretado de la pantalla, así que
        // el contenido se encoge antes que desbordar. Con el texto del sistema
        // al máximo, un dígito a tamaño completo no cabe en 31 px de ancho.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$digit',
            style: TextStyle(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w700,
              color: done ? NonaColors.keyDoneFg : NonaColors.keyDigitFg,
            ),
          ),
        ),
      ),
    );
  }
}

/// Una tecla de acción: solo el icono, con el nombre en el tooltip.
///
/// 40 de alto y no 48: sin etiqueta debajo no hace falta más, y los 8 puntos
/// que sobran se los queda el tablero. De ancho pasan de 68, así que el área de
/// toque sigue siendo cómoda aunque el alto baje del mínimo de Apple.
class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.margen,
    this.active = false,
  });

  final IconData icon;

  /// Nombre de la acción. No se pinta: es el tooltip y el nombre accesible.
  final String label;

  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  /// El medio hueco que es de esta tecla.
  final EdgeInsets margen;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? NonaColors.keyDoneFg
        : active
        ? NonaColors.accent
        : NonaColors.keyFg;
    return Semantics(
      button: true,
      enabled: enabled,
      // El estado, no el icono: un lector de pantalla tiene que poder decir si
      // el modo notas está puesto.
      toggled: active,
      child: Tooltip(
        message: label,
        child: _Pulsable(
          activa: enabled,
          onPulsar: () {
            NonaHaptics.tap();
            onTap();
          },
          margen: margen,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? NonaColors.accentChip : NonaColors.keyBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Una tecla que actúa al BAJAR el dedo, con su medio hueco incluido.
///
/// Un `Listener` y no un `GestureDetector`: un toque de gesto compite en la
/// arena y se cancela si el dedo se desliza, que es justo como se perdían
/// cifras. El `Listener` no compite: cada dedo que baja, cuenta, y en el orden
/// en que bajan. El hueco es suyo porque el margen va DENTRO de la zona que
/// escucha y el fondo se pinta solo en la tecla.
///
/// Los lectores de pantalla no mandan dedos que bajan: mandan la acción
/// «tocar». Por eso la acción va también en la semántica, o con VoiceOver el
/// numpad dejaría de funcionar.
class _Pulsable extends StatelessWidget {
  const _Pulsable({
    required this.activa,
    required this.onPulsar,
    required this.margen,
    required this.child,
  });

  final bool activa;
  final VoidCallback onPulsar;
  final EdgeInsets margen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: activa,
      onTap: activa ? onPulsar : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: activa ? (_) => onPulsar() : null,
        child: Padding(padding: margen, child: child),
      ),
    );
  }
}
