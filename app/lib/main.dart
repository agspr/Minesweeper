/// Nona — Sudoku del día. Parte de Juegos Senda.
///
/// Aquí acaba el arruinado arnés de la verificación A4 (commit f7ac6a9), que ya
/// cumplió su papel: dejó demostrado que la misma cuenta de Apple da el mismo
/// uid en CINCO y en Nona.
///
/// La plataforma ya está encendida: cuentas, amistades y compras vienen del
/// paquete `juegos_senda`. Lo que sigue sin encender es la CLASIFICACIÓN, que
/// necesita `LeaderboardService` (fase B). El juego se sostiene solo igualmente:
/// la diaria sale del banco horneado y el progreso vive en el dispositivo. Así
/// que esta app funciona entera sin red y sin cuenta, que es como debe ser el
/// día que alguien la abra en un avión.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'game/daily_controller.dart';
import 'game/practice_controller.dart';
import 'l10n/app_localizations.dart';
import 'nona_config.dart';
import 'screens/home_screen.dart';
import 'services/progress_controller.dart';
import 'services/theme_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sin Firebase configurado la app arranca igual, en modo local: la diaria y
  // el modo libre no necesitan cuenta ni red, y esa es la promesa del juego.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    // Se juega igual; lo social simplemente no aparece.
  }

  final prefs = await SharedPreferences.getInstance();
  final daily = DailyController(prefs);
  // Solo se espera a la diaria: es a lo que viene la gente. El modo libre se
  // carga la primera vez que se entra, para no meter una generación de puzle en
  // el arranque en frío.
  await daily.load();
  runApp(
    NonaApp(
      daily: daily,
      practice: PracticeController(prefs),
      locale: LocaleController(prefs),
      // Antes que `runApp`: el constructor aplica el tema guardado, y hacerlo
      // aquí evita que el primer fotograma salga con el de por defecto.
      theme: ThemeController(prefs),
      progress: ProgressController(prefs),
      auth: AuthController(firebaseReady: firebaseReady, prefs: prefs),
      friends: FriendsService(firebaseReady: firebaseReady),
      purchases: PurchaseService(prefs, nonaConfig.iap)..init(),
    ),
  );
}

class NonaApp extends StatelessWidget {
  const NonaApp({
    super.key,
    required this.daily,
    required this.practice,
    required this.locale,
    required this.theme,
    required this.progress,
    required this.auth,
    required this.friends,
    required this.purchases,
  });

  final DailyController daily;
  final PracticeController practice;
  final LocaleController locale;
  final ThemeController theme;
  final ProgressController progress;
  final AuthController auth;
  final FriendsService friends;
  final PurchaseService purchases;

  @override
  Widget build(BuildContext context) {
    // Escucha el idioma Y el tema: cambiar cualquiera de los dos reconstruye
    // MaterialApp entera, que es lo que hace que la app se traduzca y se
    // repinte sin reiniciar. El tema tiene que estar aquí arriba y no solo en
    // ajustes porque el acento lo usan el tablero, el numpad y la barra
    // inferior, que están en otra rama del árbol.
    return ListenableBuilder(
      listenable: Listenable.merge([locale, theme]),
      builder: (context, _) => MaterialApp(
        title: 'Nona',
        debugShowCheckedModeBanner: false,
        theme: nonaTheme(),
        // Bilingüe desde el primer día (diseño §0). `locale: null` significa
        // seguir al sistema; con un idioma elegido a mano, manda ese.
        locale: locale.locale,
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          // Dos delegados: el del juego y el de la plataforma. Cada capa es
          // dueña de su texto.
          L.delegate,
          SendaL.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // La marca viaja por el árbol: las pantallas del paquete la leen de
        // aquí en vez de una global, así que olvidarla es un error de
        // compilación y no un color equivocado en producción.
        home: SendaBrandScope(
          brand: nonaBrand,
          child: _OrientationGate(
            child: _AuthGate(
              auth: auth,
              child: HomeScreen(
                daily: daily,
                practice: practice,
                locale: locale,
                theme: theme,
                progress: progress,
                auth: auth,
                friends: friends,
                purchases: purchases,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrada a la app: sesión, identidad y luego el juego.
///
/// Misma forma que CINCO (`main.dart`), y por el mismo motivo: la cuenta es de
/// **Juegos Senda**, no de un juego, así que quien entra en Nona entra en la
/// familia entera y la pantalla que lo explica tiene que ser la misma.
///
/// El orden importa y no es arbitrario:
///
/// 1. Sin sesión y **sin haber elegido jugar como invitado** → pantalla de
///    entrada. Jugar sin cuenta es una elección explícita, no el defecto: si lo
///    fuera, nadie vería nunca que existe una cuenta compartida.
/// 2. Con sesión pero **sin perfil cargado todavía** → espera. Decidir antes de
///    que llegue el perfil enseñaría el onboarding a quien ya tiene username.
/// 3. Con sesión y sin username → onboarding de identidad, una sola vez.
///
/// El invitado se salta 2 y 3 enteros: no tiene perfil que esperar.
class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.auth, required this.child});

  final AuthController auth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final l = L.of(context);

        // Sin Firebase (arranque en modo local) no hay nada que decidir: se
        // juega, que es la promesa del juego.
        if (!auth.firebaseReady) return child;

        if (!auth.signedIn && !auth.guest) {
          return SendaSignInScreen(
            auth: auth,
            appName: l.appName,
            tagline: l.appTagline,
          );
        }

        if (auth.signedIn) {
          if (!auth.profileReady) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }
          if (auth.needsOnboarding) {
            return SendaOnboardingScreen(
              auth: auth,
              // El handle es de la familia: lo que reserva Nona queda
              // reservado también dentro de CINCO.
              reservedHandles: nonaConfig.reservedHandles,
            );
          }
        }

        return child;
      },
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
