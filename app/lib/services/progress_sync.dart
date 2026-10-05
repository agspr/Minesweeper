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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../game/day_key.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'progress_controller.dart';

class ProgressSync {
  ProgressSync({
    required this.progress,
    required this.auth,
    required this.uidOf,
    required this.store,
    required this.session,
    required this.prefs,
    this.onDeviceClaimed,
    this.alEstrenarSesion,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// La bandera del backfill vive aquí y no en el controlador: es un hecho de
  /// SINCRONIZACIÓN ("esta cuenta ya subió su histórico desde este aparato"),
  /// no de progreso.
  static const _kBackfilled = 'progress.daysBackfilled';

  final SharedPreferences prefs;

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

  /// Se llama justo después de reclamar el aparato, antes de leer nada.
  ///
  /// `claimDevice` borra lo GUARDADO de la cuenta anterior, pero lo que ya está
  /// cargado en memoria —la diaria— no se entera. Sin este aviso la cuenta
  /// nueva veía la partida de la otra marcada como hecha, y al abrirla ese
  /// resultado se anotaba en SU progreso. Un aviso y no el `DailyController`
  /// entero para que el sincronizador no dependa de la pantalla de juego. Es
  /// el mismo punto en que CINCO llama a `game.reloadFromPrefs()` (su main.dart).
  final void Function()? onDeviceClaimed;

  /// Se llama con la sesión ya reclamada —después de [onDeviceClaimed]— para
  /// traer lo que es de esta cuenta y no vive en el resumen: la diaria a medias
  /// (`PartidaEnLaNube`). DESPUÉS del reclamo y no antes, que es el orden que
  /// importa: traída antes, el reclamo la borraría; y sin reclamar, la cuenta
  /// nueva compararía contra el tablero de la anterior.
  final Future<void> Function(String uid)? alEstrenarSesion;
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
    // En el acto y antes de cualquier `await`: entre el borrado y la recarga
    // no puede colarse nada que lea o anote la partida de la cuenta anterior.
    onDeviceClaimed?.call();
    final traer = alEstrenarSesion;
    if (traer != null) unawaited(traer(uid));

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
    await _backfillDays(uid);
    await _pushDay(uid);
    // Y AQUÍ TERMINA: el resumen ya no se escribe desde el cliente — es la
    // mitad cliente del cierre del #3 (27-8-2026). Lo recalcula SOLO el
    // servidor desde los días crudos más `legacyPoints` (el residuo anterior a
    // que los días existieran). Mientras el cliente pudiera escribirlo,
    // cualquiera con su sesión podía ponerse los puntos que quisiera; y dos
    // escritores del mismo documento significaba que el que ganara podía
    // pisar al otro — pasó en producción. El cliente conserva tres cosas, y
    // no es contradicción: sembrar el doc VACÍO (decir "tengo este juego" es
    // del cliente; el servidor solo hace update para no resucitar borrados),
    // escribir los DÍAS (la materia prima), y LEER (adoptar la nube).
  }

  /// Sube UNA VEZ el histórico completo de días de este aparato.
  ///
  /// Es la migración del hallazgo #3 (go de André, 26-8-2026): los días crudos
  /// en la nube empezaron a existir con `writeDay`, así que el recálculo del
  /// servidor siempre salía corto — 150 puntos contra los 515 reales — y dos
  /// escritores del mismo resumen significaba que el que ganara podía pisar al
  /// otro. Subiendo el histórico REAL del teléfono, el servidor cuadra desde
  /// datos completos y puede pasar a ser la autoridad; el guardia de
  /// "nunca bajar" del servidor queda de cinturón para lo que este teléfono ya
  /// no tenga.
  ///
  /// La bandera se marca SOLO cuando todos los días subieron: marcada a medias
  /// sería no reintentar nunca, y el reintento es gratis porque cada escritura
  /// es un `set` con clave por día — idempotente. Lleva prefijo `progress.`
  /// (de cuenta): cambiar de cuenta la borra junto con los registros a los que
  /// se refiere.
  Future<void> _backfillDays(String uid) async {
    if (prefs.getBool(_kBackfilled) ?? false) return;
    final hoy = dayKeyFor(_clock());
    var todos = true;
    for (final r in progress.allRecords) {
      try {
        final json = r.toJson();
        await store.writeDay(uid, r.dayKey, json);
        // El día de HOY acaba de subir: dejar la huella evita que `_pushDay`
        // lo repita en esta misma pasada — cada escritura dispara un recálculo
        // que relee todos los días, y pagarlo dos veces por el mismo dato es
        // exactamente lo que la huella existe para impedir.
        if (r.dayKey == hoy) _ultimoDiaSubido = '$hoy=${json.toString()}';
      } catch (_) {
        todos = false;
      }
    }
    if (todos) await prefs.setBool(_kBackfilled, true);
  }

  void _onProgressChanged() {
    // Durante la adopción el propio `adoptCloud` avisa a los oyentes; escribir
    // aquí devolvería a la nube lo que se acaba de leer, y en medio de la
    // reconciliación. La escritura buena la hace `_onAuthChanged` al final.
    if (_reconciling) return;
    final uid = uidOf();
    if (uid == null) return;
    _pushDay(uid);
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
}
