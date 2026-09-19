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

  // A dónde manda «Actualizar» cuando hay una versión nueva publicada. Sin
  // ellas el aviso no sale. La de Apple, por el id numérico y SIN país, como la
  // de CINCO: un país fijo en el enlace no es el de quien lo toca, y Nona no
  // está en todas las tiendas (la ficha en `/es/` da 404, medido el
  // 19-9-2026). Y las dos son las de NONA: copiadas de CINCO, «Actualizar»
  // mandaría a instalar el otro juego.
  tiendaAndroid: Uri.parse(
    'https://play.google.com/store/apps/details?id=com.nonaapp.nona',
  ),
  tiendaIos: Uri.parse('https://apps.apple.com/app/id6802670347'),

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
