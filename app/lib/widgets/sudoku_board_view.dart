/// El tablero rectangular de Buscaminas (8×8 en fácil, 9×12 en medio, 10×14 en difícil).
///
/// Casillas superelípticas (`RoundedSuperellipseBorder`) sentadas sobre una
/// rejilla 100% uniforme ajustada a píxeles físicos. Soporta toque directo (descubrir /
/// abanderar / acorde) y pulsación larga (colocar o quitar bandera).
///
/// Material 3 Expressive: casillas cubiertas táctiles con elevación y relieve
/// concéntrico, y casillas descubiertas lisas empotradas en el terreno.
library;

import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';

import '../game/board_metrics.dart';
import '../game/grid.dart';
import '../game/sudoku_board.dart';
import '../theme.dart';

class _ActiveTouch {
  _ActiveTouch({
    required this.cell,
    required this.downPosition,
    required this.wasCovered,
  });

  final int cell;
  final Offset downPosition;
  final bool wasCovered;
  Timer? timer;
  bool longPressTriggered = false;
  bool cancelled = false;
}

class SudokuBoardView extends StatefulWidget {
  const SudokuBoardView({
    super.key,
    required this.board,
    required this.selected,
    required this.onTapCell,
    this.onLongPressCell,
    this.onPointerDownCovered,
    this.onPointerUpCovered,
  });

  final SudokuBoard board;

  /// Casilla seleccionada, o -1.
  final int selected;

  final ValueChanged<int> onTapCell;
  final ValueChanged<int>? onLongPressCell;

  /// Avisa al HUD cuando se presiona una casilla cubierta para poner la carita '😮'.
  final VoidCallback? onPointerDownCovered;
  final VoidCallback? onPointerUpCovered;

  @override
  State<SudokuBoardView> createState() => _SudokuBoardViewState();
}

class _SudokuBoardViewState extends State<SudokuBoardView> {
  final Map<int, _ActiveTouch> _touches = {};
  final Set<int> _pressedCells = {};

  /// Umbral ágil de pulsación larga para colocar/quitar bandera al instante.
  static const _kLongPressDuration = Duration(milliseconds: 240);

  @override
  void dispose() {
    for (final t in _touches.values) {
      t.timer?.cancel();
    }
    _touches.clear();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event, BoardMetrics m) {
    final cell = m.cellAt(event.localPosition);
    if (cell < 0 || cell >= widget.board.boardCellCount) return;

    final revealed = widget.board.isRevealed(cell);
    final flagged = widget.board.isFlagged(cell);
    final unrevealed = !revealed && !flagged;

    final touch = _ActiveTouch(
      cell: cell,
      downPosition: event.localPosition,
      wasCovered: unrevealed,
    );

    if (widget.onLongPressCell != null && !revealed) {
      touch.timer = Timer(_kLongPressDuration, () {
        if (!mounted || touch.cancelled) return;
        touch.longPressTriggered = true;
        if (_pressedCells.remove(cell)) {
          setState(() {});
          if (_pressedCells.isEmpty) {
            widget.onPointerUpCovered?.call();
          }
        }
        widget.onLongPressCell?.call(cell);
      });
    }

    _touches[event.pointer] = touch;
    if (unrevealed) {
      final wasEmpty = _pressedCells.isEmpty;
      if (_pressedCells.add(cell)) {
        setState(() {});
      }
      if (wasEmpty) {
        widget.onPointerDownCovered?.call();
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event, BoardMetrics m) {
    final touch = _touches[event.pointer];
    if (touch == null || touch.cancelled || touch.longPressTriggered) return;

    // Tolerancia generosa al giro del pulgar sobre la pantalla táctil.
    final maxSlop = max(26.0, m.cell * 0.95);
    if ((event.localPosition - touch.downPosition).distance > maxSlop) {
      touch.cancelled = true;
      touch.timer?.cancel();
      if (_pressedCells.remove(touch.cell)) {
        setState(() {});
        if (_pressedCells.isEmpty) {
          widget.onPointerUpCovered?.call();
        }
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final touch = _touches.remove(event.pointer);
    if (touch == null) return;
    touch.timer?.cancel();

    if (_pressedCells.remove(touch.cell)) {
      setState(() {});
      if (_pressedCells.isEmpty) {
        widget.onPointerUpCovered?.call();
      }
    }

    if (!touch.cancelled && !touch.longPressTriggered) {
      widget.onTapCell(touch.cell);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    final touch = _touches.remove(event.pointer);
    if (touch == null) return;
    touch.cancelled = true;
    touch.timer?.cancel();

    if (_pressedCells.remove(touch.cell)) {
      setState(() {});
      if (_pressedCells.isEmpty) {
        widget.onPointerUpCovered?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final selected = widget.selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = BoardMetrics.fit(
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          cols: board.cols,
          rows: board.rows,
        );
        final total = board.boardCellCount;
        final revealedSafeCount = board.revealedSafeCount;
        final isLost = board.isLost;
        final selDigit = selected >= 0 && selected < total
            ? board.valueAt(selected)
            : 0;
        final selPeers = selected >= 0 && selected < total
            ? board.neighborsOf(selected).toSet()
            : const <int>{};

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _handlePointerDown(e, m),
            onPointerMove: (e) => _handlePointerMove(e, m),
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: SizedBox(
              width: m.width,
              height: m.height,
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(
                          board: board,
                          revealedCount: revealedSafeCount,
                          isLost: isLost,
                          metrics: m,
                          thin: NonaColors.gridThin,
                          thick: NonaColors.gridThick,
                          pixelRatio: MediaQuery.devicePixelRatioOf(context),
                        ),
                      ),
                    ),
                    for (var index = 0; index < total; index++)
                      Positioned.fromRect(
                        rect: m.rectOf(index),
                        child: _Cell(
                          board: board,
                          index: index,
                          metrics: m,
                          revealedSafeCount: revealedSafeCount,
                          isLost: isLost,
                          isSelected: index == selected,
                          isPressed: _pressedCells.contains(index),
                          isPeer: selPeers.contains(index),
                          isSameDigit:
                              selDigit != 0 &&
                              index != selected &&
                              board.valueAt(index) == selDigit,
                          onTap: () => widget.onTapCell(index),
                          onLongPress: widget.onLongPressCell == null
                              ? null
                              : () => widget.onLongPressCell!(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.board,
    required this.index,
    required this.metrics,
    required this.revealedSafeCount,
    required this.isLost,
    required this.isSelected,
    required this.isPressed,
    required this.isPeer,
    required this.isSameDigit,
    required this.onTap,
    this.onLongPress,
  });

  final SudokuBoard board;
  final int index;
  final BoardMetrics metrics;
  final int revealedSafeCount;
  final bool isLost;
  final bool isSelected;
  final bool isPressed;
  final bool isPeer;
  final bool isSameDigit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static Color clueColor(int clue) => switch (clue) {
    1 => const Color(0xFF3B82F6), // Azul eléctrico puro
    2 => const Color(0xFF10B981), // Verde esmeralda vivo
    3 => const Color(0xFFEF4444), // Rojo carmesí intenso
    4 => const Color(0xFF8B5CF6), // Púrpura brillante
    5 => const Color(0xFFB91C1C), // Granate profundo
    6 => const Color(0xFF06B6D4), // Turquesa cian
    7 => const Color(0xFF334155), // Carbón oscuro
    8 => const Color(0xFF94A3B8), // Gris pizarra
    _ => NonaColors.text,
  };

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final size = m.cell;
    final value = board.valueAt(index);
    final wrong = board.isWrong(index);
    final flagged = board.isFlagged(index);
    final revealed = value != 0;
    final unrevealed = !revealed && !flagged;
    final isMine = board.isMine(index);
    final isSafeStart = revealedSafeCount == 0 &&
        index == board.safeStart &&
        value == 0;

    final Color bg;
    final BorderSide borderSide;
    final List<BoxShadow>? shadows;

    if (wrong && isMine) {
      bg = const Color(0xFF6B141E);
      borderSide = const BorderSide(color: Color(0xFFFF5252), width: 1.8);
      shadows = [
        BoxShadow(
          color: const Color(0xFFFF5252).withValues(alpha: 0.35),
          blurRadius: 6,
        ),
      ];
    } else if (isLost && flagged && !isMine) {
      bg = const Color(0xFF35171B);
      borderSide = const BorderSide(color: Color(0xFFFF5252), width: 1.5);
      shadows = null;
    } else if (isLost && unrevealed && isMine) {
      bg = const Color(0xFF1E1E28);
      borderSide = const BorderSide(color: Color(0xFF3A3A4C), width: 1.2);
      shadows = null;
    } else if (flagged) {
      bg = const Color(0xFF282836);
      borderSide = BorderSide(
        color: NonaColors.accent.withValues(alpha: 0.8),
        width: 1.5,
      );
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(0, 2),
          blurRadius: 3,
        ),
      ];
    } else if (unrevealed) {
      if (isSafeStart) {
        bg = const Color(0xFF2A2D3C);
        borderSide = BorderSide(
          color: NonaColors.accent.withValues(alpha: 0.9),
          width: 1.8,
        );
        shadows = [
          BoxShadow(
            color: NonaColors.accent.withValues(alpha: 0.35),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ];
      } else if (isPressed) {
        bg = const Color(0xFF1E1E28);
        borderSide = BorderSide.none;
        shadows = null;
      } else if (isPeer) {
        bg = const Color(0xFF353546);
        borderSide = BorderSide(
          color: NonaColors.accent.withValues(alpha: 0.55),
          width: 1.2,
        );
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            offset: const Offset(0, 1.5),
            blurRadius: 2,
          ),
        ];
      } else {
        // Casilla cubierta mate sin borde para evitar líneas triplicadas
        // ni patrones de rombos en las intersecciones.
        bg = const Color(0xFF2A2A36);
        borderSide = BorderSide.none;
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 1),
            blurRadius: 1.5,
          ),
        ];
      }
    } else {
      // Casilla descubierta (lisa empotrada en el fondo)
      if (isSelected) {
        bg = NonaColors.cellSelected;
        borderSide = BorderSide(color: NonaColors.cellSelectedBorder, width: 2);
      } else {
        bg = const Color(0xFF13131A);
        borderSide = BorderSide.none;
      }
      shadows = null;
    }

    return Semantics(
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              isSelected ? m.selectedRadius : m.radius,
            ),
            side: borderSide,
          ),
          shadows: shadows,
        ),
        child: _buildCellContent(
          size: size,
          value: value,
          wrong: wrong,
          flagged: flagged,
          isMine: isMine,
          isSafeStart: isSafeStart,
        ),
      ),
    );
  }

  Widget _buildCellContent({
    required double size,
    required int value,
    required bool wrong,
    required bool flagged,
    required bool isMine,
    required bool isSafeStart,
  }) {
    // 1. Mina detonada (en rojo carmesí)
    if (wrong && isMine) {
      return Icon(
        Icons.brightness_7_rounded,
        size: size * 0.62,
        color: const Color(0xFFFF5252),
      );
    }

    // 2. Bandera falsa revelada al perder (bandera tachada con X)
    if (isLost && flagged && !isMine) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.flag_rounded,
            size: size * 0.55,
            color: const Color(0xFF888899),
          ),
          Icon(
            Icons.close_rounded,
            size: size * 0.70,
            color: const Color(0xFFFF3B30),
          ),
        ],
      );
    }

    // 3. Bandera normal / correcta
    if (flagged) {
      return Icon(
        Icons.flag_rounded,
        size: size * 0.60,
        color: const Color(0xFFFF3B30),
      );
    }

    // 4. Mina oculta descubierta al perder
    if (isLost && isMine) {
      return Icon(
        Icons.brightness_7_rounded,
        size: size * 0.58,
        color: const Color(0xFFB0B0C4),
      );
    }

    // 5. Casilla de salida segura inicial (indicador táctil antes del primer toque)
    if (isSafeStart) {
      return Icon(
        Icons.adjust_rounded,
        size: size * 0.46,
        color: NonaColors.accent.withValues(alpha: 0.85),
      );
    }

    // 6. Pista numérica descubierta
    if (value != 0) {
      final clue = clueFromValue(value);
      if (!wrong && clue == 0) {
        return const SizedBox.shrink();
      }
      final color = wrong ? NonaColors.wrong : _Cell.clueColor(clue);
      return Text(
        '${wrong ? value : clue}',
        style: TextStyle(
          fontSize: size * 0.62,
          height: 1,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.board,
    required this.revealedCount,
    required this.isLost,
    required this.metrics,
    required this.thin,
    required this.thick,
    required this.pixelRatio,
  });

  final SudokuBoard board;
  final int revealedCount;
  final bool isLost;
  final BoardMetrics metrics;
  final Color thin;
  final Color thick;
  final double pixelRatio;

  double _snap(double v) => (v * pixelRatio).roundToDouble() / pixelRatio;

  bool _isRev(int r, int c) => board.isRevealed(r * metrics.cols + c);

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    final wTotal = m.width;
    final hTotal = m.height;

    // La cuadrícula interior se dibuja exclusivamente entre casillas
    // descubiertas (excavadas), evitando cruces y rombos entre casillas cubiertas.
    final paint = Paint()..color = thin;

    // Segmentos verticales entre columna c y c + 1
    for (var c = 0; c < m.cols - 1; c++) {
      final w = m.lineWidthAfter(c);
      final x0 = _snap(m.lineAt(c) - w / 2);
      final x1 = max(_snap(m.lineAt(c) + w / 2), x0 + 1 / pixelRatio);
      for (var r = 0; r < m.rows; r++) {
        if (!_isRev(r, c) || !_isRev(r, c + 1)) continue;
        final top = r == 0
            ? 0.0
            : (_isRev(r - 1, c) && _isRev(r - 1, c + 1)
                  ? _snap(m.lineAt(r - 1))
                  : _snap(m.offsetOf(r)));
        final bottom = r == m.rows - 1
            ? hTotal
            : (_isRev(r + 1, c) && _isRev(r + 1, c + 1)
                  ? _snap(m.lineAt(r))
                  : _snap(m.offsetOf(r) + m.cell));
        canvas.drawRect(Rect.fromLTRB(x0, top, x1, bottom), paint);
      }
    }

    // Segmentos horizontales entre fila r y r + 1
    for (var r = 0; r < m.rows - 1; r++) {
      final w = m.lineWidthAfter(r);
      final y0 = _snap(m.lineAt(r) - w / 2);
      final y1 = max(_snap(m.lineAt(r) + w / 2), y0 + 1 / pixelRatio);
      for (var c = 0; c < m.cols; c++) {
        if (!_isRev(r, c) || !_isRev(r + 1, c)) continue;
        final left = c == 0
            ? 0.0
            : (_isRev(r, c - 1) && _isRev(r + 1, c - 1)
                  ? _snap(m.lineAt(c - 1))
                  : _snap(m.offsetOf(c)));
        final right = c == m.cols - 1
            ? wTotal
            : (_isRev(r, c + 1) && _isRev(r + 1, c + 1)
                  ? _snap(m.lineAt(c))
                  : _snap(m.offsetOf(c) + m.cell));
        canvas.drawRect(Rect.fromLTRB(left, y0, right, y1), paint);
      }
    }

    // Marco exterior con borde suavizado
    final frame = Paint()
      ..color = thick
      ..style = PaintingStyle.stroke
      ..strokeWidth = m.thick;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, wTotal, hTotal).deflate(m.thick / 2),
        Radius.circular(m.frameRadius),
      ),
      frame,
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.revealedCount != revealedCount ||
      old.isLost != isLost ||
      old.board != board ||
      old.metrics.side != metrics.side ||
      old.metrics.cols != metrics.cols ||
      old.metrics.rows != metrics.rows ||
      old.thin != thin ||
      old.thick != thick ||
      old.pixelRatio != pixelRatio;
}
