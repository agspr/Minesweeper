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
/// **Fila y no `Stack`**, aunque un `Stack` centre por definición: apilado, el
/// título y el chip pueden solaparse en un móvil estrecho con el texto ampliado
/// sin que nada avise. En fila, el mismo caso desborda, y un desborde lo caza
/// `layout_test.dart`.
///
/// Aun así el título va **centrado en la PANTALLA**, no en el hueco que le
/// sobre: las dos ranuras laterales llevan el mismo `flex`, así que miden lo
/// mismo pase lo que pase con su contenido. Es lo que hace que el título no se
/// mueva al pasar de cero fallos a tres —una cabecera que se recoloca sola
/// mientras juegas es justo lo que el resto de la app evita— y por eso el chip
/// de estado tiene que ser ESTRECHO: un chip con frase dentro obligaría a
/// ranuras anchas y dejaría al título sin sitio.
///
/// ## El tamaño del título
///
/// 17 y no 13, que es lo que dice el código de CINCO. No es una discrepancia:
/// CINCO recorta la escala de texto del sistema a un MÍNIMO de 1,32
/// (`CincoTextScale`), así que sus 13 nunca se dibujan a menos de 17,2. Nona no
/// recorta nada —el texto del sistema manda, que es lo suyo—, de modo que para
/// verse igual hay que escribir el número al que allí se llega.
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
          // Las dos ranuras laterales, con el MISMO flex: es lo que centra el
          // título en la pantalla en vez de en lo que sobre.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
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
                // Sin esto, Material 3 envuelve el botón en 48 puntos de área
                // de toque pase lo que pase con `constraints`, y la cabecera
                // crece 4 puntos sin que nadie lo haya pedido. Con
                // `shrinkWrap` manda el 44, que es el mínimo de Apple.
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 17,
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
                        fontSize: 12,
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
          // El `Align` es lo que pega el chip al borde: sin él se quedaría
          // donde acabe, a media ranura.
          Expanded(
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

/// La pastilla de estado de la cabecera: un símbolo y un número.
///
/// Antes llevaba la frase entera —"sin errores", "3 errores (tope)"—, y una
/// frase en una ranura lateral es lo que impedía centrar el título: cuanto más
/// ancho el chip, menos sitio para el título y más se descentraba al llegar el
/// primer fallo. Con símbolo y número mide siempre más o menos lo mismo,
/// cualquiera que sea el idioma.
///
/// Las palabras no se pierden: siguen siendo el nombre accesible del chip, así
/// que un lector de pantalla lee "3 errores (tope)" y no "equis, tres".
///
/// **El tope se dice por RELLENO, no por texto.** Pasados los cinco fallos, el
/// castigo de puntuación ya no crece (§1), y eso lo decía el " (tope)" que ya
/// no cabe. En su lugar el chip se rellena en sólido: fondo tintado mientras
/// suma, sólido cuando ya no. Dos canales —relleno y color— y ni una palabra.
class HeaderChip extends StatelessWidget {
  const HeaderChip({
    super.key,
    required this.icon,
    required this.count,
    required this.semanticsLabel,
    this.highlight = false,
    this.capped = false,
  });

  final IconData icon;
  final int count;

  /// Lo que se lee en voz alta. Aquí viven las palabras que el chip ya no
  /// pinta.
  final String semanticsLabel;

  final bool highlight;

  /// Se alcanzó el tope: el chip pasa a sólido.
  final bool capped;

  @override
  Widget build(BuildContext context) {
    final bg = capped
        ? NonaColors.wrong
        : highlight
        ? NonaColors.cellWrong
        : NonaColors.surface;
    final fg = capped
        ? NonaColors.bg
        : highlight
        ? NonaColors.wrong
        : NonaColors.muted;
    return Semantics(
      label: semanticsLabel,
      // El icono y el número por separado se leerían como "equis" y "tres".
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
