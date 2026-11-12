import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../l10n/app_localizations.dart';

/// Rótulo del menú principal con mosaicos expresivos Material 3 Expressive.
///
/// Dos líneas de fichas superelípticas limpias con solo letras:
/// - En inglés: `MINE` (4 fichas) arriba y `SWEEPER` (7 fichas) abajo, centradas.
/// - En español: `BUSCA` (5 fichas) arriba y `MINAS` (5 fichas) abajo, centradas.
///
/// Con 4 y 7 fichas (o 5 y 5), un tamaño base ligeramente mayor (45–46dp en teléfonos)
/// le da al título presencia heroica y equilibrada con respecto a las tarjetas y el
/// botón de racha, sin saturar visualmente.
///
/// Gramática cromática reactiva al tema elegido (`SendaBrandScope`):
/// - Fichas destacadas: acento principal del tema activo (`brand.accent`,
///   Azul Cielo `#4FA8FF` en el tema principal Cobalto) con `brand.accentDeep`.
/// - Fichas neutras de tablero: pizarra oscura (`#242632`) con borde sutil
///   (`#3A4258`) y texto blanco nítido (`#F2F4FA`).
class MainMenuTitleTiles extends StatelessWidget {
  const MainMenuTitleTiles({super.key, this.tileSize});

  /// Tamaño base de cada ficha en teléfonos. Con 4/7 letras y 5/5 letras,
  /// 45.0 dp es proporcional, legible y estilizado.
  static const double defaultTileSize = 45.0;
  static const double defaultTileGap = 6.5;

  final double? tileSize;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final isEs = l.localeName == 'es';

    // Suscripción reactiva a SendaBrandScope para que cambiar el tema en "Más"
    // reconstruya inmediatamente el rótulo con la paleta activa.
    final brand = SendaBrandScope.of(context);
    final accent = brand.accent;
    final accentFg = brand.accentDeep;

    const darkBg = Color(0xFF242632);
    const darkFg = Color(0xFFF2F4FA);
    const darkBorder = Color(0xFF3A4258);

    final mqSize = MediaQuery.sizeOf(context);
    final shortest = mqSize.shortestSide;
    final effectiveTileSize =
        tileSize ??
        (shortest >= 700
            ? 52.0
            : shortest >= 540
            ? 48.0
            : defaultTileSize);
    final effectiveGap = effectiveTileSize * (defaultTileGap / defaultTileSize);

    final List<_TileData> row1Tiles;
    final List<_TileData> row2Tiles;

    if (isEs) {
      // Español: BUSCA (5 fichas) arriba, MINAS (5 fichas) abajo
      // Ritmo de acentos armónico en extremos y centro
      row1Tiles = [
        _TileData('B', accent, accentFg),
        _TileData('U', darkBg, darkFg, borderColor: darkBorder),
        _TileData('S', darkBg, darkFg, borderColor: darkBorder),
        _TileData('C', darkBg, darkFg, borderColor: darkBorder),
        _TileData('A', accent, accentFg),
      ];
      row2Tiles = [
        _TileData('M', darkBg, darkFg, borderColor: darkBorder),
        _TileData('I', accent, accentFg),
        _TileData('N', darkBg, darkFg, borderColor: darkBorder),
        _TileData('A', accent, accentFg),
        _TileData('S', darkBg, darkFg, borderColor: darkBorder),
      ];
    } else {
      // Inglés: MINE (4 fichas) arriba, SWEEPER (7 fichas) abajo
      // MINE: M y E en acento, I y N neutras oscuras
      row1Tiles = [
        _TileData('M', accent, accentFg),
        _TileData('I', darkBg, darkFg, borderColor: darkBorder),
        _TileData('N', darkBg, darkFg, borderColor: darkBorder),
        _TileData('E', accent, accentFg),
      ];
      // SWEEPER: S y R en extremos neutros, la primera E y la P neutras,
      // la W y la segunda E en acento, creando un balance rítmico y limpio
      row2Tiles = [
        _TileData('S', darkBg, darkFg, borderColor: darkBorder),
        _TileData('W', darkBg, darkFg, borderColor: darkBorder),
        _TileData('E', darkBg, darkFg, borderColor: darkBorder),
        _TileData('E', accent, accentFg),
        _TileData('P', darkBg, darkFg, borderColor: darkBorder),
        _TileData('E', darkBg, darkFg, borderColor: darkBorder),
        _TileData('R', accent, accentFg),
      ];
    }

    return Semantics(
      header: true,
      label: l.appName,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRow(row1Tiles, effectiveTileSize, effectiveGap),
              SizedBox(height: effectiveGap),
              _buildRow(row2Tiles, effectiveTileSize, effectiveGap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<_TileData> tiles, double size, double gap) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _TileView(data: tiles[i], size: size),
        ],
      ],
    );
  }
}

class _TileData {
  const _TileData(
    this.letter,
    this.bgColor,
    this.fgColor, {
    this.borderColor,
  });

  final String letter;
  final Color bgColor;
  final Color fgColor;
  final Color? borderColor;
}

class _TileView extends StatelessWidget {
  const _TileView({required this.data, required this.size});

  final _TileData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * (12.5 / 42.0);

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: data.bgColor,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
          side: data.borderColor != null
              ? BorderSide(color: data.borderColor!, width: 1.5)
              : BorderSide.none,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        data.letter,
        style: TextStyle(
          color: data.fgColor,
          fontSize: size * 0.50,
          fontWeight: FontWeight.w900,
          fontFamily: 'Figtree',
          height: 1.0,
        ),
      ),
    );
  }
}
