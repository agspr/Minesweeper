import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/theme.dart';

/// El tablero teñido, vigilado por números.
///
/// El acento es ELEGIBLE, así que el tablero cambia de color sin que nadie
/// toque este código. Un tema nuevo —o retocar uno— puede acercar dos estados
/// hasta volverlos indistinguibles, y eso no lo cazaría ninguna prueba de las
/// otras: compila igual, no desborda, y el fallo solo se ve mirando.
///
/// Lo que se comprueba es la regla del paquete: **ningún estado con significado
/// puede depender solo del tono.** Aquí se mide el tono, y donde el margen es
/// estrecho a propósito se documenta cuál es el segundo canal.
void main() {
  /// Distancia euclídea en RGB. No es percepción humana fina, pero para
  /// "¿estos dos grises oscuros se confunden?" separa bien y no necesita
  /// dependencias.
  double dist(Color a, Color b) => sqrt(
    pow((a.r - b.r) * 255, 2) +
        pow((a.g - b.g) * 255, 2) +
        pow((a.b - b.b) * 255, 2),
  );

  /// Umbral: por debajo de esto, dos fondos oscuros se leen igual en un móvil
  /// a media luz. Sale de medir el peor par que había ANTES de teñir
  /// —pista contra misma cifra, 8,8— y de que teñir lo subiera a 25.
  const minima = 20.0;

  tearDown(() {
    NonaColors.current = SendaPalettes.menta;
    NonaColors.tinted = true;
  });

  for (final p in SendaPalettes.all) {
    group('tema ${p.name}', () {
      setUp(() {
        NonaColors.current = p;
        NonaColors.tinted = true;
      });

      test('las dos ayudas de orientación no se confunden entre sí', () {
        // Antes de teñir estaban a 8,8: eran el mismo gris a efectos
        // prácticos. Es el par que MÁS gana con el color.
        expect(
          dist(NonaColors.cellPeer, NonaColors.cellSameDigit),
          greaterThan(minima),
          reason: '${p.name}: fila/columna y misma cifra se ven igual',
        );
      });

      test('ninguna ayuda se confunde con la casilla normal', () {
        expect(dist(NonaColors.cellPeer, NonaColors.cell), greaterThan(minima));
        expect(
          dist(NonaColors.cellSameDigit, NonaColors.cell),
          greaterThan(minima),
        );
      });

      test('"misma cifra" no se confunde con "equivocada"', () {
        // El peor caso de este par es Coral, que comparte familia de tono con
        // el rojo de error. Si un tema nuevo lo bajara del umbral, "hay otro 7
        // aquí" se leería como "esto está mal".
        expect(
          dist(NonaColors.cellSameDigit, NonaColors.cellWrong),
          greaterThan(minima),
          reason: '${p.name}: la ayuda de misma cifra parece un error',
        );
      });

      test('la equivocada no sigue al tema: siempre el mismo rojo', () {
        final wrong = NonaColors.cellWrong;
        NonaColors.tinted = false;
        expect(
          NonaColors.cellWrong,
          wrong,
          reason: 'el fondo de error cambió con el tinte, y no debe',
        );
        expect(NonaColors.wrong, const Color(0xFFFF7A8A));
      });

      test('la seleccionada tiene borde: segundo canal frente a la errónea', () {
        // Este par SÍ queda justo con Coral (22,7 entre el chip y el rojo de
        // error) y es anterior al tinte. No se arregla con tono, se arregla
        // con el borde — así que lo que se comprueba es que el borde exista y
        // contraste, no que los fondos se separen.
        expect(
          dist(NonaColors.cellSelectedBorder, NonaColors.cellSelected),
          greaterThan(minima),
          reason: '${p.name}: el borde de la seleccionada no se ve',
        );
      });
    });
  }

  test('apagar el color devuelve TODO el cromo del tablero a los grises', () {
    // "Todo" incluye la casilla seleccionada. Se quedaba con el chip del tema
    // mientras el resto ya era gris, así que con el color apagado quedaba una
    // única casilla de color y el interruptor parecía a medio hacer.
    for (final p in SendaPalettes.all) {
      NonaColors.current = p;
      NonaColors.tinted = false;
      expect(NonaColors.cellPeer, const Color(0xFF1E1E26));
      expect(NonaColors.cellSameDigit, const Color(0xFF262029));
      expect(NonaColors.gridThin, const Color(0xFF26262E));
      expect(NonaColors.gridThick, const Color(0xFF4A4A58));
      expect(
        NonaColors.cellSelected,
        const Color(0xFF2C2C36),
        reason: '${p.name}: la seleccionada sigue teñida con el color apagado',
      );
    }
  });

  test('apagar el color NO toca el dígito escrito', () {
    // El límite del interruptor: apaga la decoración, no el acento de lo que
    // ha escrito quien juega. Eso distingue lo suyo de las pistas y no es
    // adorno.
    NonaColors.current = SendaPalettes.cobalto;
    NonaColors.tinted = false;
    expect(NonaColors.entered, SendaPalettes.cobalto.brand.accent);
  });

  test('con el color apagado la seleccionada conserva su borde', () {
    // Apagar el color no debe costar legibilidad: el borde es lo que separa
    // "seleccionada" de "equivocada", y esa distinción no es decorativa.
    NonaColors.tinted = false;
    expect(
      dist(NonaColors.cellSelectedBorder, NonaColors.cellSelected),
      greaterThan(minima),
    );
  });
}
