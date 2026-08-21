import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/theme.dart';
import 'package:nona/widgets/game_header.dart';

import 'helpers.dart';

/// La cabecera de partida: que el título esté CENTRADO y el chip sea estrecho.
///
/// Las dos cosas son la misma: el título se centra porque las ranuras
/// laterales miden lo mismo, y solo pueden medir lo mismo si el chip cabe en lo
/// que mide la X. Cuando el chip llevaba la frase entera —"sin errores", "3
/// errores (tope)"— empujaba al título fuera del centro y lo movía al llegar el
/// primer fallo.
void main() {
  const ancho = 402.0;

  Future<void> montar(
    WidgetTester tester, {
    Widget? trailing,
    String? subtitle,
  }) async {
    tester.view.physicalSize = const Size(ancho, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: GameHeader(
            title: 'Sudoku del día',
            subtitle: subtitle,
            onClose: () {},
            trailing: trailing,
          ),
        ),
      ),
    );
  }

  double centroDelTitulo(WidgetTester tester) =>
      tester.getCenter(find.text('SUDOKU DEL DÍA')).dx;

  testWidgets('el título va centrado en la PANTALLA, no en lo que sobre', (
    tester,
  ) async {
    await montar(tester);
    expect(centroDelTitulo(tester), closeTo(ancho / 2, 1.0));
  });

  testWidgets('el chip no mueve el título, ni al aparecer ni al crecer', (
    tester,
  ) async {
    // ESTE es el fallo que se arregló: con la frase dentro, pasar de cero
    // fallos a tres ensanchaba el chip y el título se iba a la izquierda a
    // mitad de partida.
    await montar(tester);
    final sinChip = centroDelTitulo(tester);

    await montar(
      tester,
      trailing: const HeaderChip(
        icon: Icons.close_rounded,
        count: 0,
        semanticsLabel: 'sin errores',
      ),
    );
    expect(centroDelTitulo(tester), closeTo(sinChip, 1.0));

    await montar(
      tester,
      trailing: const HeaderChip(
        icon: Icons.close_rounded,
        count: 12,
        semanticsLabel: '12 errores (tope)',
        highlight: true,
        capped: true,
      ),
    );
    expect(centroDelTitulo(tester), closeTo(sinChip, 1.0));
  });

  testWidgets('el chip va pegado al borde derecho', (tester) async {
    // Su ranura tiene que ser TENSA (`Expanded`), no floja: floja, la ranura se
    // encoge al ancho del chip y el sobrante se va detrás de él, así que el
    // chip se despega del borde. El título no se mueve —eso lo fija el flex de
    // la izquierda—, de modo que sin esta comprobación el fallo no lo ve nadie.
    await montar(
      tester,
      trailing: const HeaderChip(
        icon: Icons.close_rounded,
        count: 0,
        semanticsLabel: 'sin errores',
      ),
    );
    expect(tester.getTopRight(find.byType(HeaderChip)).dx, closeTo(ancho, 1.0));
  });

  testWidgets('el subtítulo tampoco lo descoloca', (tester) async {
    await montar(tester);
    final sinSubtitulo = centroDelTitulo(tester);
    await montar(tester, subtitle: 'Fácil');
    expect(centroDelTitulo(tester), closeTo(sinSubtitulo, 1.0));
    expect(find.text('FÁCIL'), findsOneWidget);
  });

  testWidgets('el chip enseña el número, no la frase', (tester) async {
    await montar(
      tester,
      trailing: const HeaderChip(
        icon: Icons.close_rounded,
        count: 3,
        semanticsLabel: '3 errores',
        highlight: true,
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('3 errores'), findsNothing);
    expect(
      find.byIcon(Icons.close_rounded),
      findsNWidgets(2),
    ); // la X y el chip
  });

  testWidgets('pero las palabras siguen ahí para quien no ve el chip', (
    tester,
  ) async {
    // Quitar la frase de la pantalla no puede quitarla de la accesibilidad: un
    // lector de pantalla tiene que decir "3 errores (tope)" y no "equis, tres".
    final handle = tester.ensureSemantics();
    await montar(
      tester,
      trailing: const HeaderChip(
        icon: Icons.close_rounded,
        count: 3,
        semanticsLabel: '3 errores (tope)',
        highlight: true,
        capped: true,
      ),
    );
    expect(find.bySemanticsLabel('3 errores (tope)'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'el tope se dice por RELLENO, que es lo que sustituye a la palabra',
    (tester) async {
      // El " (tope)" ya no cabe. Si el relleno dejara de cambiar, no quedaría
      // ninguna señal de que los fallos han dejado de restar.
      Color fondo(WidgetTester t) {
        final c = t.widget<Container>(
          find.descendant(
            of: find.byType(HeaderChip),
            matching: find.byType(Container),
          ),
        );
        return ((c.decoration! as BoxDecoration).color)!;
      }

      await montar(
        tester,
        trailing: const HeaderChip(
          icon: Icons.close_rounded,
          count: 3,
          semanticsLabel: '3',
          highlight: true,
        ),
      );
      final sumando = fondo(tester);

      await montar(
        tester,
        trailing: const HeaderChip(
          icon: Icons.close_rounded,
          count: 5,
          semanticsLabel: '5',
          highlight: true,
          capped: true,
        ),
      );
      expect(
        fondo(tester),
        isNot(sumando),
        reason: 'el chip topado se ve igual que uno que todavía resta',
      );
      expect(fondo(tester), NonaColors.wrong);
    },
  );
}
