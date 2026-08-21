/// Identidad visual de Nona.
///
/// Los neutros oscuros y **los cuatro temas** los pone ahora el paquete: son el
/// aire de familia de Juegos Senda. Nona ofrece los mismos cuatro que CINCO
/// —Menta, Lavanda, Coral y Cobalto— porque la página "Más" es la misma
/// pantalla en las dos apps y tenía que verse igual, con los mismos nombres y
/// los mismos tonos.
///
/// **Esto sustituye al ámbar propio que tenía Nona.** El ámbar se eligió para
/// separar las dos apps de un vistazo en la pantalla de inicio y por ser un
/// tono cálido y de brillo medio, más llevadero en las sentadas largas que
/// invita un sudoku. Se cambia por decisión de producto —que las dos apps se
/// vean hermanas pesa más—, no porque aquel razonamiento fuera malo. Si algún
/// día se quiere recuperar, cabe como QUINTO tema junto a los cuatro de la
/// familia; lo que no cabe es que Nona tenga cuatro temas distintos a los de
/// CINCO en la misma pantalla compartida.
///
/// Lo que sigue siendo de Nona y solo de Nona es el **tablero**: necesita
/// distinguir **seis** estados a la vez —pista, escrita, equivocada,
/// seleccionada, misma fila/columna/caja, mismo dígito— y eso no se puede hacer
/// solo con tonos: quien no distingue bien los colores vería lo mismo. Así que
/// cada estado se separa además por **brillo** o por **peso de la tipografía**,
/// nunca solo por color. Por eso casi todo el tablero es neutro y solo la
/// casilla seleccionada y el dígito escrito siguen al acento.
library;

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart';

import 'nona_config.dart';

abstract final class NonaColors {
  /// Con qué tema arranca Nona quien no ha elegido ninguno.
  ///
  /// **Cobalto y no Menta, y el motivo no es estético.** Los dos juegos ofrecen
  /// los mismos cuatro temas —eso es deliberado, la pantalla "Más" es la misma
  /// en las dos apps— pero además arrancaban los dos en Menta, y eso ya no era
  /// deliberado: era que ninguno había elegido. El resultado es que las fichas
  /// de tienda de CINCO y de Nona se veían como la misma app en el scroll, y
  /// que el icono cargaba solo con toda la diferenciación. Lo detectó el agente
  /// de listings mirando qué implicaba la paleta compartida en su terreno.
  ///
  /// Cambiar el DEFECTO lo arregla sin tocar nada de lo compartido: las cuatro
  /// tarjetas de color siguen siendo las mismas, con los mismos nombres y en el
  /// mismo orden, y quien quiera Menta la tiene a un toque. Lo único que cambia
  /// es con qué color se abre la app por primera vez.
  ///
  /// Cobalto de los tres posibles: es el más lejano en tono al menta de CINCO
  /// —que es justo el punto—, y el azul le sienta bien a un juego de números.
  /// Coral se descartó porque comparte familia con el rojo de "equivocado".
  /// Lo declara `nona_config.dart`, que es la costura donde va todo lo que
  /// distingue a Nona. Aquí solo se reexporta para que el tablero no tenga que
  /// conocer el GameConfig entero.
  static SendaPalette get defaultPalette => nonaConfig.defaultPalette;

  /// Tema activo. No es `const` a propósito: se elige en ajustes y toda la app
  /// se reconstruye con el nuevo tono. Mismo patrón que `CincoColors.current`.
  ///
  /// Quien lo cambia es `ThemeController`, que además lo guarda; asignarlo a
  /// mano desde otro sitio dejaría la pantalla y el disco diciendo cosas
  /// distintas.
  static SendaPalette current = SendaPalettes.cobalto;

  // Neutros compartidos con CINCO.
  static const bg = SendaColors.bg;
  static const appBg = SendaColors.appBg;
  static const surface = SendaColors.surface;
  static const sheet = SendaColors.sheet;
  static const text = SendaColors.text;
  static const muted = SendaColors.muted;

  // Acento: el del tema elegido.
  static Color get accent => current.brand.accent;
  static Color get accentDeep => current.brand.accentDeep;
  static Color get accentChip => current.brand.accentChip;

  // ── Tablero ────────────────────────────────────────────
  //
  // El tablero se TIÑE con el tema, y se puede apagar desde la propia pantalla
  // de juego (`ThemeController.boardColour`). Lo controla esta bandera.
  //
  // Qué se tiñe y qué no NO es cuestión de gusto: se tiñen los canales
  // ESPACIALES —dónde estoy, qué casillas se relacionan con esta— y nunca los
  // SEMÁNTICOS —esto está mal, esto es una pista—. Un acento elegible no puede
  // decidir el color de algo que significa una cosa concreta, que es la regla
  // de los dos canales que el paquete ya documenta.
  //
  // Medido antes de escribirlo, en distancia RGB entre pares de estados:
  //
  //                        hoy (neutro)   teñido
  //   pista/misma cifra          8,8      25-32     <- eran casi el mismo gris
  //   pista/casilla normal      13,4      38-45
  //   misma cifra/equivocada    29,7      52-70
  //
  // O sea que el tablero neutro era lo ARRIESGADO: las dos ayudas de
  // orientación se distinguían por 8,8, que a ojo es nada. Teñir no gasta
  // margen de legibilidad, lo multiplica.
  static bool tinted = true;

  static Color _tint(Color base, double t) =>
      tinted ? Color.lerp(base, current.brand.accent, t)! : base;

  /// Fondo de una casilla normal. NUNCA se tiñe: son 81 casillas y teñirlas
  /// dejaría sin contraste a todo lo que va encima.
  static const cell = Color(0xFF17171D);

  /// Casilla de la fila/columna/caja de la seleccionada. Un paso más clara,
  /// para orientar sin gritar.
  ///
  /// El gris de base es MÁS claro que el que tenía (`#1E1E26`), y eso arregla
  /// un fallo que metí con el interruptor: con el color apagado, esta casilla
  /// quedaba a 13,4 de la normal y a 8,8 de "misma cifra" — o sea, los números
  /// exactos que hacían del tablero neutro el diseño arriesgado. Al teñir se
  /// arreglaban solos, así que monté el interruptor sin medir nunca el estado
  /// que produce. Sin tono disponible, la separación tiene que salir del
  /// BRILLO.
  static Color get cellPeer => _tint(const Color(0xFF24242E), 0.10);

  /// Casilla seleccionada. Es el chip del tema: el mismo tinte que usan las
  /// pastillas del resto de la app, para que "seleccionado" signifique lo
  /// mismo en el tablero y fuera de él.
  ///
  /// Con el color apagado se va a un gris, igual que el resto del cromo. Es el
  /// límite del interruptor: apaga la DECORACIÓN del tablero —fondos, líneas—
  /// pero no el acento de los dígitos que ha escrito quien juega, porque eso no
  /// es adorno sino la diferencia entre lo suyo y las pistas.
  static Color get cellSelected =>
      tinted ? current.brand.accentChip : const Color(0xFF2C2C36);

  /// Borde de la casilla seleccionada.
  ///
  /// Existe por Coral: su chip (#3A2129) queda a 22,7 de [cellWrong]
  /// (#3A1218), que es el par más justo de todo el tablero — y es anterior al
  /// tinte, viene de adoptar los cuatro temas. Un borde separa "seleccionada"
  /// de "equivocada" por PRESENCIA, no por tono, así que aguanta el tema que
  /// sea. Se mantiene con el color apagado, donde también ayuda.
  static Color get cellSelectedBorder =>
      tinted ? current.brand.accent : const Color(0xFF6E6E7D);

  /// Casillas con el MISMO dígito que la seleccionada: ayuda a barrer el
  /// tablero buscando dónde falta ese número.
  ///
  /// Se tiñe MÁS que [cellPeer] porque son dos ayudas distintas y antes se
  /// diferenciaban por 8,8 — es decir, no se diferenciaban. El gris de base
  /// también sube, por lo mismo que [cellPeer]: con el color apagado la
  /// escalera de brillo es lo único que queda.
  static Color get cellSameDigit => _tint(const Color(0xFF33333F), 0.18);

  /// Fondo de una casilla equivocada. La comprobación automática va activa
  /// (§1), así que esto se ve en el acto.
  static const cellWrong = Color(0xFF3A1218);

  // ── Dígitos ────────────────────────────────────────────
  //
  // Los números van en el color del tema, en el tablero y en el teclado: es lo
  // que hace que elegir Cobalto se sienta como un tablero AZUL y no como un
  // tablero gris con detalles azules. Las pistas llevan el acento entero y en
  // negrita; lo escrito, el mismo acento aclarado y más ligero. Dos canales
  // —brillo y peso— entre lo que no se puede tocar y lo que sí.
  //
  // Ninguno de los dos sigue al interruptor de color: apaga la decoración del
  // tablero, no la diferencia entre lo suyo y las pistas.
  //
  // Coral obliga a mirar una pareja más: su acento (#FF8A93) queda a 18,4 del
  // rojo de error (#FF7A8A), y ahora la pista lleva el acento EN NEGRITA, igual
  // que lo equivocado. Lo que las separa es el FONDO: un dígito equivocado solo
  // existe sobre [cellWrong], que está a más de 20 de cualquier otro fondo.
  // `board_colour_test.dart` declara esa exención con su canal.

  /// Pista: el acento entero, en negrita. No se puede tocar, y se nota.
  static Color get given => accent;

  /// Dígito escrito por el jugador: el acento aclarado hacia el blanco, más
  /// ligero que una pista. Sigue siendo "del tema", pero se ve de un vistazo
  /// que es de quien juega.
  static Color get entered => Color.lerp(accent, Colors.white, 0.55)!;

  /// Dígito equivocado.
  static const wrong = Color(0xFFFF7A8A);

  /// Anotaciones a lápiz.
  static const note = Color(0xFF7B7B8C);

  /// Líneas finas entre casillas y gruesas entre cajas de 3×3 (y el marco).
  /// Corren por el centro de los huecos que separan las superelipses, sobre
  /// [appBg]. Se tiñen: son pura geometría, no significan ningún estado, así
  /// que el acento puede mandar sin pisar nada.
  static Color get gridThin => _tint(const Color(0xFF26262E), 0.15);
  static Color get gridThick => _tint(const Color(0xFF4A4A58), 0.28);

  // ── Numpad ─────────────────────────────────────────────
  static const keyBg = Color(0xFF23232B);

  /// Texto e icono de las teclas de acción (deshacer, borrar, notas) y de las
  /// barras del modo práctica. Neutro: son botones, no números.
  static const keyFg = Color(0xFFECEAF2);

  /// El dígito de cada tecla numérica, en el acento como las pistas: el
  /// teclado y el tablero hablan el mismo color. Solo los NÚMEROS; las teclas
  /// de acción siguen en [keyFg] para que "notas" activo conserve su cambio
  /// de color.
  static Color get keyDigitFg => accent;
  static const keyDone = Color(0xFF1A1A20);
  static const keyDoneFg = Color(0xFF44444E);
}

/// El tema de la app.
///
/// Delega en el del paquete en vez de montar uno propio: así la tipografía
/// —Figtree— y el esquema de color salen del MISMO sitio en los dos juegos.
/// Cuando esto se construía aparte, Nona se quedó sin Figtree sin que nadie lo
/// notara: compilaba, pasaba las pruebas, y la misma pantalla compartida se
/// veía con dos letras distintas según la app.
ThemeData nonaTheme() => sendaTheme(NonaColors.current.brand);
