/// Nona — Sudoku del día. Parte de Juegos Senda.
///
/// Aquí acaba el arruinado arnés de la verificación A4 (commit f7ac6a9), que ya
/// cumplió su papel: dejó demostrado que la misma cuenta de Apple da el mismo
/// uid en CINCO y en Nona.
///
/// La plataforma ya está encendida entera: cuentas, amistades, clasificación,
/// invitaciones y compras vienen del paquete `juegos_senda`. El juego se
/// sostiene solo igualmente:
/// la diaria sale del banco horneado y el progreso vive en el dispositivo. Así
/// que esta app funciona entera sin red y sin cuenta, que es como debe ser el
/// día que alguien la abra en un avión.
library;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'game/daily_controller.dart';
import 'game/practice_controller.dart';
import 'l10n/app_localizations.dart';
import 'nona_config.dart';
import 'screens/home_screen.dart';
import 'widgets/puzzle_layout.dart';
import 'services/progress_controller.dart';
import 'services/progress_sync.dart';
import 'services/theme_controller.dart';
import 'theme.dart';
import 'sentry_config.dart';

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

  // App Check, en MONITOREO: certifica que las peticiones vienen de la app de
  // verdad. Justo después de initializeApp y antes de tocar Firestore. No fuerza
  // nada todavía —eso se enciende en la consola cuando el tráfico verificado se
  // vea en el panel— así que añadirlo no puede romper esta versión ni las
  // anteriores. Hallazgo #1 de la auditoría: Nona era la única de la familia que
  // no lo llamaba.
  await activateSendaAppCheck(firebaseReady: firebaseReady);

  // Crashlytics: errores de Flutter y de plataforma. Desactivado en debug para
  // no ensuciar el panel con crashes de desarrollo. Misma forma que CINCO
  // (regla de familia): un juego de Juegos Senda declara su telemetría desde
  // el día uno.
  if (firebaseReady) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Sin esta llamada, TODOS los eventos que el paquete emite en Nona se
  // descartaban en silencio: `Analytics._ready` nunca pasaba a true, así que
  // cada inicio de sesión y cada invitación median cero. La firma exacta del
  // fallo silencioso — compila, corre, y no cuenta nada.
  if (firebaseReady) Analytics.init();

  final prefs = await SharedPreferences.getInstance();
  final daily = DailyController(prefs);
  final progress = ProgressController(prefs);
  final auth = AuthController(
    firebaseReady: firebaseReady,
    prefs: prefs,
    // Sin esto no se escribe `apps.nona` y los amigos de la familia ven a
    // quien juega a Nona como "todavía no lo tiene" — y le invitan a instalar
    // lo que ya tiene.
    gameId: nonaGameId,
  );
  final notifications = NotificationsService(
    firebaseReady: firebaseReady,
    gameId: nonaGameId,
  );
  // El toque de una invitación cruzada abre la tienda de ESTA plataforma
  // (o ninguna, si el juego aún no está publicado ahí). Ver el paquete.
  notifications.wireInviteTaps();

  // Los avisos: registrar el token de esta app en cuanto haya sesión, SIN pedir
  // permiso todavía. Si ya está concedido —lo normal a partir de la segunda
  // vez, y siempre si lo concedió en CINCO— el token se escribe solo. El
  // permiso se pide en su momento con contexto, al aceptar una amistad, no de
  // golpe al abrir la app.
  //
  // También en cada cambio de cuenta: el token va POR USUARIO, y sin `reset()`
  // la cuenta nueva se quedaría sin registrar creyendo que ya lo estaba.
  auth.addListener(() {
    if (auth.signedIn) {
      notifications.ensureReady(canAskPermission: false);
    } else {
      notifications.reset();
    }
  });

  // La copia del progreso en la nube. Se enciende SOLO con Firebase: sin él no
  // hay a dónde escribir, y montarlo igual dejaría un oyente comprobando una
  // sesión que nunca existe.
  //
  // Vive lo que vive el proceso —no lo desecha nadie— porque el progreso hay
  // que subirlo mientras la app esté abierta, y el único momento en que dejaría
  // de hacer falta es cuando ya no hay app.
  if (firebaseReady) {
    ProgressSync(
      prefs: prefs,
      progress: progress,
      auth: auth,
      uidOf: () => auth.user?.uid,
      store: FirestoreProgressStore(nonaConfig.dataLayout),
      session: SessionSync(
        prefs,
        ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
      ),
    ).start();
  }

  // Solo se espera a la diaria: es a lo que viene la gente. El modo libre se
  // carga la primera vez que se entra, para no meter una generación de puzle en
  // el arranque en frío.
  await daily.load();
  final app = NonaApp(
    daily: daily,
    practice: PracticeController(prefs),
    locale: LocaleController(prefs),
    // Antes que `runApp`: el constructor aplica el tema guardado, y hacerlo
    // aquí evita que el primer fotograma salga con el de por defecto.
    theme: ThemeController(prefs),
    progress: progress,
    auth: auth,
    friends: FriendsService(firebaseReady: firebaseReady, gameId: nonaGameId),
    notifications: notifications,
    prefs: prefs,
    // La clasificación necesita Firestore ya en el constructor, así que sin
    // Firebase no se construye: en modo local la pestaña Social enseña la
    // invitación a entrar y nada más.
    leaderboard: firebaseReady
        ? LeaderboardService(layout: nonaConfig.dataLayout)
        : null,
    purchases: PurchaseService(prefs, nonaConfig.iap)..init(),
    // El consentimiento (RGPD + ATT) se pide una vez por sesión y lo comparte
    // todo lo que muestre anuncios, así que vive aquí arriba y no dentro del
    // banner.
    consent: ConsentManager(),
  );

  // Sentry envuelve los manejadores de error ya instalados (los de Crashlytics
  // incluidos), así que ambos reciben cada error. Con el DSN vacío, Sentry
  // queda apagado y Crashlytics sigue: el default del DSN vive en
  // `sentry_config.dart` — SIN default real, todas las builds saldrían con
  // Sentry apagado sin que nada falle (los builds no pasan --dart-define).
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.environment = kDebugMode ? 'debug' : 'production';
      options.tracesSampleRate = 0.2;
    }, appRunner: () => runApp(app));
  } else {
    runApp(app);
  }
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
    required this.consent,
    required this.notifications,
    required this.leaderboard,
    required this.prefs,
  });

  final DailyController daily;
  final PracticeController practice;
  final LocaleController locale;
  final ThemeController theme;
  final ProgressController progress;
  final AuthController auth;
  final FriendsService friends;
  final PurchaseService purchases;
  final ConsentManager consent;
  final NotificationsService notifications;

  /// Para poder limpiar lo que Nona guarda al salirse de la cuenta.
  final SharedPreferences prefs;
  final LeaderboardService? leaderboard;

  @override
  Widget build(BuildContext context) {
    // Escucha el idioma Y el tema: cambiar cualquiera de los dos reconstruye
    // MaterialApp entera, que es lo que hace que la app se traduzca y se
    // repinte sin reiniciar. El tema tiene que estar aquí arriba y no solo en
    // ajustes porque el acento lo usan el tablero, el numpad y la barra
    // inferior, que están en otra rama del árbol.
    return ListenableBuilder(
      listenable: Listenable.merge([locale, theme]),
      // La marca ENVUELVE al MaterialApp, no vive en su `home`.
      //
      // Dentro de `home` queda por debajo del Navigator, así que las pantallas
      // que se EMPUJAN como ruta no la heredan y revientan al abrirse. Pasaba
      // ya: "Eliminar cuenta" se empuja desde el editor de perfil y lee la
      // marca. Lo cazó una prueba del paquete que empuja la pantalla de Amigos
      // en vez de montarla como `home`.
      builder: (context, _) => SendaBrandScope(
        brand: nonaBrand,
        child: MaterialApp(
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
          // El corte lo declara Nona y no el paquete: es el MISMO número que
          // manda su maqueta de tablet, así que la rotación y la maqueta no
          // pueden separarse.
          home: SendaOrientationGate(
            ladoCortoMinimo: kTabletShortestSide,
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
                notifications: notifications,
                prefs: prefs,
                leaderboard: leaderboard,
                // Se construye AQUÍ, una sola vez y arriba del todo: el banner
                // reserva su alto desde el primer fotograma, y rehacerlo en
                // cada reconstrucción del armazón lo haría recargar. Las
                // pruebas montan `HomeScreen` sin él.
                banner: AdBanner(
                  consent: consent,
                  purchases: purchases,
                  ads: nonaConfig.ads,
                  // El hueco reservado tiene que fundirse con el fondo de la
                  // app, no con uno del paquete.
                  backgroundColor: NonaColors.appBg,
                ),
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
          // **Si el perfil no se pudo leer, se DICE.** Antes esto era solo la
          // ruedita, y un fallo de lectura la dejaba girando para siempre:
          // pantalla en blanco, sin texto y sin salida. Pasó de verdad —App
          // Check denegando en un simulador cuyo token de depuración no estaba
          // registrado— y le pasa igual a quien no supere la atestación en un
          // aparato real, o con una regla mal desplegada.
          //
          // Va ANTES del spinner: `profileReady` se queda en false a propósito
          // ante el error (si se diera por leído, `needsOnboarding` mandaría a
          // elegir @usuario a quien ya tiene uno, y es inmutable), así que sin
          // esta comprobación el error es indistinguible de «aún cargando».
          if (auth.profileError != null) {
            return _NoSePudoLeerElPerfil(auth: auth, l: l);
          }
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

/// Lo que se enseña cuando la lectura del perfil falla.
///
/// Calcada de la de CINCO (`_NoSePudoLeerElPerfil`) salvo en una cosa: **los
/// textos salen del ARB**, porque Nona es bilingüe de verdad y ahí CINCO puede
/// permitirse castellano fijo y Nona no.
///
/// **Dos salidas, y las dos hacen falta.** Reintentar cubre el caso pasajero
/// —la conexión—, pero si el fallo es de la cuenta (atestación que no pasa,
/// una regla que la deja fuera) reintentar no sale nunca del bucle: cerrar
/// sesión es lo único que devuelve el control. Con una sola, la pantalla sería
/// otro callejón sin salida, más bonito.
class _NoSePudoLeerElPerfil extends StatelessWidget {
  const _NoSePudoLeerElPerfil({required this.auth, required this.l});

  final AuthController auth;
  final L l;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.profileErrorTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: NonaColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                // Que el progreso local no se ha perdido se dice explícito: es
                // lo primero que teme quien ve fallar su perfil.
                l.profileErrorBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: NonaColors.muted,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.reintentarPerfil,
                  style: FilledButton.styleFrom(
                    backgroundColor: NonaColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    l.profileErrorRetry,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: NonaColors.accentDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: auth.signOut,
                child: Text(
                  l.profileErrorSignOut,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NonaColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
