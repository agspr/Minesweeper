/// Lo que Nona le cuenta a la plataforma sobre sí misma.
///
/// Todo lo que distingue a Nona de CINCO cabe en este fichero. Si algo hay que
/// tocar aquí para que funcione otro juego, es que estaba en el sitio
/// equivocado.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

import 'theme.dart';

/// Id del juego: espacio de nombres en Firestore (`users/{uid}/apps/minesweeper`) y
/// prefijo de sus Cloud Functions. Cambiarlo tras publicar significaría
/// abandonar los datos de todo el mundo.
const String nonaGameId = 'minesweeper';

/// Las invitaciones cruzadas están ENCENDIDAS desde el 25-8-2026.
///
/// Estuvo apagada desde que se construyó, esperando a que `onInvite` se
/// desplegara. La Function llevaba semanas arriba y nadie giró el interruptor,
/// así que **la Social decía "invítalos desde Amigos" y en Amigos no había
/// nada**: André lo encontró grabando las dos apps lado a lado. La promesa y
/// lo que la cumple viven en el paquete y estaban gobernadas por separado.
///
/// Lo que hubo que resolver antes de encenderla no fue solo el despliegue:
/// enseñar "estos amigos no tienen Nona" revela qué juegos de la familia tiene
/// cada uno, y eso era legible por CUALQUIERA con sesión. André lo zanjó —
/// *"solo tus amigos deben poder ver qué juegos tienes"*— y el dato se mudó a
/// `users/{uid}/apps/*`, cerrado a los amigos activos.
///
/// Se queda como constante, y no se borra, porque el parámetro del paquete es
/// obligatorio: apagarla sigue siendo posible el día que haga falta, pero
/// nadie la hereda apagada por olvido.
const bool kInvitesEnabled = true;

/// La configuración de siempre, con el nombre en inglés: es la que usan los
/// servicios (datos, anuncios, compras, tiendas), a los que el nombre les da
/// igual.
final GameConfig nonaConfig = nonaConfigNamed('Minesweeper');

/// La misma configuración con el nombre del juego en el idioma de la pantalla
/// (`L.appName`: «Buscaminas» en español).
///
/// Existe porque el paquete escribe `config.appName` tal cual en Más y en el
/// borrado de cuenta: con el nombre fijo en inglés, la app en español decía
/// «Califica Minesweeper» debajo de «Acerca de Buscaminas», y «Borrar
/// Minesweeper de tu cuenta» en una app que en el teléfono y en las dos tiendas
/// se llama Buscaminas. Lo que se le pasa a `SendaSettingsScreen` y a
/// `SendaAboutScreen` sale de aquí.
///
/// Una instancia por nombre, y no una nueva en cada `build`: el que la recibe
/// puede compararla para saber si cambió.
GameConfig nonaConfigNamed(String appName) =>
    _porNombre.putIfAbsent(appName, () => _configCon(appName));

final Map<String, GameConfig> _porNombre = {};

GameConfig _configCon(String appName) => GameConfig(
  gameId: nonaGameId,
  appName: appName,
  appleBundleId: 'com.sendallc.minesweeper',
  // No es 'Minesweeper'. El App ID está agrupado bajo el primario de CINCO,
  // y está MEDIDO (2026-08-17) que quien solo tenga esta app ve *CINCO* en
  // Ajustes -> Iniciar sesión con Apple. Poner aquí el nombre del juego
  // mandaría a buscar una entrada que no existe, justo cuando esa persona ya
  // borró su cuenta y no puede volver a preguntar.
  appleSignInEntryName: 'CINCO',

  // Disposición LIMPIA, nunca la heredada de CINCO: los puntos van a
  // users/{uid}/apps/minesweeper y los días a .../days/{día}. Escribir en `games`
  // metería documentos en la colección viva de CINCO (§3.2).
  dataLayout: const SendaDataLayout.namespaced(nonaGameId),

  // Las unidades de Minesweeper, creadas el 23-11-2026 bajo sus dos apps de
  // AdMob («Minesweeper — Daily Logic», Android ~7005873887 e iOS
  // ~7754567513). Hasta entonces aquí iban las de Nona: los anuncios se
  // servían, pero contaban como tráfico de OTRA app, que es justo lo que las
  // políticas de AdMob tratan como inválido. Los ids de aplicación viven
  // aparte, en AndroidManifest.xml e Info.plist, y tienen que ser de la misma
  // app que estas unidades.
  ads: const AdConfig(
    bannerAndroid: 'ca-app-pub-5030233210775781/9248893845',
    bannerIos: 'ca-app-pub-5030233210775781/5128404174',
    interstitialAndroid: 'ca-app-pub-5030233210775781/4707013608',
    interstitialIos: 'ca-app-pub-5030233210775781/8865750461',
  ),

  iap: const IapConfig(removeAdsId: 'com.sendallc.minesweeper.removeads'),

  legal: LegalUrls(
    // Cada juego con las SUYAS: la política que enseña una ficha de tienda
    // tiene que ser la de esa app (§8). Las páginas las publica el agente de
    // sendapr; estas URLs son las acordadas para Minesweeper.
    privacy: Uri.parse('https://sendapr.com/privacy/minesweeper/'),
    terms: Uri.parse('https://sendapr.com/terms/minesweeper/'),
    accountDeletion: Uri.parse(
      'https://sendapr.com/delete-account/minesweeper/',
    ),
  ),

  // Bilingüe desde el primer día (diseño §0). CINCO seguirá siendo solo
  // español; el paquete no supone ninguno de los dos.
  supportedLocales: const [Locale('es'), Locale('en')],

  // Con qué color se abre Minesweeper la primera vez: Cobalto.
  defaultPalette: SendaPalettes.cobalto,

  // El handle es de toda la familia, así que reservar "minesweeper" aquí lo
  // protege también dentro de CINCO.
  reservedHandles: const {'minesweeper', 'buscaminas'},

  // A dónde manda «Actualizar» cuando hay una versión nueva publicada.
  tiendaAndroid: Uri.parse(
    'https://play.google.com/store/apps/details?id=com.sendallc.minesweeper',
  ),
  tiendaIos: Uri.parse('https://apps.apple.com/app/id6830734481'),

  // Claves locales que pertenecen a UNA cuenta. Si una se queda fuera, el
  // progreso de una persona se le atribuiría a quien entre después en el mismo
  // teléfono — y eso no se ve en desarrollo, hace falta cambiar de cuenta.
  ownedPrefKeyPrefixes: const ['game.', 'progress.', 'auth.name.'],
);

/// La marca de Nona para las pantallas de plataforma.
///
/// Ya no es constante: Nona ofrece los cuatro temas de la familia y el acento
/// depende del elegido. Se lee cada vez en vez de guardarse porque quien la
/// consume la mete en un `SendaBrandScope` que se reconstruye con el
/// `ThemeController`; una copia guardada se quedaría con el tema de arranque.
SendaBrand get nonaBrand => NonaColors.current.brand;
