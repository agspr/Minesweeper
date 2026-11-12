import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/theme.dart';
import 'package:nona/widgets/main_menu_title_tiles.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    NonaColors.current = NonaColors.defaultPalette;
  });

  testWidgets(
    'en inglés enseña MINE arriba (4) y SWEEPER abajo (7)',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: Center(child: MainMenuTitleTiles())),
          locale: const Locale('en'),
        ),
      );
      await tester.pump();

      expect(find.text('M'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      // 'E' aparece una vez en MINE y tres veces en SWEEPER (total 4)
      expect(find.text('E'), findsNWidgets(4));
    },
  );

  testWidgets(
    'en español enseña BUSCA arriba (5) y MINAS abajo (5)',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: Center(child: MainMenuTitleTiles())),
          locale: const Locale('es'),
        ),
      );
      await tester.pump();

      expect(find.text('B'), findsOneWidget);
      expect(find.text('U'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      // 'S' aparece en BUSCA y en MINAS (2 veces)
      expect(find.text('S'), findsNWidgets(2));
      // 'A' aparece en BUSCA y en MINAS (2 veces)
      expect(find.text('A'), findsNWidgets(2));
    },
  );

  testWidgets(
    'actualiza los colores del rótulo dinámicamente al cambiar el tema',
    (tester) async {
      final brandNotifier = ValueNotifier<SendaBrand>(
        SendaPalettes.cobalto.brand,
      );

      await tester.pumpWidget(
        ValueListenableBuilder<SendaBrand>(
          valueListenable: brandNotifier,
          builder: (context, brand, _) => SendaBrandScope(
            brand: brand,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates:
                  (testApp(const SizedBox()) as SendaBrandScope)
                      .child is MaterialApp
                  ? ((testApp(const SizedBox()) as SendaBrandScope).child
                            as MaterialApp)
                        .localizationsDelegates
                  : null,
              supportedLocales: const [Locale('es'), Locale('en')],
              home: const Scaffold(body: Center(child: MainMenuTitleTiles())),
            ),
          ),
        ),
      );
      await tester.pump();

      // Al cambiar a Lavanda, el widget se reconstruye con el acento lavanda
      NonaColors.current = SendaPalettes.lavanda;
      brandNotifier.value = SendaPalettes.lavanda.brand;
      await tester.pump();

      expect(find.text('M'), findsOneWidget);
    },
  );

  testWidgets(
    'provee etiqueta de accesibilidad completa para el lector de pantalla',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: Center(child: MainMenuTitleTiles())),
          locale: const Locale('es'),
        ),
      );
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(MainMenuTitleTiles));
      expect(semantics.label, 'Buscaminas');
    },
  );
}
