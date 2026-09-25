import 'package:flutter/widgets.dart';

import '../game/difficulty.dart';
import '../l10n/app_localizations.dart';

/// Etiqueta de dificultad, traducida. Vive suelta porque la usan varias
/// pantallas y no merece vivir dentro de ninguna: estaba en la tarjeta del
/// resultado, que se fue al llegar las escenas del final.
String difficultyLabel(BuildContext context, Difficulty d) {
  final l = L.of(context);
  return switch (d) {
    Difficulty.easy => l.difficultyEasy,
    Difficulty.medium => l.difficultyMedium,
    Difficulty.hard => l.difficultyHard,
  };
}
