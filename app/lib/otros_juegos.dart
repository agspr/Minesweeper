import 'package:juegos_senda/juegos_senda.dart' show SendaJuegoDeLaFamilia;

/// **Los otros Juegos Senda que Nona anuncia** en Más (André, 29-9-2026, para
/// la familia: «promover Nona, y luego Minigrama y los demás según salgan»).
/// La lista es de cada juego: el paquete no nombra juegos. Uno nuevo se añade
/// aquí el día que llega a las tiendas —Minigrama aún no—, con su icono en
/// `assets/juegos/`.
///
/// Los datos de CINCO son los de su ficha: los mismos que su `GameConfig`, y
/// el icono, su icono de tienda reducido a 192 px, como CINCO hace con el de
/// Nona.
const List<SendaJuegoDeLaFamilia> kOtrosJuegosDeNona = [
  SendaJuegoDeLaFamilia(
    id: 'cinco',
    nombre: 'CINCO',
    lema: {'es': 'La palabra del día', 'en': 'The daily word game'},
    icono: 'assets/juegos/cinco.png',
    paqueteAndroid: 'com.cincoapp.cinco',
    tiendaIos: 'https://apps.apple.com/app/id6800007080',
  ),
];
