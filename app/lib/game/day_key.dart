/// La clave del día y la semilla que le corresponde.
///
/// La clave es la fecha **local** del jugador (`2026-08-17`), igual que en
/// CINCO. Conviene decirlo claro porque es fácil suponer lo contrario: eso
/// significa que "el puzle es el mismo para todo el mundo" quiere decir *el
/// mismo por fecha local*, así que en Madrid empieza unas horas antes que en
/// San Juan. Es el comportamiento que CINCO ya tiene y encaja con un diario
/// tranquilo; lo que no vale es descubrirlo por accidente.
///
/// Nota: cuando el paquete `juegos_senda` esté extraído, esta lógica de fechas
/// se muda allí —la comparten todos los juegos— y este fichero desaparece.
library;

/// Clave del día en horario local, `yyyy-MM-dd`.
String dayKeyFor(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

/// La próxima medianoche LOCAL después de [now].
///
/// `DateTime(año, mes, día + 1)` y no `now.add(Duration(days: 1))`: sumar 24 h
/// mide tiempo transcurrido, y el día del cambio de hora dura 23 o 25, así que
/// el aviso caería una hora antes o después de la medianoche de verdad. El
/// constructor con el día desbordado lo normaliza Dart a la fecha local
/// correcta —también a fin de mes y de año—, que es justo lo que se quiere.
DateTime nextLocalMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);

/// Días de calendario entre dos fechas, inmune al horario de verano.
///
/// Restar `DateTime` locales y usar `.inDays` mide tiempo transcurrido, no
/// días: el día del cambio de primavera dura 23 h, `.inDays` da 0 y el puzle
/// del día se repetiría mientras las rachas se romperían solas. Pasar por UTC
/// —que no tiene horario de verano— cuenta días de calendario de verdad.
/// Tomado de CINCO (`game_logic.dart`), donde corrigió exactamente ese fallo.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Semilla del puzle de [dayKey].
///
/// Sale de la **fecha misma**, no de un contador, y eso es deliberado: cada día
/// es reproducible por separado. Se puede regenerar el 14 de marzo de 2028 para
/// depurarlo sin tocar ningún otro día, y hornear el banco en dos tandas da
/// exactamente el mismo resultado que hornearlo de una.
///
/// FNV-1a de 32 bits: pequeño, estable para siempre y sin dependencias. No hace
/// falta calidad criptográfica —solo que reparta— porque la aleatoriedad de
/// verdad la pone [Prng] a partir de esta semilla.
int seedForDayKey(String dayKey) {
  var hash = 0x811C9DC5;
  for (final unit in dayKey.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
