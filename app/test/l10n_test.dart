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
      es = jsonDecode(
        File('lib/l10n/app_es.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      en = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
    });

    Set<String> keysOf(Map<String, dynamic> arb) =>
        arb.keys.where((k) => !k.startsWith('@')).toSet();

    test('los temas se leen en el idioma de la pantalla', () {
      // Salían en castellano dentro de una pantalla en inglés: "Cobalto" no es
      // una marca, es "Cobalt" mal escrito para quien lee en inglés. Lo vio
      // André en su teléfono.
      //
      // Y lo que se GUARDA es el id, no la etiqueta: si dependiera del nombre
      // visible, cambiar de idioma le quitaría el tema elegido.
      expect(SendaPalettes.cobalto.id, 'cobalto');
      expect(
        SendaPalettes.byId('Cobalto', fallback: SendaPalettes.menta),
        SendaPalettes.cobalto,
        reason:
            'lo guardado por versiones anteriores tiene que seguir valiendo',
      );
    });

    test('el castellano de Nona cumple el de la familia', () {
      // Las reglas están en docs/CASTELLANO.md y las comprueba el paquete, así
      // que aquí basta una línea. Sin esto, una regla de estilo la cumple
      // quien haya leído el documento — y Nona la escribe otro agente.
      final fallos = SendaCopyRules.violations(es);
      expect(fallos, isEmpty, reason: fallos.join('\n'));
    });

    test('la fila "Acerca de" se llama igual en los dos juegos', () {
      expect(es['aboutNona'], 'Acerca de Buscaminas');
      expect(en['aboutNona'], startsWith('About '));
    });

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
      const coincidenOk = {'breakdownTotal', 'shareScore'};
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
      expect((await load(const Locale('es'))).appName, 'Buscaminas');
      expect((await load(const Locale('en'))).appName, 'Minesweeper');
      expect((await load(const Locale('es'))).appTagline, 'Reto diario');
      expect((await load(const Locale('en'))).appTagline, 'Daily Challenge');
    });

    test('los plurales concuerdan en los dos idiomas', () async {
      final es = await load(const Locale('es'));
      final en = await load(const Locale('en'));
      expect(es.mistakeCount(1), '1 error');
      expect(es.mistakeCount(3), '3 errores');
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

    // El selector es un segmentado ES/EN, así que siempre hay que saber qué
    // pastilla encender — incluso cuando nadie ha elegido nada.
    group('resolvedCode', () {
      // Los idiomas los pone el GameConfig: Nona tiene dos, CINCO tendrá uno.
      const supported = [Locale('es'), Locale('en')];

      test('sin elegir nada, sigue al teléfono', () async {
        final c = LocaleController(await SharedPreferences.getInstance());
        expect(c.resolvedCode(const Locale('en'), supported), 'en');
        expect(c.resolvedCode(const Locale('es'), supported), 'es');
        expect(c.locale, isNull, reason: 'resolver no debe elegir por nadie');
      });

      test('un idioma elegido manda sobre el del teléfono', () async {
        final c = LocaleController(await SharedPreferences.getInstance());
        await c.setLocale(const Locale('es'));
        expect(c.resolvedCode(const Locale('en'), supported), 'es');
      });

      test(
        'un teléfono en un idioma que el juego no habla cae en el primero',
        () async {
          // Alemán: ni español ni inglés. Cae en español, que es lo mismo que
          // resolvería Flutter — si aquí saliera otra cosa, el segmentado
          // enseñaría encendido un idioma distinto del que se está leyendo.
          final c = LocaleController(await SharedPreferences.getInstance());
          expect(c.resolvedCode(const Locale('de'), supported), 'es');
        },
      );
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
        home: Builder(builder: (context) => Text(L.of(context).menuPractice)),
      ),
    );
    expect(find.text('Practice mode'), findsOneWidget);
    expect(find.text('Modo práctica'), findsNothing);
  });
}
