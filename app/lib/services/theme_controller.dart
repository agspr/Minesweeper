/// El tema elegido: cuál de los cuatro de la familia y dónde se guarda.
///
/// Los cuatro temas —Menta, Lavanda, Coral, Cobalto— los define el paquete
/// (`SendaPalettes`) porque son de Juegos Senda y no de un juego: la página
/// "Más" es la misma pantalla en CINCO y en Nona y tenía que ofrecer lo mismo,
/// con los mismos nombres y los mismos tonos. Lo que hace este controlador es
/// solo recordar cuál está puesto.
///
/// Se guarda el **nombre** y no un índice: si algún día se añade un tema en
/// medio de la lista, un índice guardado cambiaría de tema a la gente sin que
/// nadie tocara nada. Un nombre desconocido —tema retirado, o datos de una
/// versión futura— cae en Menta, que es el defecto.
library;

import 'package:flutter/foundation.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    // Se aplica en el constructor y no al primer `build`: `NonaColors.current`
    // lo leen widgets que pueden pintarse antes: un fotograma con el tema
    // equivocado sería un parpadeo de color en cada arranque.
    NonaColors.current = SendaPalettes.byName(_prefs.getString(_kTheme));
  }

  /// Sin prefijo `game.` ni `progress.`: el tema es del APARATO, no de la
  /// cuenta. Está fuera de `ownedPrefKeyPrefixes` a propósito — cambiar de
  /// sesión en un teléfono compartido no debe repintar la app de otro color.
  static const _kTheme = 'settings.theme';

  final SharedPreferences _prefs;

  SendaPalette get palette => NonaColors.current;

  Future<void> select(SendaPalette value) async {
    if (value.name == NonaColors.current.name) return;
    NonaColors.current = value;
    notifyListeners();
    await _prefs.setString(_kTheme, value.name);
  }
}
