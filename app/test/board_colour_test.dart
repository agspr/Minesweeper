import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/theme.dart';

/// El tablero teñido, vigilado por números.
///
/// El acento es ELEGIBLE, así que el tablero cambia de color sin que nadie
/// toque este código. Un tema nuevo —o retocar uno— puede acercar dos estados
/// hasta volverlos indistinguibles, y eso no lo cazaría ninguna otra prueba:
/// compila igual, no desborda, y el fallo solo se ve mirando.
///
/// ## Por qué comprueba TODAS las parejas y no unas cuantas
///
/// La primera versión enumeraba a mano cuatro parejas que me parecían las
/// arriesgadas. Eso es una lista negra: cubre lo que a alguien se le ocurrió
/// temer, y un estado nuevo entra sin que lo mire nadie. De diez parejas que
/// existen, comprobaba cuatro.
///
/// Ahora la invariante es de lista blanca: **todo par de estados que se
/// distinga por TONO tiene que superar el umbral**, y el bucle las recorre
/// todas. Añadir un estado al mapa lo compara automáticamente contra los
/// demás.
///
/// (La forma me la corrigió el agente de CINCO, que me pilló proponiéndole a
/// él una lista negra para su generador de páginas legales.)
void main() {
  /// Distancia euclídea en RGB. No es percepción humana fina, pero para
  /// "¿estos dos grises oscuros se confunden?" separa bien.
  double dist(Color a, Color b) => sqrt(
    pow((a.r - b.r) * 255, 2) +
        pow((a.g - b.g) * 255, 2) +
        pow((a.b - b.b) * 255, 2),
  );

  /// Por debajo de esto, dos fondos oscuros se leen igual en un móvil a media
  /// luz. El peor par real que NO está exento es 25,4 (fila/columna contra
  /// misma cifra, con Cobalto), así que 20 deja margen sin volverse
  /// decorativo.
  const minima = 20.0;

  tearDown(() {
    NonaColors.current = NonaColors.defaultPalette;
    NonaColors.tinted = true;
  });

  /// Los fondos que se distinguen SOLO por tono.
  ///
  /// La casilla seleccionada NO está aquí, y no por olvido: es la única que
  /// lleva borde, así que su canal es la PRESENCIA y no el tono. Medida por
  /// tono llega a quedarse a 12,8 de la fila/columna con Lavanda, y da igual,
  /// porque el borde la separa de todo. Se comprueba aparte, más abajo.
  Map<String, Color> fondosPorTono() => {
    'normal': NonaColors.cell,
    'fila/columna/caja': NonaColors.cellPeer,
    'misma cifra': NonaColors.cellSameDigit,
    'equivocada': NonaColors.cellWrong,
  };

  /// Los dígitos.
  Map<String, Color> digitos() => {
    'pista': NonaColors.given,
    'escrito': NonaColors.entered,
    'equivocado': NonaColors.wrong,
    'anotación': NonaColors.note,
  };

  /// Parejas que pueden estar cerca en tono PORQUE tienen un segundo canal.
  /// Cada excepción dice cuál es; una excepción sin canal es un fallo
  /// disfrazado.
  const exentas = <String, String>{
    // Con Coral el acento (#FF8A93) y el rojo de error (#FF7A8A) son el mismo
    // color a ojo, y la pista lleva el acento en negrita, igual que lo
    // equivocado. Lo que las separa es dónde están: un dígito equivocado solo
    // existe sobre `cellWrong`, y ese fondo se mide contra todos los demás en
    // `fondosPorTono`. Ver sudoku_board_view.dart.
    'pista|equivocado': 'fondo rojo de la casilla equivocada',
  };

  bool exenta(String a, String b) =>
      exentas.containsKey('$a|$b') || exentas.containsKey('$b|$a');

  void todasLasParejas(Map<String, Color> st, String tema, String modo) {
    final ks = st.keys.toList();
    for (var i = 0; i < ks.length; i++) {
      for (var j = i + 1; j < ks.length; j++) {
        if (exenta(ks[i], ks[j])) continue;
        expect(
          dist(st[ks[i]]!, st[ks[j]]!),
          greaterThan(minima),
          reason: '$tema $modo: "${ks[i]}" y "${ks[j]}" se ven igual',
        );
      }
    }
  }

  for (final p in SendaPalettes.all) {
    for (final tinted in [true, false]) {
      final modo = tinted ? 'en color' : 'en gris';

      group('${p.name} · $modo', () {
        setUp(() {
          NonaColors.current = p;
          NonaColors.tinted = tinted;
        });

        test('todos los fondos se distinguen entre sí', () {
          todasLasParejas(fondosPorTono(), p.name, modo);
        });

        test('todos los dígitos se distinguen entre sí', () {
          todasLasParejas(digitos(), p.name, modo);
        });

        test('la seleccionada tiene borde visible: ese es su canal', () {
          // Está exenta de la comparación por tono, así que su segundo canal
          // TIENE que existir. Si el borde dejara de verse, la exención se
          // quedaría sin nada detrás.
          expect(
            dist(NonaColors.cellSelectedBorder, NonaColors.cellSelected),
            greaterThan(minima),
            reason: '${p.name} $modo: el borde de la seleccionada no se ve',
          );
          expect(
            dist(NonaColors.cellSelectedBorder, NonaColors.cell),
            greaterThan(minima),
            reason: '${p.name} $modo: el borde no se ve contra el tablero',
          );
        });

        test('lo equivocado nunca sigue al tema', () {
          // El único estado que no puede depender de una elección de quien
          // juega: rojo, siempre el mismo, con tema y sin tema.
          expect(NonaColors.cellWrong, const Color(0xFF3A1218));
          expect(NonaColors.wrong, const Color(0xFFFF7A8A));
        });
      });
    }
  }

  test('apagar el color devuelve TODO el cromo del tablero a los grises', () {
    for (final p in SendaPalettes.all) {
      NonaColors.current = p;
      NonaColors.tinted = false;
      expect(NonaColors.cellPeer, const Color(0xFF24242E));
      expect(NonaColors.cellSameDigit, const Color(0xFF33333F));
      expect(NonaColors.gridThin, const Color(0xFF26262E));
      expect(NonaColors.gridThick, const Color(0xFF4A4A58));
      expect(
        NonaColors.cellSelected,
        const Color(0xFF2C2C36),
        reason: '${p.name}: la seleccionada sigue teñida con el color apagado',
      );
    }
  });

  test('apagar el color NO toca los dígitos', () {
    // El límite del interruptor: apaga la decoración, no el color de los
    // números. Pistas, escritos y teclado siguen al tema con el color apagado.
    NonaColors.current = SendaPalettes.cobalto;
    NonaColors.tinted = false;
    expect(NonaColors.given, SendaPalettes.cobalto.brand.accent);
    expect(NonaColors.keyDigitFg, SendaPalettes.cobalto.brand.accent);
    expect(
      NonaColors.entered,
      Color.lerp(SendaPalettes.cobalto.brand.accent, Colors.white, 0.55),
    );
  });

  test('lo escrito es el acento aclarado, no otro color', () {
    // Lo escrito tiene que seguir pareciendo "del tema": más claro que la
    // pista, pero de la misma familia. Y distinto de la pista por brillo, que
    // es el canal que acompaña al peso.
    for (final p in SendaPalettes.all) {
      NonaColors.current = p;
      expect(
        dist(NonaColors.entered, NonaColors.given),
        greaterThan(minima),
        reason: '${p.name}: lo escrito se confunde con la pista',
      );
      expect(
        NonaColors.entered.computeLuminance(),
        greaterThan(NonaColors.given.computeLuminance()),
        reason: '${p.name}: lo escrito tiene que ser MÁS claro que la pista',
      );
    }
  });

  test('cada excepción declara su segundo canal', () {
    // Una excepción sin motivo escrito es un fallo esperando. Si alguien añade
    // una pareja aquí para que deje de fallar, tiene que decir por qué se
    // distingue — y esa es justo la conversación que hay que tener.
    for (final e in exentas.entries) {
      expect(
        e.value.trim(),
        isNotEmpty,
        reason: '${e.key} está exenta sin declarar su canal',
      );
    }
  });
}
