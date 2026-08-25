/// La copia en la nube del progreso de Nona.
///
/// El teléfono manda: se juega sin cuenta y sin cobertura, y las preferencias
/// son la verdad. Firestore guarda un RESUMEN de ese progreso, y existe por
/// dos motivos, en este orden:
///
/// 1. **El marcador de amigos lo lee.** `users/{uid}/apps/nona` es lo único
///    que otra persona puede leer de tu progreso; sin escribirlo, cualquier
///    amistad te ve a cero para siempre.
/// 2. **Reinstalar no debería costar la racha.** Al estrenar sesión se lee
///    primero y, si la nube va por delante, se adopta.
///
/// ## Por qué el orden importa tanto
///
/// Escribir antes de leer es el fallo clásico de este patrón y no lo cazaría
/// ninguna prueba de desarrollo: en un teléfono recién instalado el resumen
/// local es cero, y una escritura al arrancar sesión pisaría con ceros el
/// documento bueno de alguien que lleva meses jugando. Por eso
/// [_onAuthChanged] LEE, adopta con [ProgressController.adoptCloud] —que solo
/// adopta si la nube va por delante en puntos— y solo después escribe.
///
/// ## Por qué falla en silencio
///
/// Hasta que exista la regla de `users/{uid}/apps/{juego}` (despliegue D1),
/// toda escritura aquí es `permission-denied`. No se enseña nada: es una copia
/// de seguridad, no una acción de quien juega, y un aviso de error por algo
/// que ni pidió ni puede arreglar solo asusta. Lo que sí queda es un
/// `debugPrint` en depuración.
library;

import 'package:flutter/foundation.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../game/day_key.dart';
import 'progress_controller.dart';

class ProgressSync {
  ProgressSync({
    required this.progress,
    required this.auth,
    required this.uidOf,
    required this.store,
    required this.session,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ProgressController progress;

  /// Quién avisa de que la sesión ha cambiado, y quién dice de quién es.
  ///
  /// Dos piezas en vez del `AuthController` entero a propósito: su `user` es un
  /// `User` de Firebase, un tipo que no se puede construir sin Firebase, y con
  /// él en la firma esta clase no la montaría ninguna prueba. Lo que de verdad
  /// necesita es "avísame" y "¿de quién es la sesión?".
  final Listenable auth;
  final String? Function() uidOf;

  final ProgressStore store;
  final SessionSync session;
  final DateTime Function() _clock;

  bool _attached = false;
  bool _reconciling = false;

  /// Último día subido, como `clave=json`, para no reescribir lo idéntico.
  ///
  /// Cada día escrito dispara `onDayRecorded` en el servidor, que relee TODOS
  /// los días del juego (contrato del resumen, PARIDAD §"El resumen por
  /// juego"). Reescribir un día sin cambios sería pagar ese recálculo por
  /// nada. En memoria y no en preferencias a propósito: tras reinstalar
  /// conviene reescribirlo una vez, que es barato y re-siembra el crudo.
  String? _ultimoDiaSubido;

  /// Empieza a escuchar. Idempotente: llamarlo dos veces no duplica avisos.
  void start() {
    if (_attached) return;
    _attached = true;
    auth.addListener(_onAuthChanged);
    progress.addListener(_onProgressChanged);
    _onAuthChanged();
  }

  void dispose() {
    if (!_attached) return;
    auth.removeListener(_onAuthChanged);
    progress.removeListener(_onProgressChanged);
    _attached = false;
  }

  /// Estreno de sesión: reclamar el aparato, leer, adoptar y escribir.
  Future<void> _onAuthChanged() async {
    final uid = uidOf();
    if (!session.shouldSync(uid) || uid == null) return;

    // ANTES de leer nada de la nube: si este teléfono era de otra cuenta, su
    // progreso local no es de quien acaba de entrar, y sin limpiarlo la
    // reconciliación se lo regalaría.
    session.claimDevice(uid);

    _reconciling = true;
    try {
      final cloud = await store.readSummary(uid);
      progress.adoptCloud(cloud);
    } catch (e) {
      // Leer puede fallar por reglas o por red. Adoptar es una MEJORA, no un
      // requisito: si no se puede, el teléfono sigue siendo la verdad.
      if (kDebugMode) debugPrint('ProgressSync: no se pudo leer la nube: $e');
    } finally {
      _reconciling = false;
    }
    await _pushDay(uid);
    await _push(uid);
  }

  void _onProgressChanged() {
    // Durante la adopción el propio `adoptCloud` avisa a los oyentes; escribir
    // aquí devolvería a la nube lo que se acaba de leer, y en medio de la
    // reconciliación. La escritura buena la hace `_onAuthChanged` al final.
    if (_reconciling) return;
    final uid = uidOf();
    if (uid == null) return;
    _pushDay(uid);
    _push(uid);
  }

  /// Sube el CRUDO del día de hoy, si existe y cambió desde la última subida.
  ///
  /// Es la mitad cliente del hallazgo #3: el servidor (`onDayRecorded`)
  /// recalcula el resumen desde estos días con la tabla de puntuación, y el
  /// `points` que va dentro es informativo — la autoridad ya no es este
  /// cliente. También es lo que hace RECONSTRUIBLE el historial: sin días en
  /// la nube, un cambio de aparato conserva la racha pero pierde el detalle
  /// diario (le pasó a CINCO antes de tener esto).
  ///
  /// Solo el día de HOY: `record()` corre al cerrar el puzle o al salir con
  /// parcial, siempre sobre la fecha actual, así que no hay días pasados que
  /// puedan cambiar. Y con moderación (contrato, cláusula 3): cada escritura
  /// dispara un recálculo que relee todos los días del juego.
  Future<void> _pushDay(String uid) async {
    final clave = dayKeyFor(_clock());
    final registro = progress.recordFor(clave);
    if (registro == null) return;

    final json = registro.toJson();
    final huella = '$clave=${json.toString()}';
    if (huella == _ultimoDiaSubido) return;

    try {
      await store.writeDay(uid, clave, json);
      _ultimoDiaSubido = huella;
    } catch (e) {
      // Igual que el resumen: copia de seguridad, no acción de quien juega.
      if (kDebugMode) debugPrint('ProgressSync: no se pudo subir el día: $e');
    }
  }

  Future<void> _push(String uid) async {
    final resumen = progress.summaryAsOf(_clock());

    // Un resumen SIN NADA no se publica, y no es una optimización.
    //
    // Dos cosas se rompen si se publica: (1) tras "Borrar Nona de tu cuenta"
    // el teléfono queda limpio, así que el primer aviso del progreso volvería a
    // CREAR el documento que el servidor acaba de borrar —vacío, pero
    // existiendo—; y (2) el marcador trata "tiene documento de progreso" como
    // prueba de que juega aquí, así que quien instale y no termine ni un puzle
    // saldría en la clasificación de sus amigos con un cero. Es el cero
    // mentiroso que el §15 prohíbe, por la puerta de atrás.
    //
    // Se comprueba `lastPlayedDay` además de los puntos porque un día a medias
    // puede dar cero puntos y aun así ser progreso de verdad.
    if (resumen.totalPoints == 0 && resumen.lastPlayedDay == null) return;

    try {
      await store.writeSummary(uid, resumen);
    } catch (e) {
      if (kDebugMode) debugPrint('ProgressSync: no se pudo escribir: $e');
    }
  }
}
