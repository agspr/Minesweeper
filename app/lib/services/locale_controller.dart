/// Idioma de la app: el del sistema o uno elegido a mano.
///
/// Nona es bilingüe desde el primer día (diseño §0) porque es un juego de
/// números: el idioma apenas roza el juego, y el banco diario es el mismo para
/// las dos lenguas —los dígitos no se traducen—, así que un jugador que cambie
/// de idioma sigue teniendo exactamente el mismo puzle y la misma puntuación.
///
/// El interruptor existe además por una razón práctica: mucha gente tiene el
/// teléfono en inglés y prefiere jugar en español, o al revés. Seguir solo al
/// sistema los dejaría fuera.
///
/// Cuando el paquete `juegos_senda` esté extraído, esto se muda allí: elegir
/// idioma es plataforma, no juego, y CINCO lo necesitará igual al pasar de
/// ser solo-español.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs);

  static const _kLocale = 'settings.locale';

  final SharedPreferences _prefs;

  /// `null` = seguir al sistema. Es el valor por defecto a propósito: acertar
  /// sin preguntar es mejor que obligar a elegir en el primer arranque.
  Locale? get locale {
    final code = _prefs.getString(_kLocale);
    if (code == null) return null;
    return Locale(code);
  }

  Future<void> setLocale(Locale? value) async {
    if (value == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, value.languageCode);
    }
    notifyListeners();
  }

  /// Recorre sistema → español → inglés → sistema.
  ///
  /// Un ciclo y no un menú porque solo hay dos idiomas: un desplegable para
  /// tres opciones sería más ceremonia que la que merece.
  Future<void> cycle() async {
    final current = locale?.languageCode;
    await setLocale(switch (current) {
      null => const Locale('es'),
      'es' => const Locale('en'),
      _ => null,
    });
  }

  /// Etiqueta corta del estado actual, para el botón.
  String labelFor(String systemLabel) => switch (locale?.languageCode) {
    null => systemLabel,
    'es' => 'ES',
    _ => 'EN',
  };
}
