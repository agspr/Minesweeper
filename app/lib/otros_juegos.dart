import 'package:juegos_senda/juegos_senda.dart' show SendaJuegoDeLaFamilia;

/// **Los otros Juegos Senda que Buscaminas anuncia** en Más.
/// Incluye a CINCO y Nona, con sus iconos en `assets/juegos/`.
const List<SendaJuegoDeLaFamilia> kOtrosJuegosDeNona = [
  SendaJuegoDeLaFamilia(
    id: 'cinco',
    nombre: 'CINCO',
    lema: {'es': 'La palabra del día', 'en': 'The daily word game'},
    icono: 'assets/juegos/cinco.png',
    paqueteAndroid: 'com.cincoapp.cinco',
    tiendaIos: 'https://apps.apple.com/app/id6800007080',
  ),
  SendaJuegoDeLaFamilia(
    id: 'nona',
    nombre: 'Nona',
    lema: {'es': 'El sudoku del día', 'en': 'The daily sudoku'},
    icono: 'assets/juegos/nona.png',
    paqueteAndroid: 'com.nonaapp.nona',
    tiendaIos: 'https://apps.apple.com/app/id6802670347',
  ),
];
