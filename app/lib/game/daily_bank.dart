/// Acceso al banco de puzles diarios horneado en `assets/bank/`.
///
/// El banco viene comprometido en el repo, un fichero por año, para que el
/// puzle de una fecha sea idéntico en todos los dispositivos y versiones (ver
/// `tools/bake_bank.dart`). Aquí solo se lee.
///
/// Se carga **por año y de forma perezosa**: son ~120 KB por año y no hay
/// motivo para meter cinco en memoria cuando se juega un día. El año en curso
/// se queda en caché, así que abrir la diaria dos veces no vuelve a leer nada.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'day_key.dart';
import 'difficulty.dart';

class DailyPuzzle {
  const DailyPuzzle({
    required this.dayKey,
    required this.givens,
    required this.solution,
    required this.difficulty,
    required this.clues,
    this.start = -1,
  });

  final String dayKey;

  /// Casilla de salida segura del día (siempre un `0`), o -1 si no la hay.
  final int start;

  /// 81 caracteres, '.' en las casillas vacías.
  final String givens;

  /// 81 dígitos. Va con el puzle porque la puntuación necesita saber si una
  /// casilla es un fallo **en el momento de escribirla** (diseño §4), y sin la
  /// solución a mano eso obligaría a resolver en caliente en cada pulsación.
  final String solution;

  final Difficulty difficulty;
  final int clues;

  /// Casillas que el jugador tiene que rellenar. Es el denominador del
  /// porcentaje de avance con el que se calcula el crédito parcial.
  int get emptyCells => difficulty.cellCount - clues;
}

/// Un día pedido que no está en el banco. Pasa si el horizonte horneado se
/// agota (el banco cubre 2026–2030) o si el reloj del aparato está en otra era.
class DayNotInBankException implements Exception {
  DayNotInBankException(this.dayKey);
  final String dayKey;

  @override
  String toString() =>
      'El día $dayKey no está en el banco. ¿Hay que hornear más años?';
}

abstract final class DailyBank {
  static final Map<int, Map<String, dynamic>> _years = {};

  /// Para pruebas: permite inyectar un año sin tocar los assets.
  static void debugSeedYear(int year, Map<String, dynamic> entries) =>
      _years[year] = entries;

  static void debugClear() => _years.clear();

  /// El puzle de [date] (fecha local del jugador).
  static Future<DailyPuzzle> forDate(DateTime date) =>
      forDayKey(dayKeyFor(date), date.year);

  static Future<DailyPuzzle> forDayKey(String dayKey, int year) async {
    final entries = _years[year] ??= await _loadYear(year);
    final raw = entries[dayKey];
    if (raw == null) throw DayNotInBankException(dayKey);
    final m = (raw as Map).cast<String, dynamic>();
    final solution = m['solution'] as String;
    return DailyPuzzle(
      dayKey: dayKey,
      givens: (m['givens'] as String?) ?? '.' * solution.length,
      solution: solution,
      difficulty: Difficulty.values.byName(m['difficulty'] as String),
      clues: (m['clues'] as num?)?.toInt() ?? 0,
      start: (m['start'] as num?)?.toInt() ?? -1,
    );
  }

  static Future<Map<String, dynamic>> _loadYear(int year) async {
    try {
      final text = await rootBundle.loadString('assets/bank/$year.json');
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      // Año fuera del horizonte horneado: se trata como "no está", que es lo
      // que el llamante ya sabe manejar.
      //
      // El catch va SIN tipo a propósito. Antes era `on Exception` y no valía:
      // cuando falta un asset, rootBundle lanza FlutterError, que hereda de
      // Error y NO de Exception, así que se escapaba y subía sin capturar. Lo
      // pilló la prueba de "un día fuera del banco". Cualquier fallo al leer un
      // año significa lo mismo para quien llama —ese día no está—, así que se
      // traga todo y se responde vacío.
      return const {};
    }
  }
}
