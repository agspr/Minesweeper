/// La cabecera de las dos pantallas de juego: salir, dónde estás, y el estado.
///
/// Misma forma que CINCO, que es lo que hace que las dos apps de la familia se
/// reconozcan: X a la izquierda, título centrado en versalitas espaciadas, y un
/// chip a la derecha con lo que se está midiendo.
///
/// **La X es la ÚNICA salida.** Desde que la barra inferior desaparece mientras
/// se juega, no hay pestañas debajo ni gesto de atrás que valga: si esta
/// cabecera no se dibuja, quien juega se queda encerrado. Por eso la pintan
/// también los estados de carga y de error de la diaria, donde antes no había
/// cabecera ninguna.
///
/// **Fila y no `Stack`**, aunque un `Stack` centraría el título de forma
/// perfecta: apilado, el título y el chip pueden solaparse en un móvil estrecho
/// con el texto ampliado sin que nada avise. En fila, el mismo caso desborda, y
/// un desborde lo caza `layout_test.dart`. Se paga con que el título va
/// centrado respecto a SU hueco y no a la pantalla —al llegar el primer fallo
/// el chip crece y lo empuja un par de puntos—, y es un precio que CINCO ya
/// paga.
///
/// Las dos ranuras laterales existen SIEMPRE, con chip o sin él, para que el
/// hueco del título no cambie de tamaño entre "sin errores" y "3 errores": una
/// cabecera que se recoloca sola mientras juegas es exactamente lo que el resto
/// de la app evita.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/haptics.dart';
import '../theme.dart';

class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.subtitle,
    this.trailing,
  });

  /// Se pone en VERSALITAS aquí, no en el ARB: así ninguna traducción tiene que
  /// acordarse de las mayúsculas. Es la misma convención que el menú.
  final String title;

  /// La dificultad, en la diaria. `null` mientras carga y en modo práctica.
  final String? subtitle;

  final VoidCallback onClose;

  /// El chip de estado: fallos en la diaria, pistas en el modo práctica.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              NonaHaptics.tap();
              onClose();
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 22,
              color: NonaColors.muted,
            ),
            tooltip: l.closeGame,
            // El tooltip ES el nombre accesible: añadir además un
            // `Semantics(label:)` haría que se leyera dos veces.
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            // Sin esto, Material 3 envuelve el botón en 48 puntos de área de
            // toque pase lo que pase con `constraints`, y la cabecera crece 4
            // puntos sin que nadie lo haya pedido. Con `shrinkWrap` manda el
            // 44, que es el mínimo que pide Apple.
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: NonaColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!.toUpperCase(),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: NonaColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // `Expanded` y no `Flexible`: con `Flexible` el hueco se encoge al
          // ancho del chip y el sobrante se va a la derecha DE ÉL, así que el
          // chip deja de estar pegado al borde y el título se descentra según
          // lo que ponga el chip.
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: trailing ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La pastilla de estado de la cabecera.
///
/// Era privada de la pantalla de la diaria; ahora la usan las dos, así que vive
/// aquí con el resto de la cabecera.
class HeaderChip extends StatelessWidget {
  const HeaderChip({super.key, required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? NonaColors.cellWrong : NonaColors.surface,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: highlight ? NonaColors.wrong : NonaColors.muted,
        ),
      ),
    );
  }
}
