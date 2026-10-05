import 'package:flutter/material.dart';

import '../theme.dart';
import 'escenas_del_final.dart' show kColorDeRacha;

/// La racha que llevas con un amigo, en su fila de la Social: 🔥 y los días.
///
/// La de CINCO (`streak_chip.dart` allí), con los colores de Nona. **Viva**
/// —naranja— cuando los dos habéis jugado hoy; si falta alguno, apagada: la
/// racha sigue en pie, pero hoy todavía pide algo.
class ChipDeRachaDeAmigo extends StatelessWidget {
  const ChipDeRachaDeAmigo({
    super.key,
    required this.n,
    required this.yoJugue,
    required this.elJugo,
  });

  final int n;
  final bool yoJugue;
  final bool elJugo;

  bool get viva => yoJugue && elJugo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: viva ? 1 : .35,
          child: const Text('🔥', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 3),
        Text(
          '$n',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: viva ? kColorDeRacha : NonaColors.muted,
          ),
        ),
      ],
    );
  }
}
