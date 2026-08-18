import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/l10n/app_localizations.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/theme.dart';

/// Envoltorio para las pruebas de widgets.
///
/// Existe porque en cuanto la app se tradujo, cualquier `MaterialApp` de prueba
/// sin los delegados revienta con un "Null check operator used on a null value"
/// —`L.of(context)` no encuentra nada— y el mensaje no dice en absoluto que
/// falten los delegados. Centralizarlo evita repetir el error en cada prueba
/// nueva.
///
/// Monta DOS delegados y el `SendaBrandScope`, igual que `main.dart`. Cuando
/// Nona empezó a usar widgets del paquete, este envoltorio se quedó con solo el
/// suyo y las pruebas volvieron a reventar con el mismo error ilegible — que es
/// exactamente lo que este fichero existía para evitar. Si una prueba monta algo
/// del paquete, necesita las tres piezas.
Widget testApp(Widget home, {Locale locale = const Locale('es')}) => MaterialApp(
  theme: nonaTheme(),
  locale: locale,
  supportedLocales: L.supportedLocales,
  localizationsDelegates: const [
    L.delegate,
    SendaL.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: SendaBrandScope(brand: nonaBrand, child: home),
);
