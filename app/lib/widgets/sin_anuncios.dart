/// «Quitar anuncios» fuera de Más: en el final de la diaria y junto al banner.
///
/// Copiado de CINCO 1.9 (`sin_anuncios.dart` allí). Hasta ahora la compra solo
/// vivía al final de Más, donde nadie mira. **Las dos entradas abren la misma
/// hoja**, con la compra y «Restaurar compras» juntas (André, 24-9-2026): quien
/// ya pagó en otro teléfono tiene que poder recuperarlo donde se le ofrece
/// pagar otra vez, no solo en Más.
///
/// Abrir la hoja no cobra nada: la tienda enseña su propia confirmación
/// después. Por eso ni la franja del banner ni el enlace del final lanzan la
/// compra de un toque: un toque perdido junto al banner no debe abrir la
/// tienda.
///
/// **Sin el evento `quitar_anuncios_tocado` de CINCO.** Allí lo declara su
/// política; la de Nona (§3.8) dice «estos y ninguno más», así que emitirlo
/// aquí sería recoger algo que no está declarado. Si se quiere medir, primero
/// la política.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// ¿Tiene sentido ofrecer la compra? Sin tienda o sin producto, no: un botón
/// que no puede cobrar es peor que ninguno. **Pura.**
bool sePuedeOfrecerSinAnuncios(PurchaseService compras) =>
    !compras.adsRemoved && compras.available;

/// Abre la hoja.
Future<void> abrirHojaSinAnuncios(
  BuildContext context, {
  required PurchaseService compras,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Sin esto la hoja se topa en 9/16 de la pantalla, y en un iPhone SE con
    // el texto al máximo había que desplazarla para llegar a comprar.
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NonaColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    constraints: BoxConstraints(
      maxWidth: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 420.0),
    ),
    builder: (_) => HojaSinAnuncios(compras: compras),
  );
}

/// La hoja: qué se compra, el precio de la tienda, y «Restaurar compras».
///
/// Se cierra sola en cuanto la compra (o la restauración) llega: lo que queda
/// debajo ya no tiene anuncios que quitar.
class HojaSinAnuncios extends StatefulWidget {
  const HojaSinAnuncios({super.key, required this.compras});

  final PurchaseService compras;

  @override
  State<HojaSinAnuncios> createState() => _HojaSinAnunciosState();
}

class _HojaSinAnunciosState extends State<HojaSinAnuncios> {
  /// Qué pidió el jugador por última vez, para saber qué gira y qué decir al
  /// acabar. La tienda no distingue: `busy` vale para las dos cosas.
  bool _restaurando = false;

  /// Restaurar terminó sin error y sin compra. La tienda no lo dice —si no hay
  /// nada, simplemente no contesta—, y sin esto el botón dejaba de girar y no
  /// pasaba nada, que se lee como «no funciona».
  bool _nadaQueRestaurar = false;

  bool _cerrada = false;

  PurchaseService get _compras => widget.compras;

  @override
  void initState() {
    super.initState();
    _compras.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _compras.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted || _cerrada) return;
    if (_compras.adsRemoved) {
      _cerrada = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      if (_restaurando && !_compras.busy) {
        _restaurando = false;
        _nadaQueRestaurar = _compras.error == null;
      }
    });
  }

  void _comprar() {
    setState(() {
      _restaurando = false;
      _nadaQueRestaurar = false;
    });
    _compras.buy();
  }

  void _restaurar() {
    setState(() {
      _restaurando = true;
      _nadaQueRestaurar = false;
    });
    _compras.restore();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final sl = SendaL.of(context);
    final ocupada = _compras.busy;
    final precio = _compras.price;
    // Una sola línea de estado, con su alto reservado: que aparezca un error o
    // el «no hay nada» no empuja los botones (nada se mueve bajo el dedo).
    final estado =
        _compras.error ?? (_nadaQueRestaurar ? l.noAdsNothingToRestore : null);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.noAdsTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: NonaColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sl.removeAdsBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: NonaColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: ocupada ? null : _comprar,
                style: FilledButton.styleFrom(
                  backgroundColor: NonaColors.accent,
                  disabledBackgroundColor: NonaColors.accent.withValues(
                    alpha: .55,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: ocupada && !_restaurando
                    ? _Girando(color: NonaColors.accentDeep)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          precio == null
                              ? sl.removeAds
                              : '${sl.removeAds} · $precio',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: NonaColors.accentDeep,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: ocupada ? null : _restaurar,
                child: ocupada && _restaurando
                    ? const _Girando(color: NonaColors.muted)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          sl.restorePurchases,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: NonaColors.muted,
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(
              height: 22,
              child: estado == null
                  ? null
                  : Text(
                      estado,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _compras.error == null
                            ? NonaColors.muted
                            : SendaColors.danger,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Girando extends StatelessWidget {
  const _Girando({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
  );
}

/// «Jugar sin anuncios · precio», debajo del botón principal del resultado.
///
/// **Se decide al abrir el final y no cambia de sitio.** El precio llega de la
/// tienda cuando llega: si el enlace apareciera en cuanto lo hace, lo de encima
/// se movería bajo el dedo. Así que o está desde el principio, o no está. Y si
/// la compra llega con el final abierto, el enlace se vuelve un «Listo» del
/// mismo alto.
class EnlaceSinAnuncios extends StatefulWidget {
  const EnlaceSinAnuncios({super.key, required this.compras});

  final PurchaseService compras;

  /// Alto fijo, el mínimo de un toque cómodo en iOS.
  static const alto = 44.0;

  @override
  State<EnlaceSinAnuncios> createState() => _EnlaceSinAnunciosState();
}

class _EnlaceSinAnunciosState extends State<EnlaceSinAnuncios> {
  late final bool _sale = sePuedeOfrecerSinAnuncios(widget.compras);

  @override
  Widget build(BuildContext context) {
    if (!_sale) return const SizedBox.shrink();
    final l = L.of(context);
    return ListenableBuilder(
      listenable: widget.compras,
      builder: (context, _) {
        final hecho = widget.compras.adsRemoved;
        return SizedBox(
          height: EnlaceSinAnuncios.alto,
          width: double.infinity,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: hecho
                ? Center(
                    key: const ValueKey('hecho'),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.noAdsDone,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: NonaColors.muted,
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    key: const ValueKey('oferta'),
                    onPressed: () =>
                        abrirHojaSinAnuncios(context, compras: widget.compras),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.noAdsLink(widget.compras.price ?? ''),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: NonaColors.accent,
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// La franja de «Quitar anuncios» encima del banner.
///
/// **Encima y no sobre él**: AdMob no deja tapar un anuncio, ni poner nada que
/// parezca su botón de cerrar —por eso no lleva ✕—. Y a un lado, pegado a la
/// derecha y solo tan ancho como su texto: el resto de la franja es aire entre
/// lo de encima y el anuncio, que es lo que evita tocar uno queriendo tocar el
/// otro.
///
/// **Su alto es fijo desde el primer frame**, llegue o no el producto de la
/// tienda: una franja que apareciera al cargar el precio empujaría hacia
/// arriba lo que haya encima. Sin producto, la franja está vacía. Con la
/// compra hecha se va, con el banner.
class FranjaSinAnuncios extends StatelessWidget {
  const FranjaSinAnuncios({
    super.key,
    required this.compras,
    this.visible = true,
  });

  final PurchaseService compras;

  /// Con false mide 0 y no enseña nada: debajo de un tablero no va. Sus 30 pt
  /// se los quitaría a la rejilla, que ya comparte el alto con el banner.
  final bool visible;

  static const alto = 30.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: compras,
      builder: (context, _) {
        if (!visible || compras.adsRemoved) return const SizedBox.shrink();
        final ofrece = sePuedeOfrecerSinAnuncios(compras);
        return Container(
          height: alto,
          width: double.infinity,
          color: NonaColors.appBg,
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: ofrece ? 1 : 0,
            child: !ofrece
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () =>
                        abrirHojaSinAnuncios(context, compras: compras),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, alto),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    // Topada en el techo de la familia (1,55, el que CINCO
                    // pone a toda su app): la franja mide 30 pt fijos, y Nona
                    // no topa la letra, así que al máximo no cabría.
                    child: Text(
                      SendaL.of(context).removeAds,
                      maxLines: 1,
                      textScaler: MediaQuery.textScalerOf(context)
                          .clamp(maxScaleFactor: SendaTextScale.max),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NonaColors.muted,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
