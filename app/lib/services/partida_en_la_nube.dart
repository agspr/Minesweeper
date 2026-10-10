/// La diaria a medias, en la nube: empezarla en un teléfono y terminarla en
/// otro.
///
/// Lo pidió André el 5-10-2026 («cuando cambio de aparato se pierde el sudoku
/// del día»). Solo subía el día TERMINADO —su resultado, en `days/`—, y el
/// tablero a medias vivía únicamente en el teléfono. Cambiar de teléfono, o
/// cerrar sesión y volver a entrar, lo dejaba en blanco: la diaria se podía
/// empezar de cero cuantas veces se quisiera, con lo aprendido y sin los
/// fallos. CINCO tuvo exactamente esto y lo arregló el 19-9-2026 (su
/// `partidaEnCurso_cinco`); esto es lo mismo para Nona.
///
/// ## Dónde
///
/// `users/{uid}/private/partidaEnCurso_nona`, que solo lee y escribe el dueño:
/// sin cambio de reglas. **No en `apps/nona/days/`**: escribir ahí dispara el
/// recálculo del servidor, que daría el día por jugado —puntos, racha, rachas
/// de amigos— con la partida a medias. Borrar la cuenta se lleva `private/*`
/// entero.
///
/// ## Cuándo
///
/// - **Sube** un momento después de cada jugada (no en cada una: se juntan),
///   en el acto al terminar, y al irse la app al fondo.
/// - **Baja** al estrenar sesión —tras reclamar el aparato, para que la de la
///   cuenta anterior no se cuele— y al volver la app a primer plano: así, el
///   teléfono que se dejó a medias recoge lo que se jugó en el otro.
/// - Qué se adopta lo decide `partidaQueSeAdopta`: solo la de hoy, nunca
///   hacia atrás, y los fallos nunca bajan.
///
/// Todo falla en silencio: es una copia, no algo que haya pedido quien juega.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../game/daily_controller.dart';

/// Dónde se lee y se escribe la partida. Una interfaz para poder probarlo sin
/// Firebase.
abstract interface class AlmacenDePartida {
  Future<Map<String, dynamic>?> leer(String uid);
  Future<void> escribir(String uid, Map<String, dynamic> partida);
}

class AlmacenDePartidaFirestore implements AlmacenDePartida {
  const AlmacenDePartidaFirestore();

  /// El nombre lleva el juego, como el de CINCO: el día que el servidor sepa
  /// borrarla al quitar un juego de la cuenta, la busca por ese nombre.
  static const kDocumento = 'partidaEnCurso_nona';

  DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc(kDocumento);

  @override
  Future<Map<String, dynamic>?> leer(String uid) async =>
      (await _doc(uid).get()).data();

  @override
  Future<void> escribir(String uid, Map<String, dynamic> partida) =>
      _doc(uid).set({...partida, 'updatedAt': FieldValue.serverTimestamp()});
}

class PartidaEnLaNube with WidgetsBindingObserver {
  PartidaEnLaNube({
    required this.daily,
    required this.uidOf,
    required this.almacen,
    this.espera = const Duration(milliseconds: 1500),
  });

  final DailyController daily;
  final String? Function() uidOf;
  final AlmacenDePartida almacen;

  /// Cuánto se juntan las jugadas antes de subir.
  final Duration espera;

  Timer? _pendiente;
  String? _ultimaSubida;
  bool _arrancado = false;

  void start() {
    if (_arrancado) return;
    _arrancado = true;
    daily.guardados.addListener(_alGuardar);
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    if (!_arrancado) return;
    _arrancado = false;
    _pendiente?.cancel();
    daily.guardados.removeListener(_alGuardar);
    WidgetsBinding.instance.removeObserver(this);
  }

  void _alGuardar() {
    _pendiente?.cancel();
    // Terminada, en el acto: es justo cuando alguien coge el otro teléfono.
    if (daily.estadoGuardado?['completa'] == true) {
      unawaited(_subir());
      return;
    }
    _pendiente = Timer(espera, () => unawaited(_subir()));
  }

  Future<void> _subir() async {
    _pendiente = null;
    final uid = uidOf();
    final estado = daily.estadoGuardado;
    if (uid == null || estado == null) return;
    // Sin una sola jugada no hay nada que llevar al otro teléfono, y sí mucho
    // que perder: abrir la diaria y salir guarda el reloj, y ese tablero en
    // blanco pisaba la partida del otro si este aún no la había traído (el
    // 10-10-2026 la nube de André tenía 0 jugadas y 12 segundos). Como CINCO,
    // que solo sube al jugar.
    if (estado['jugadas'] == 0) return;
    // Lo idéntico no se reescribe: irse al fondo sin haber jugado nada no
    // gasta una escritura.
    final huella = estado.toString();
    if (huella == _ultimaSubida) return;
    try {
      await almacen.escribir(uid, estado);
      _ultimaSubida = huella;
    } catch (e) {
      if (kDebugMode) debugPrint('PartidaEnLaNube: no se pudo subir: $e');
    }
  }

  /// Trae la partida de la nube y la adopta si va por delante. La llama el
  /// sincronizador al estrenar sesión, y este mismo al volver a primer plano.
  Future<void> traer(String uid) async {
    // Antes de leer, lo pendiente sube: si no, la jugada que aún no subió
    // perdería contra una copia más vieja que la de este teléfono.
    if (_pendiente != null) {
      _pendiente!.cancel();
      await _subir();
    }
    try {
      final remota = await almacen.leer(uid);
      if (remota == null) return;
      if (await daily.adoptar(remota)) {
        // Lo adoptado ya está en la nube: no hace falta volver a subirlo.
        _ultimaSubida = daily.estadoGuardado?.toString();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PartidaEnLaNube: no se pudo leer: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = uidOf();
    if (uid == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(traer(uid));
      case AppLifecycleState.inactive ||
          AppLifecycleState.paused ||
          AppLifecycleState.hidden:
        // Irse al fondo es lo último que se sabe de este teléfono: lo que
        // quede pendiente, sube ya.
        if (_pendiente != null) {
          _pendiente!.cancel();
          unawaited(_subir());
        }
      case AppLifecycleState.detached:
        break;
    }
  }
}
