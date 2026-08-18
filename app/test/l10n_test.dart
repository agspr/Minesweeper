import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/l10n/app_localizations.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nona es bilingüe desde el primer día (diseño §0). Estas pruebas vigilan lo
/// que de verdad se rompe en una app traducida: que falte una cadena en un
/// idioma, que se cuele texto sin traducir, o que el plural esté mal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('los dos ficheros ARB', () {
    late Map<String, dynamic> es;
    late Map<String, dynamic> en;

    setUpAll(() {
      es = jsonDecode(File('lib/l10n/app_es.arb').readAsStringSync()) as Map<String, dynamic>;
      en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    });

    Set<String> keysOf(Map<String, dynamic> arb) =>
        arb.keys.where((k) => !k.startsWith('@')).toSet();

    test('el inglés no se deja ninguna clave del español', () {
      // Es el fallo clásico: se añade una cadena, se traduce a medias y en el
      // otro idioma sale la del idioma plantilla sin que nadie se entere.
      expect(
        keysOf(es).difference(keysOf(en)),
        isEmpty,
        reason: 'faltan estas claves en app_en.arb',
      );
    });

    test('el inglés no inventa claves que el español no tenga', () {
      expect(keysOf(en).difference(keysOf(es)), isEmpty);
    });

    test('ninguna traducción quedó idéntica por descuido', () {
      // Algunas coinciden legítimamente ("Nona", "Total"): se listan a mano,
      // así que cualquier OTRA que coincida sale a la luz.
      // "pts" es igual en los dos idiomas, igual que el nombre de la app y
      // "Total". Cualquier OTRA coincidencia es una traducción sin hacer.
      const coincidenOk = {'appName', 'breakdownTotal', 'shareScore'};
      final iguales = <String>[];
      for (final k in keysOf(es)) {
        if (coincidenOk.contains(k)) continue;
        if (es[k] == en[k]) iguales.add(k);
      }
      expect(iguales, isEmpty, reason: 'sin traducir de verdad: $iguales');
    });
  });

  group('cadenas generadas', () {
    Future<L> load(Locale locale) => L.delegate.load(locale);

    test('el español y el inglés cargan', () async {
      expect((await load(const Locale('es'))).appTagline, 'Sudoku del día');
      expect((await load(const Locale('en'))).appTagline, 'Daily Sudoku');
    });

    test('los plurales concuerdan en los dos idiomas', () async {
      final es = await load(const Locale('es'));
      final en = await load(const Locale('en'));
      expect(es.mistakeCount(1), '1 fallo');
      expect(es.mistakeCount(3), '3 fallos');
      expect(en.mistakeCount(1), '1 mistake');
      expect(en.mistakeCount(3), '3 mistakes');
      expect(es.hintCount(1), '1 pista');
      expect(es.hintCount(2), '2 pistas');
    });

    test('los marcadores de posición se sustituyen', () async {
      final es = await load(const Locale('es'));
      expect(es.menuDailyToday('Fácil'), 'Fácil · hoy');
      expect(es.breakdownCompleted(60), '60% completado');
    });
  });

  group('LocaleController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('por defecto sigue al sistema', () async {
      final c = LocaleController(await SharedPreferences.getInstance());
      expect(c.locale, isNull);
    });

    test('el ciclo recorre sistema → es → en → sistema', () async {
      // Los idiomas los pone el GameConfig: Nona tiene dos, CINCO tendrá uno.
      const supported = [Locale('es'), Locale('en')];
      final c = LocaleController(await SharedPreferences.getInstance());
      await c.cycle(supported);
      expect(c.locale, const Locale('es'));
      await c.cycle(supported);
      expect(c.locale, const Locale('en'));
      await c.cycle(supported);
      expect(c.locale, isNull, reason: 'vuelve a seguir al sistema');
    });

    test('la elección sobrevive a cerrar la app', () async {
      final prefs = await SharedPreferences.getInstance();
      await LocaleController(prefs).setLocale(const Locale('en'));
      expect(LocaleController(prefs).locale, const Locale('en'));
    });
  });

  testWidgets('la app se pinta en inglés al elegirlo', (tester) async {
    // La prueba de verdad: no que exista la traducción, sino que llegue a la
    // pantalla.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(L.of(context).menuPractice),
        ),
      ),
    );
    expect(find.text('Free play'), findsOneWidget);
    expect(find.text('Modo libre'), findsNothing);
  });
}
