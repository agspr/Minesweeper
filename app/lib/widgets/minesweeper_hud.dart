/// La barra superior de estado (HUD) icónica de Buscaminas bajo Material 3 Expressive.
///
/// Dispone en una sola fila simétrica y táctil:
/// - Izquierda: Contador digital de minas restantes (`💣 007`).
/// - Centro: El botón interactivo de la carita (`🙂` normal, `😮` en tensión al pulsar
///   una casilla oculta, `😎` con gafas de sol al ganar, `😵` mareada al detonar mina).
///   Al pulsar la carita se reinicia la partida.
/// - Derecha: Cronómetro digital en vivo (`0.0s` / `12.4s`) que arranca con el primer toque.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/haptics.dart';

enum MinesweeperFaceState {
  normal,
  surprised,
  won,
  lost,
}

class MinesweeperHud extends StatefulWidget {
  const MinesweeperHud({
    super.key,
    required this.remainingMines,
    required this.faceState,
    required this.onReset,
    required this.isRunning,
    required this.elapsedSeconds,
    this.initialTenths = 0,
  });

  /// Minas pendientes por marcar.
  final int remainingMines;

  /// Estado visual de la carita.
  final MinesweeperFaceState faceState;

  /// Acción al pulsar la carita (reiniciar partida).
  final VoidCallback onReset;

  /// Si el temporizador está corriendo activamente.
  final bool isRunning;

  /// Segundos acumulados antes de la sesión actual.
  final int elapsedSeconds;

  /// Décimas iniciales si las hubiera.
  final int initialTenths;

  @override
  State<MinesweeperHud> createState() => _MinesweeperHudState();
}

class _MinesweeperHudState extends State<MinesweeperHud> {
  Timer? _ticker;
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    if (widget.isRunning) {
      _stopwatch.start();
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(MinesweeperHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _stopwatch.reset();
        _stopwatch.start();
        _startTicker();
      } else {
        _stopwatch.stop();
        _stopwatch.reset();
        _ticker?.cancel();
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  double get _currentElapsed {
    if (!widget.isRunning) return widget.elapsedSeconds.toDouble();
    final live = _stopwatch.elapsedMilliseconds / 1000.0;
    return widget.elapsedSeconds + live;
  }

  String _formatMines(int count) {
    if (count < 0) {
      final abs = count.abs().clamp(0, 99);
      return '-${abs.toString().padLeft(2, '0')}';
    }
    return count.clamp(0, 999).toString().padLeft(3, '0');
  }

  String _formatTime(double seconds) {
    if (seconds < 100.0) {
      return seconds.toStringAsFixed(1);
    }
    final s = seconds.toInt().clamp(0, 999);
    return s.toString().padLeft(3, '0');
  }

  @override
  Widget build(BuildContext context) {
    final formattedMines = _formatMines(widget.remainingMines);
    final formattedTime = _formatTime(_currentElapsed);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF282836),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Contador de minas (Izquierda) ──────────────────
            DigitalLcd(
              icon: Icons.brightness_7_rounded,
              value: formattedMines,
              tooltip: 'Minas restantes: $formattedMines',
            ),

            // ── Botón Carita Smiley (Centro) ───────────────────
            SmileyButton(
              state: widget.faceState,
              onPressed: () {
                NonaHaptics.tap();
                _stopwatch.reset();
                widget.onReset();
              },
            ),

            // ── Cronómetro en vivo (Derecha) ───────────────────
            DigitalLcd(
              icon: Icons.timer_outlined,
              value: formattedTime,
              tooltip: 'Tiempo: $formattedTime s',
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla LCD digital empotrada con dígitos segmentados de alto contraste.
class DigitalLcd extends StatelessWidget {
  const DigitalLcd({
    super.key,
    required this.icon,
    required this.value,
    required this.tooltip,
  });

  final IconData icon;
  final String value;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF09090D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF1E1E28),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 1),
              blurRadius: 2,
              spreadRadius: -1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: const Color(0xFFFF5252).withValues(alpha: 0.85),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Color(0xFFFF4136),
                shadows: [
                  Shadow(
                    color: Color(0x88FF4136),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón interactivo de la carita clásica de Buscaminas dibujada con vector nítido.
class SmileyButton extends StatefulWidget {
  const SmileyButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final MinesweeperFaceState state;
  final VoidCallback onPressed;

  @override
  State<SmileyButton> createState() => _SmileyButtonState();
}

class _SmileyButtonState extends State<SmileyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pressed
                ? const [Color(0xFF22222E), Color(0xFF1A1A24)]
                : const [Color(0xFF323244), Color(0xFF222230)],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: _pressed ? const Color(0xFF1A1A24) : const Color(0xFF44445A),
            width: 1.2,
          ),
          boxShadow: _pressed
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(24, 24),
            painter: _SmileyPainter(state: widget.state),
          ),
        ),
      ),
    );
  }
}

/// Dibuja vectorialmente la icónica carita de Buscaminas según el estado.
class _SmileyPainter extends CustomPainter {
  const _SmileyPainter({required this.state});

  final MinesweeperFaceState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cabeza amarilla
    final facePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFEE58), Color(0xFFFBC02D)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, facePaint);

    // Contorno de cabeza
    final outlinePaint = Paint()
      ..color = const Color(0xFFC49000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, outlinePaint);

    final black = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.fill;

    final mouthStroke = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final leftEye = Offset(center.dx - radius * 0.35, center.dy - radius * 0.2);
    final rightEye = Offset(center.dx + radius * 0.35, center.dy - radius * 0.2);

    switch (state) {
      case MinesweeperFaceState.normal:
        // Ojos redondos normales
        canvas.drawCircle(leftEye, radius * 0.12, black);
        canvas.drawCircle(rightEye, radius * 0.12, black);
        // Sonrisa amplia
        final mouthRect = Rect.fromCircle(
          center: Offset(center.dx, center.dy + radius * 0.1),
          radius: radius * 0.5,
        );
        canvas.drawArc(mouthRect, 0.2 * math.pi, 0.6 * math.pi, false, mouthStroke);

      case MinesweeperFaceState.surprised:
        // Ojos muy abiertos
        canvas.drawCircle(leftEye, radius * 0.15, black);
        canvas.drawCircle(rightEye, radius * 0.15, black);
        // Boca redonda 'O' de sorpresa
        final surprisedMouth = Paint()
          ..color = const Color(0xFF212121)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + radius * 0.35),
            width: radius * 0.36,
            height: radius * 0.44,
          ),
          surprisedMouth,
        );

      case MinesweeperFaceState.won:
        // Gafas de sol negras
        final glassesPath = Path();
        final gTop = center.dy - radius * 0.35;
        final gBottom = center.dy + radius * 0.05;
        // Lente izquierdo
        glassesPath.moveTo(center.dx - radius * 0.75, gTop);
        glassesPath.lineTo(center.dx - radius * 0.05, gTop);
        glassesPath.lineTo(center.dx - radius * 0.12, gBottom);
        glassesPath.lineTo(center.dx - radius * 0.68, gBottom);
        glassesPath.close();
        // Lente derecho
        glassesPath.moveTo(center.dx + radius * 0.05, gTop);
        glassesPath.lineTo(center.dx + radius * 0.75, gTop);
        glassesPath.lineTo(center.dx + radius * 0.68, gBottom);
        glassesPath.lineTo(center.dx + radius * 0.12, gBottom);
        glassesPath.close();
        // Puente
        glassesPath.addRect(Rect.fromLTWH(
          center.dx - radius * 0.1,
          gTop + radius * 0.05,
          radius * 0.2,
          radius * 0.1,
        ));
        canvas.drawPath(glassesPath, black);

        // Sonrisa triunfante con colmillo / guiño
        final wonMouth = Rect.fromCircle(
          center: Offset(center.dx, center.dy + radius * 0.2),
          radius: radius * 0.45,
        );
        canvas.drawArc(wonMouth, 0.15 * math.pi, 0.7 * math.pi, false, mouthStroke);

      case MinesweeperFaceState.lost:
        // Ojos en X (derrota / mina)
        void drawX(Offset pt) {
          const d = 3.2;
          canvas.drawLine(pt + const Offset(-d, -d), pt + const Offset(d, d), mouthStroke);
          canvas.drawLine(pt + const Offset(-d, d), pt + const Offset(d, -d), mouthStroke);
        }
        drawX(leftEye);
        drawX(rightEye);
        // Boca triste / mueca
        final lostMouth = Rect.fromCircle(
          center: Offset(center.dx, center.dy + radius * 0.6),
          radius: radius * 0.45,
        );
        canvas.drawArc(lostMouth, 1.2 * math.pi, 0.6 * math.pi, false, mouthStroke);
    }
  }

  @override
  bool shouldRepaint(_SmileyPainter old) => old.state != state;
}
