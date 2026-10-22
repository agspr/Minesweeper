import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../theme.dart';

/// Un aviso corto que sube desde abajo y se va solo. Lo usa la casilla
/// ocupada: «Usa el botón de borrar para quitarlo primero».
///
/// **No intercepta toques** (`IgnorePointer`) y sale sobre el borde de abajo
/// del TABLERO, nunca sobre el numpad: tapa a lo sumo un trozo del tablero un
/// par de segundos, pero no la tecla Borrar que el propio aviso manda tocar.
/// Un `SnackBar` saldría justo encima de ella.
///
/// Se dispara cada vez que [disparo] cambia; si vuelve a cambiar con el aviso
/// a la vista, el plazo se reinicia en vez de apilar otro.
class AvisoFlotante extends StatefulWidget {
  const AvisoFlotante({
    super.key,
    required this.disparo,
    required this.texto,
    this.icono,
    this.ocultarCon,
    this.duracion = const Duration(milliseconds: 2500),
  });

  final ValueListenable<int> disparo;
  final String texto;
  final IconData? icono;
  final Duration duracion;

  /// Se va en cuanto esto cambia, sin esperar al plazo: en un teléfono
  /// pequeño (iPhone SE) no hay hueco entre tablero y numpad, y el aviso tapa
  /// la fila de abajo, quizá la casilla que se va a corregir. Ya cumplió en
  /// cuanto se hace otra cosa —borrar, elegir otra casilla—, así que deja
  /// verla. La pantalla le pasa su partida, que NO avisa de un toque
  /// rechazado: si no, se iría al mismo tiempo que sale.
  final Listenable? ocultarCon;

  @override
  State<AvisoFlotante> createState() => _AvisoFlotanteState();
}

class _AvisoFlotanteState extends State<AvisoFlotante> {
  bool _visible = false;
  Timer? _ocultar;

  @override
  void initState() {
    super.initState();
    widget.disparo.addListener(_mostrar);
    widget.ocultarCon?.addListener(_ocultarYa);
  }

  @override
  void didUpdateWidget(AvisoFlotante old) {
    super.didUpdateWidget(old);
    if (old.disparo != widget.disparo) {
      old.disparo.removeListener(_mostrar);
      widget.disparo.addListener(_mostrar);
    }
    if (old.ocultarCon != widget.ocultarCon) {
      old.ocultarCon?.removeListener(_ocultarYa);
      widget.ocultarCon?.addListener(_ocultarYa);
    }
  }

  @override
  void dispose() {
    widget.disparo.removeListener(_mostrar);
    widget.ocultarCon?.removeListener(_ocultarYa);
    _ocultar?.cancel();
    super.dispose();
  }

  void _ocultarYa() {
    _ocultar?.cancel();
    if (_visible && mounted) setState(() => _visible = false);
  }

  void _mostrar() {
    _ocultar?.cancel();
    _ocultar = Timer(widget.duracion, () {
      if (mounted) setState(() => _visible = false);
    });
    if (!_visible) setState(() => _visible = true);
    // Quien no ve la pantalla también tiene que enterarse de por qué la tecla
    // no hizo nada.
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.texto,
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: SendaTextScale.max);
    return IgnorePointer(
      // Sale DE DEBAJO del borde: recortado, no aparece flotando de la nada.
      child: ClipRect(
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 1.2),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Center(
                child: ExcludeSemantics(
                  // Ya se anuncia al salir: leído otra vez al recorrer la
                  // pantalla, sería un aviso viejo.
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: NonaColors.sheet,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NonaColors.accentChip),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icono != null) ...[
                          Icon(
                            widget.icono,
                            size: 18,
                            color: NonaColors.accent,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            widget.texto,
                            textScaler: escala,
                            style: const TextStyle(
                              color: NonaColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
