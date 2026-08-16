/// Generador de números pseudoaleatorios determinista y **estable para
/// siempre**.
///
/// No se usa `dart:math`'s `Random(seed)` a propósito: su algoritmo no está
/// especificado, así que una versión futura del SDK podría cambiarlo. Eso no
/// rompería el banco ya horneado (está comprometido en el repo), pero sí haría
/// irreproducible su regeneración: no se podría volver a generar el mismo
/// puzle a partir de la misma semilla para depurar un día concreto. Un
/// xorshift128 de 32 bits escrito aquí no cambia nunca.
///
/// Toda la aritmética va enmascarada a 32 bits para que el resultado no
/// dependa del tamaño de entero de la plataforma.
library;

class Prng {
  /// Siembra el estado con SplitMix32 a partir de [seed]: una semilla pequeña
  /// (0, 1, 2…) daría un estado casi todo ceros, y xorshift tarda miles de
  /// pasos en recuperarse de eso.
  Prng(int seed) {
    var x = seed & 0xFFFFFFFF;
    _s0 = _splitMix32(x = (x + 0x9E3779B9) & 0xFFFFFFFF);
    _s1 = _splitMix32(x = (x + 0x9E3779B9) & 0xFFFFFFFF);
    _s2 = _splitMix32(x = (x + 0x9E3779B9) & 0xFFFFFFFF);
    _s3 = _splitMix32((x + 0x9E3779B9) & 0xFFFFFFFF);
    // Un estado todo a cero es un punto fijo del xorshift: se quedaría ahí.
    if (_s0 | _s1 | _s2 | _s3 == 0) _s0 = 0x9E3779B9;
  }

  late int _s0, _s1, _s2, _s3;

  static int _splitMix32(int z) {
    var x = z & 0xFFFFFFFF;
    x = (x ^ (x >> 16)) & 0xFFFFFFFF;
    x = (x * 0x21F0AAAD) & 0xFFFFFFFF;
    x = (x ^ (x >> 15)) & 0xFFFFFFFF;
    x = (x * 0x735A2D97) & 0xFFFFFFFF;
    return (x ^ (x >> 15)) & 0xFFFFFFFF;
  }

  /// Siguiente entero de 32 bits sin signo.
  int next() {
    final t = (_s1 << 9) & 0xFFFFFFFF;
    _s2 ^= _s0;
    _s3 ^= _s1;
    _s1 ^= _s2;
    _s0 ^= _s3;
    _s2 ^= t;
    _s3 = ((_s3 << 11) | (_s3 >> 21)) & 0xFFFFFFFF;
    return _s0;
  }

  /// Entero en [0, max). Con rechazo, no con módulo: el módulo sesga los
  /// valores bajos, y ese sesgo se colaría en qué casillas se vacían.
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'Debe ser positivo');
    final limit = 0x100000000 - (0x100000000 % max);
    while (true) {
      final v = next();
      if (v < limit) return v % max;
    }
  }

  /// Baraja [list] en el sitio (Fisher-Yates).
  void shuffle(List<Object?> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}
