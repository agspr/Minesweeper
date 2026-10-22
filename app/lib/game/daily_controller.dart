/// La partida diaria: carga el puzle del banco, guarda el estado y lleva el
/// reloj.
///
/// Es **imposible de perder** (diseño §1): no hay límite de fallos ni pantalla
/// de derrota, así que aquí no existe ningún estado "perdido". Los fallos solo
/// bajan la puntuación, y la racha solo pide terminar.
///
/// El reloj se muestra para quien quiera picarse consigo mismo y **no puntúa**
/// (§1). Por eso no lleva ninguna defensa contra trampas: adelantar el reloj no
/// da nada. Se para al irse la app al fondo, para que mida tiempo de juego real
/// y no tiempo de calendario.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/haptics.dart';

import 'daily_bank.dart';
import 'day_key.dart';
import 'difficulty.dart';
import 'grid.dart';
import 'sudoku_board.dart';

/// Lo que la partida entrega a la puntuación (N4) cuando el día se cierra.
///
/// Deliberadamente tonto: solo datos. La tabla de puntos vive en `scoring.dart`
/// y este objeto es la costura, para que cambiar la puntuación no obligue a
/// tocar la partida ni al contrario.
class DailyOutcome {
  const DailyOutcome({
    required this.dayKey,
    required this.difficulty,
    required this.completed,
    required this.mistakes,
    required this.completionPercent,
    required this.seconds,
  });

  final String dayKey;
  final Difficulty difficulty;

  /// Terminado del todo. Es lo ÚNICO que da racha (§1).
  final bool completed;

  final int mistakes;
  final int completionPercent;
  final int seconds;
}

class DailyController extends ChangeNotifier {
  DailyController(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  // Prefijo 'game.' a propósito: es lo que SessionSync borra al cambiar de
  // cuenta en el aparato, para que la partida de una persona no se le atribuya
  // a otra.
  static const _kState = 'game.nona.today';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  SudokuBoard? _board;
  String? _dayKey;
  Difficulty? _difficulty;
  bool _ready = false;
  Object? _loadError;

  int _selected = -1;
  bool _notesMode = false;

  /// Jugadas hechas en el tablero de hoy: cifras, notas, borrar y deshacer.
  /// Solo sube, y viaja con la partida: es lo que dice cuál de dos teléfonos
  /// va más avanzado (ver [partidaQueSeAdopta]).
  int _jugadas = 0;

  /// Cada carga del tablero. Quien pinte la partida la compara para saber si
  /// el tablero que tiene delante es otro —por ejemplo, el que llegó de otro
  /// teléfono— aunque sea del mismo día.
  int _generacion = 0;
  int get generacion => _generacion;

  /// Avisa en cada guardado: es lo que sube la partida a la nube (ver
  /// `PartidaEnLaNube`). Aparte de `notifyListeners`, que salta también al
  /// mover la selección, que no es jugada.
  final ValueNotifier<int> guardados = ValueNotifier(0);

  /// Cuántas veces se tocó una cifra sobre un número ya puesto (ver
  /// `SudokuBoard.place`). Solo sube: la pantalla lo escucha para avisar de
  /// que hay que borrarlo primero.
  final ValueNotifier<int> intentosDeSobrescribir = ValueNotifier(0);

  int _accumulatedSeconds = 0;
  DateTime? _runningSince;

  SudokuBoard? get board => _board;
  String? get dayKey => _dayKey;
  Difficulty? get difficulty => _difficulty;

  /// `true` cuando el puzle del día está cargado y se puede jugar.
  bool get ready => _ready;

  /// El día pedido no estaba en el banco (horizonte agotado, reloj en otra era).
  Object? get loadError => _loadError;

  int get selected => _selected;
  bool get notesMode => _notesMode;
  bool get isComplete => _board?.isComplete ?? false;

  Duration get elapsed => Duration(
    seconds:
        _accumulatedSeconds +
        (_runningSince == null
            ? 0
            : _clock().difference(_runningSince!).inSeconds),
  );

  /// Carga el puzle de hoy. Idempotente por día.
  Future<void> load() async {
    final today = dayKeyFor(_clock());
    if (_ready && _dayKey == today) return;
    _ready = false;
    _loadError = null;
    notifyListeners();
    try {
      final puzzle = await DailyBank.forDayKey(today, _clock().year);
      _dayKey = today;
      _difficulty = puzzle.difficulty;
      final saved = _readSaved(today);
      _board = saved == null
          ? SudokuBoard.fromStrings(
              givens: puzzle.givens,
              solution: puzzle.solution,
            )
          : SudokuBoard.restore(
              givens: puzzle.givens,
              solution: puzzle.solution,
              saved: saved,
            );
      _accumulatedSeconds = (saved?['seconds'] as num?)?.toInt() ?? 0;
      _jugadas = (saved?['jugadas'] as num?)?.toInt() ?? 0;
      _generacion++;
      _runningSince = null;
      _selected = -1;
      _notesMode = false;
      _ready = true;
    } catch (e) {
      _loadError = e;
      _board = null;
    }
    notifyListeners();
  }

  /// Relee el día del reloj y recarga si ya cambió.
  ///
  /// Se llama al volver la app a primer plano. Un proceso móvil sobrevive a
  /// medianoche durante días sin problema, y sin esto seguiría mostrando el
  /// puzle de ayer y guardaría el resultado en la fecha equivocada. Mismo
  /// patrón que `refreshForToday` en CINCO, donde arregló justo ese fallo.
  Future<bool> refreshForToday() async {
    final today = dayKeyFor(_clock());
    if (today == _dayKey) return false;
    pauseTimer();
    await load();
    return true;
  }

  // ── Reloj ────────────────────────────────────────────────

  void startTimer() {
    if (_runningSince != null || isComplete) return;
    _runningSince = _clock();
  }

  void pauseTimer() {
    if (_runningSince == null) return;
    _accumulatedSeconds += _clock().difference(_runningSince!).inSeconds;
    _runningSince = null;
    _save();
  }

  // ── Entrada ──────────────────────────────────────────────

  void select(int cell) {
    if (cell < 0 || cell >= cellCount) return;
    // Volver a tocar la casilla ya seleccionada no cambia nada: ni repinta ni
    // vibra. Aquí es el único sitio que sabe si la selección se ha movido de
    // verdad, y por eso la háptica de selección sale de aquí y no del widget.
    if (cell == _selected) return;
    _selected = cell;
    NonaHaptics.select();
    notifyListeners();
  }

  void toggleNotesMode() {
    _notesMode = !_notesMode;
    notifyListeners();
  }

  /// Pulsa un dígito del numpad sobre la casilla seleccionada.
  /// Devuelve si la cifra contó como FALLO. El numpad lo necesita para no
  /// encabalgar su golpe con el patrón de error: la cifra entra al tocar la
  /// tecla, así que el veredicto ya no llega «después», al soltar.
  bool tapDigit(int digit) {
    final b = _board;
    if (b == null || _selected < 0 || isComplete) return false;
    if (b.ocupada(_selected) && (_notesMode || b.entries[_selected] != digit)) {
      // No es una jugada: ni cuenta, ni se guarda, ni cambia nada.
      intentosDeSobrescribir.value++;
      return false;
    }
    var fallo = false;
    _jugadas++;
    if (_notesMode) {
      b.toggleNote(_selected, digit);
    } else {
      // Un fallo se siente, no solo se ve: ver NonaHaptics.mistake.
      fallo = b.place(_selected, digit);
      if (fallo) NonaHaptics.mistake();
      // Terminar para el reloj: la partida ya está cerrada.
      if (b.isComplete) pauseTimer();
    }
    _save();
    notifyListeners();
    return fallo;
  }

  void erase() {
    final b = _board;
    if (b == null || _selected < 0 || isComplete) return;
    _jugadas++;
    b.erase(_selected);
    _save();
    notifyListeners();
  }

  void undo() {
    final b = _board;
    if (b == null || isComplete) return;
    _jugadas++;
    b.undo();
    _save();
    notifyListeners();
  }

  /// El resultado de hoy tal y como está ahora mismo.
  ///
  /// Sirve tanto al terminar (crédito completo) como al abandonar a medias
  /// (crédito parcial): la puntuación decide, esto solo informa.
  DailyOutcome? get outcome {
    final b = _board;
    if (b == null || _dayKey == null || _difficulty == null) return null;
    return DailyOutcome(
      dayKey: _dayKey!,
      difficulty: _difficulty!,
      completed: b.isComplete,
      mistakes: b.mistakes,
      completionPercent: b.completionPercent,
      seconds: elapsed.inSeconds,
    );
  }

  // ── Persistencia ─────────────────────────────────────────

  Map<String, dynamic>? _readSaved(String today) {
    final raw = _prefs.getString(_kState);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      // Guardado de otro día: no sirve, y devolverlo pondría las entradas de
      // ayer en el tablero de hoy.
      if (data['day'] != today) return null;
      return data;
    } catch (_) {
      return null; // Corrupto: se empieza limpio.
    }
  }

  /// La partida de hoy tal como se guarda: lo que sube a la nube.
  Map<String, dynamic>? get estadoGuardado {
    final b = _board;
    if (b == null || _dayKey == null) return null;
    return {
      'day': _dayKey,
      ...b.toJson(),
      'seconds': elapsed.inSeconds,
      'jugadas': _jugadas,
      'completa': b.isComplete,
    };
  }

  void _save() {
    final estado = estadoGuardado;
    if (estado == null) return;
    unawaited(_prefs.setString(_kState, jsonEncode(estado)));
    guardados.value++;
  }

  /// Adopta la partida de hoy que llega de otro teléfono, si va por delante
  /// (ver [partidaQueSeAdopta]). Devuelve si la adoptó.
  ///
  /// Escribe en las preferencias y recarga, sin pasar por [_save]: lo que se
  /// acaba de traer no tiene por qué volver a subir. Si el reloj corría —la
  /// partida estaba delante—, sigue corriendo con el tablero nuevo.
  Future<bool> adoptar(Map<String, dynamic> remota) async {
    final hoy = dayKeyFor(_clock());
    final local = _readSaved(hoy);
    final elegida = partidaQueSeAdopta(local: local, remota: remota, hoy: hoy);
    if (elegida == null) return false;
    final corria = _runningSince != null;
    pauseTimer();
    await _prefs.setString(_kState, jsonEncode(elegida));
    _ready = false;
    _dayKey = null;
    await load();
    if (corria) startTimer();
    return true;
  }

  /// Vuelve a leer las prefs para el día actual, si lo que hay en memoria ya
  /// no es lo guardado. La llama `ProgressSync` justo después de reclamar el
  /// aparato al estrenar sesión.
  ///
  /// **Estuvo sin llamador desde el primer commit**, con un comentario que
  /// decía que se llamaba tras un cambio de cuenta. `claimDevice` borraba la
  /// partida guardada, pero el tablero de la cuenta anterior seguía en memoria:
  /// la cuenta nueva veía la diaria de la otra marcada como hecha, y al
  /// abrirla, `GameScreen` anotaba ese resultado EN SU progreso —y tras un reinicio
  /// del proceso, que en un teléfono es lo normal, podía acabar en su nube—. Lo encontró André el 12-9-2026 al
  /// cambiar a la cuenta de pruebas y volver.
  ///
  /// **No recarga si lo guardado sigue ahí.** `claimDevice` se llama en cada
  /// estreno de sesión, también cuando entra la MISMA persona —al abrir la app
  /// la sesión llega un instante después del primer fotograma—, y solo borra
  /// si el aparato era de otra cuenta. Recargar a ciegas le quitaría la casilla
  /// seleccionada y le pararía el reloj a quien ya estuviera jugando. Si las
  /// prefs aún guardan la partida de hoy, lo que hay en memoria ES de este
  /// dueño: no hay nada que recargar.
  Future<void> reloadFromPrefs() async {
    final today = dayKeyFor(_clock());
    if (_ready && _dayKey == today && _readSaved(today) != null) return;
    _ready = false;
    _dayKey = null;
    await load();
  }

  // ── Medianoche ───────────────────────────────────────────

  Timer? _midnight;

  /// Pasa sola al día nuevo a medianoche, con la app delante.
  ///
  /// Volver de segundo plano ya relee el día (`refreshForToday`, desde el
  /// armazón), pero con la app ABIERTA a medianoche no hay vuelta de la que
  /// enterarse: el menú seguía enseñando la de ayer como hecha hasta cerrar la
  /// app. Es la otra mitad del fallo que vio André el 12-9-2026.
  ///
  /// Se arma a mano y no en el constructor a propósito: el controlador se
  /// construye en decenas de pruebas, y un temporizador de hasta 24 h armado en
  /// cada una las dejaría todas con un temporizador colgando. Lo arma el menú
  /// mientras se ve, y lo suelta al entrar en una partida o al desmontarse.
  ///
  /// Volver a llamarlo reprograma, no duplica. Por eso se llama también al
  /// volver de segundo plano: un temporizador que durmió con la app suspendida
  /// no es de fiar.
  void watchMidnight() {
    _midnight?.cancel();
    final now = _clock();
    // Sin margen, y no por descuido: si el temporizador saltara unos
    // milisegundos antes de la medianoche, `refreshForToday` leería todavía el
    // día de ayer y no haría nada, pero la reprogramación de abajo calcularía
    // una espera de esos pocos milisegundos y volvería a saltar ya en el día
    // nuevo. Se corrige solo; un margen fijo no añadiría nada que medir.
    final wait = nextLocalMidnight(now).difference(now);
    _midnight = Timer(wait, () {
      unawaited(refreshForToday());
      watchMidnight();
    });
  }

  void stopWatchingMidnight() {
    _midnight?.cancel();
    _midnight = null;
  }

  @override
  void dispose() {
    stopWatchingMidnight();
    pauseTimer();
    guardados.dispose();
    intentosDeSobrescribir.dispose();
    super.dispose();
  }
}

/// Qué partida queda en este teléfono cuando llega la de otro, o null si se
/// queda la que hay. **Pura.**
///
/// - Solo la de **hoy**: la de ayer a medias no dice nada del día de hoy.
/// - Una partida **terminada** aquí no se cambia por nada: ya está apuntada.
/// - Una terminada **allí** se adopta siempre: se resolvió en el otro.
/// - Si no, la que lleve **más jugadas**: el contador solo sube, así que es la
///   que va por delante —también si los dos teléfonos jugaron sin red—.
/// - **Los fallos nunca bajan**: se queda el mayor de los dos. Son lo único que
///   puntúa, y cambiar de teléfono no puede servir para borrarlos.
/// - De la nube se queda **solo lo que guarda [DailyController.estadoGuardado]**.
///   El documento trae además el `updatedAt` del servidor, un `Timestamp` que
///   `jsonEncode` no sabe escribir: copiado entero, `adoptar` fallaba con CADA
///   partida de verdad, en silencio, y ningún aparato adoptaba nunca la del
///   otro (André, 10-10-2026: «progress isn't syncing on my tablet»). Las
///   pruebas no lo vieron porque su nube fingida no ponía la fecha.
Map<String, dynamic>? partidaQueSeAdopta({
  required Map<String, dynamic>? local,
  required Map<String, dynamic> remota,
  required String hoy,
}) {
  if (remota['day'] != hoy) return null;
  remota = {
    for (final k in clavesDeLaPartida)
      if (remota.containsKey(k)) k: remota[k],
  };
  final localDeHoy = local != null && local['day'] == hoy ? local : null;
  if (localDeHoy == null) return remota;
  if (localDeHoy['completa'] == true) return null;
  int n(Object? x) => (x as num?)?.toInt() ?? 0;
  final adelante =
      remota['completa'] == true ||
      n(remota['jugadas']) > n(localDeHoy['jugadas']);
  if (!adelante) return null;
  final fallos = n(remota['mistakes']) > n(localDeHoy['mistakes'])
      ? n(remota['mistakes'])
      : n(localDeHoy['mistakes']);
  return {...remota, 'mistakes': fallos};
}

/// Las claves de [DailyController.estadoGuardado] (`entries`, `notes` y
/// `mistakes` vienen de `SudokuBoard.toJson`). Una clave nueva allí que no
/// esté aquí no viajaría; la prueba de la nube compara las dos.
@visibleForTesting
const clavesDeLaPartida = {
  'day',
  'entries',
  'notes',
  'mistakes',
  'seconds',
  'jugadas',
  'completa',
};
