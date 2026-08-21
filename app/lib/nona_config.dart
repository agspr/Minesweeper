/// Lo que Nona le cuenta a la plataforma sobre sí misma.
///
/// Todo lo que distingue a Nona de CINCO cabe en este fichero. Si algo hay que
/// tocar aquí para que funcione otro juego, es que estaba en el sitio
/// equivocado.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

import 'theme.dart';

/// Id del juego: espacio de nombres en Firestore (`users/{uid}/apps/nona`) y
/// prefijo de sus Cloud Functions. Cambiarlo tras publicar significaría
/// abandonar los datos de todo el mundo.
const String nonaGameId = 'nona';

final GameConfig nonaConfig = GameConfig(
  gameId: nonaGameId,
  appName: 'Nona',
  appleBundleId: 'com.nonaapp.nona',
  // No es 'Nona'. El App ID de Nona esta agrupado bajo el primario de CINCO,
  // y esta MEDIDO (2026-08-17) que quien solo tenga Nona ve *CINCO* en
  // Ajustes -> Iniciar sesion con Apple. Poner aqui el nombre del juego
  // mandaria a buscar una entrada que no existe, justo cuando esa persona ya
  // borro su cuenta y no puede volver a preguntar.
  appleSignInEntryName: 'CINCO',

  // Disposición LIMPIA, nunca la heredada de CINCO: los puntos van a
  // users/{uid}/apps/nona y los días a .../days/{día}. Escribir en `games`
  // metería documentos en la colección viva de CINCO (§3.2).
  dataLayout: const SendaDataLayout.namespaced(nonaGameId),

  // Sin cuenta de AdMob todavía: el paquete cae a las unidades de prueba de
  // Google. Se cambia por las reales cuando el agente de listings las cree, y
  // mientras tanto la app se puede construir y enseñar entera.
  ads: const AdConfig(
    bannerAndroid: 'ca-app-pub-5030233210775781/8790973745',
    bannerIos: 'ca-app-pub-5030233210775781/5154197249',
    interstitialAndroid: 'ca-app-pub-5030233210775781/2444273423',
    interstitialIos: 'ca-app-pub-5030233210775781/2528033906',
  ),

  iap: const IapConfig(removeAdsId: 'com.nonaapp.nona.removeads'),

  legal: LegalUrls(
    // Cada juego con las SUYAS: la política que enseña una ficha de tienda
    // tiene que ser la de esa app (§8). Las páginas las publica el agente de
    // sendapr; estas URLs son las acordadas para Nona.
    privacy: Uri.parse('https://sendapr.com/privacy/nona/'),
    terms: Uri.parse('https://sendapr.com/terms/nona/'),
    accountDeletion: Uri.parse('https://sendapr.com/delete-account/nona/'),
  ),

  // Bilingüe desde el primer día (diseño §0). CINCO seguirá siendo solo
  // español; el paquete no supone ninguno de los dos.
  supportedLocales: const [Locale('es'), Locale('en')],

  // Con qué color se abre Nona la primera vez. NO es Menta, que es el de
  // CINCO: las dos ofrecen los mismos cuatro temas a propósito, pero arrancar
  // las dos en el mismo hacía que las fichas de tienda parecieran la misma app.
  // Cobalto es el más lejano en tono al menta, y el azul le sienta bien a un
  // juego de números.
  defaultPalette: SendaPalettes.cobalto,

  // El handle es de toda la familia, así que reservar "nona" aquí lo protege
  // también dentro de CINCO.
  reservedHandles: const {'nona', 'nonaapp'},

  // Claves locales que pertenecen a UNA cuenta. Si una se queda fuera, el
  // progreso de una persona se le atribuiría a quien entre después en el mismo
  // teléfono — y eso no se ve en desarrollo, hace falta cambiar de cuenta.
  ownedPrefKeyPrefixes: const ['game.', 'progress.'],
);

/// La marca de Nona para las pantallas de plataforma.
///
/// Ya no es constante: Nona ofrece los cuatro temas de la familia y el acento
/// depende del elegido. Se lee cada vez en vez de guardarse porque quien la
/// consume la mete en un `SendaBrandScope` que se reconstruye con el
/// `ThemeController`; una copia guardada se quedaría con el tema de arranque.
SendaBrand get nonaBrand => NonaColors.current.brand;
