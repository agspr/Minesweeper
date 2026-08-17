/// Nona — Sudoku del día. Parte de Juegos Senda.
///
/// Aquí acaba el arruinado arnés de la verificación A4 (commit f7ac6a9), que ya
/// cumplió su papel: dejó demostrado que la misma cuenta de Apple da el mismo
/// uid en CINCO y en Nona.
///
/// Todavía NO se enciende nada de plataforma —cuentas, amistades,
/// clasificación, anuncios, notificaciones— porque eso llega con el paquete
/// `juegos_senda` en la fase N8, y hasta entonces el juego se sostiene solo:
/// la diaria sale del banco horneado y el progreso vive en el dispositivo. Así
/// que esta app funciona entera sin red y sin cuenta, que es como debe ser el
/// día que alguien la abra en un avión.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/daily_controller.dart';
import 'screens/game_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final daily = DailyController(prefs);
  await daily.load();
  runApp(NonaApp(daily: daily));
}

class NonaApp extends StatelessWidget {
  const NonaApp({super.key, required this.daily});

  final DailyController daily;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nona',
      debugShowCheckedModeBanner: false,
      theme: nonaTheme(),
      // Bilingüe desde el primer día (diseño §0): Nona es un juego de números,
      // así que el idioma casi no toca el juego. Las cadenas se sacan a ARB en
      // N7; de momento el delegado de Material ya responde en los dos.
      supportedLocales: const [Locale('es'), Locale('en')],
      home: _OrientationGate(child: GameScreen(controller: daily)),
    );
  }
}

/// Móviles en vertical; tablets y plegables abiertos, libres.
///
/// Se decide con MediaQuery y no en `main()` porque `physicalSize` puede ser
/// 0×0 antes del primer fotograma y clasificaría mal el aparato. Mismo criterio
/// que CINCO.
class _OrientationGate extends StatefulWidget {
  const _OrientationGate({required this.child});

  final Widget child;

  @override
  State<_OrientationGate> createState() => _OrientationGateState();
}

class _OrientationGateState extends State<_OrientationGate> {
  bool? _locked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locked = MediaQuery.sizeOf(context).shortestSide < 600;
    if (locked != _locked) {
      _locked = locked;
      SystemChrome.setPreferredOrientations(
        locked ? [DeviceOrientation.portraitUp] : DeviceOrientation.values,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
