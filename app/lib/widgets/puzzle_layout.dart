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

/// A partir de aquí se considera pantalla grande (plegable abierto, tablet o
/// ventana de escritorio). Es el mismo corte que usa `SendaOrientationGate` en
/// `main.dart` para desbloquear la rotación en los cuatro sentidos.
/// 540 dp incluye los plegables abiertos (Galaxy Z Fold, Pixel Fold, etc.,
/// cuyo lado menor ronda los 550–595 dp) además de todas las tablets.
const double kTabletShortestSide = 540;

class PuzzleLayout extends StatelessWidget {
  const PuzzleLayout({
    super.key,
    required this.header,
    required this.board,
    this.numpad,
    this.hud,
    this.aviso,
  });

  final Widget header;

  /// Barra de estado superior de Buscaminas (Minas restantes, Carita, Cronómetro).
  final Widget? hud;

  /// Se le da una caja y él se hace cuadrado con el lado menor: por eso aquí
  /// solo hay que darle la caja correcta, no calcular su tamaño.
  final Widget board;

  final Widget? numpad;

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
    final isLargeDevice = size.shortestSide >= kTabletShortestSide;
    final isLandscape = size.width > size.height * 1.05;

    if (isLargeDevice && isLandscape) return _wide(size);
    final maxWidth = isLargeDevice
        ? (size.width * 0.94).clamp(540.0, 860.0)
        : 520.0;
    return _tall(maxWidth: maxWidth);
  }

  /// Móvil, plegable vertical y tablet en vertical: columna optimizada para
  /// máxima área de tablero manteniendo proporciones armónicas.
  Widget _tall({required double maxWidth}) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topDrop = (constraints.maxHeight - 680).clamp(0.0, 28.0);
            return Column(
              children: [
                if (topDrop > 0) SizedBox(height: topDrop),
                header,
                if (hud != null) ...[
                  const SizedBox(height: 4),
                  hud!,
                ],
                const SizedBox(height: 6),
                // El tablero se acerca a la cabecera superior en pantallas altas
                // sin desperdiciar ningún píxel en pantallas compactas.
                Expanded(
                  child: _conAviso(
                    Align(
                      alignment: const Alignment(0, -0.30),
                      child: board,
                    ),
                  ),
                ),
                if (numpad != null) ...[
                  const SizedBox(height: 8),
                  numpad!,
                ],
                const SizedBox(height: 4),
              ],
            );
          },
        ),
      ),
    ),
  );

  /// Plegable abierto en horizontal, tablet apaisada, portátil y escritorio:
  /// tablero a la izquierda ocupando todo el alto disponible; cabecera, HUD y
  /// controles en un panel lateral proporcionado a la derecha.
  Widget _wide(Size screenSize) {
    final panelMaxWidth = (screenSize.width * 0.36).clamp(260.0, 400.0);
    final panelMinWidth = (screenSize.width * 0.26).clamp(220.0, 280.0);
    final horizontalGap = (screenSize.width * 0.025).clamp(16.0, 32.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // El tablero manda: se lleva todo el alto disponible y el ancho
              // que necesite para seguir cuadrado o rectangular según el modo.
              Expanded(child: _conAviso(Center(child: board))),
              SizedBox(width: horizontalGap),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: panelMaxWidth,
                  minWidth: panelMinWidth,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        header,
                        if (hud != null) ...[
                          const SizedBox(height: 12),
                          hud!,
                        ],
                        if (numpad != null) ...[
                          const SizedBox(height: 16),
                          numpad!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
