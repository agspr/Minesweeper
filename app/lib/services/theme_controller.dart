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
    // `byId` cae en Menta cuando no reconoce el id, que es el defecto de
    // la FAMILIA. El de Nona es otro, así que sin guardar nada se usa el suyo;
    // guardado, manda lo guardado.
    NonaColors.current = SendaPalettes.byId(
      _prefs.getString(_kTheme),
      fallback: NonaColors.defaultPalette,
    );
    // `?? true`: el tablero nace en color. Quien no quiera, lo apaga desde la
    // propia pantalla de juego y se le recuerda.
    NonaColors.tinted = _prefs.getBool(_kBoardColour) ?? true;
  }

  /// Sin prefijo `game.` ni `progress.`: el tema es del APARATO, no de la
  /// cuenta. Está fuera de `ownedPrefKeyPrefixes` a propósito — cambiar de
  /// sesión en un teléfono compartido no debe repintar la app de otro color.
  static const _kTheme = 'settings.theme';
  static const _kBoardColour = 'settings.boardColour';

  final SharedPreferences _prefs;

  SendaPalette get palette => NonaColors.current;

  Future<void> select(SendaPalette value) async {
    if (value.id == NonaColors.current.id) return;
    NonaColors.current = value;
    notifyListeners();
    // El ID, nunca el nombre visible: el nombre cambia con el idioma y esta
    // clave tiene que sobrevivir a que alguien cambie de idioma.
    await _prefs.setString(_kTheme, value.id);
  }

  /// Si el tablero sigue al tema o se queda en grises.
  ///
  /// Se apaga desde la propia pantalla de juego y no desde ajustes: es una
  /// decisión que se toma MIRANDO el tablero, y mandar a alguien a otra
  /// pantalla para verla aplicada aquí sería pedirle que recuerde dos estados a
  /// la vez.
  bool get boardColour => NonaColors.tinted;

  Future<void> toggleBoardColour() async {
    NonaColors.tinted = !NonaColors.tinted;
    notifyListeners();
    await _prefs.setBool(_kBoardColour, NonaColors.tinted);
  }
}
