/// Cómo se reparten cabecera, tablero y numpad según el aparato.
///
/// Vive aparte porque lo usan las DOS pantallas de juego —la diaria y el modo
/// práctica— y tenían el reparto copiado. Con dos copias, arreglar el iPad en
/// una y no en la otra era cuestión de tiempo.
///
/// ## Por qué hay un caso de tablet
///
/// Nona salía con `TARGETED_DEVICE_FAMILY = "1,2"` porque es lo que pone la
/// plantilla de Flutter, no porque nadie eligiera iPad. Y con el reparto de
/// móvil estirado a 12.9 pulgadas, el tablero quedaba en un cuadrado de 520 px
/// flotando en mitad de la pantalla, con dos franjas negras enormes y el numpad
/// descolgado abajo: no desbordaba —las pruebas de layout pasaban— pero era una
/// app de móvil estirada.
///
/// Un sudoku es de los juegos que MÁS gana en pantalla grande: la cuadrícula se
/// lee de un vistazo y se toca sin apuntar. Así que en tablet no se estira, se
/// reparte:
///
/// - **Tablet apaisada**: tablero a la izquierda, ocupando todo el alto que
///   haya; cabecera y numpad en una columna a la derecha. Es el reparto clásico
///   y el único que usa el ancho para algo.
/// - **Tablet vertical**: la misma columna del móvil, pero dejando crecer el
///   tablero de verdad en vez de toparlo en 520.
/// - **Móvil**: exactamente lo de antes. No se toca lo que ya funcionaba.
library;

import 'package:flutter/material.dart';

/// A partir de aquí se considera tablet. Es el mismo corte que usa
/// `_OrientationGate` en `main.dart` para decidir si bloquea la rotación, así
/// que un aparato no puede ser tablet para una cosa y móvil para la otra.
const double kTabletShortestSide = 600;

class PuzzleLayout extends StatelessWidget {
  const PuzzleLayout({
    super.key,
    required this.header,
    required this.board,
    required this.numpad,
    this.aviso,
  });

  final Widget header;

  /// Se le da una caja y él se hace cuadrado con el lado menor: por eso aquí
  /// solo hay que darle la caja correcta, no calcular su tamaño.
  final Widget board;

  final Widget numpad;

  /// Lo que sube desde el borde de abajo del tablero (ver `AvisoFlotante`).
  /// Va sobre la zona del tablero y nunca sobre el numpad, que es lo que
  /// alguien está a punto de tocar.
  final Widget? aviso;

  Widget _conAviso(Widget tablero) {
    final a = aviso;
    if (a == null) return tablero;
    return Stack(
      fit: StackFit.expand,
      children: [
        tablero,
        Positioned(left: 0, right: 0, bottom: 0, child: a),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= kTabletShortestSide;
    final isLandscape = size.width > size.height;

    if (isTablet && isLandscape) return _wide();
    return _tall(maxWidth: isTablet ? 760 : 520);
  }

  /// Móvil, y tablet en vertical: la columna de siempre.
  Widget _tall({required double maxWidth}) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            header,
            const SizedBox(height: 10),
            // El tablero se queda con el espacio que sobre y siempre cuadrado;
            // el numpad no se comprime nunca, porque un numpad estrujado se
            // falla al tocar.
            Expanded(child: _conAviso(Center(child: board))),
            const SizedBox(height: 14),
            numpad,
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );

  /// Tablet apaisada: tablero a la izquierda, controles a la derecha.
  Widget _wide() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El tablero manda: se lleva todo el alto disponible y el ancho que
        // necesite para seguir cuadrado.
        Expanded(child: _conAviso(Center(child: board))),
        const SizedBox(width: 24),
        // Ancho fijo y no una fracción: el numpad tiene un tamaño cómodo para
        // el dedo y crecer con la pantalla lo convertiría en teclas enormes y
        // separadas. Topado también por si la ventana es estrecha (Split View).
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, minWidth: 260),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [header, const SizedBox(height: 28), numpad],
          ),
        ),
      ],
    ),
  );
}
