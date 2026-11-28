import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'Buscaminas'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In es, this message translates to:
  /// **'Reto diario'**
  String get appTagline;

  /// No description provided for @menuDaily.
  ///
  /// In es, this message translates to:
  /// **'Reto diario'**
  String get menuDaily;

  /// No description provided for @menuDailyToday.
  ///
  /// In es, this message translates to:
  /// **'{difficulty} · hoy'**
  String menuDailyToday(String difficulty);

  /// No description provided for @menuDailyDone.
  ///
  /// In es, this message translates to:
  /// **'Hecha · {difficulty}'**
  String menuDailyDone(String difficulty);

  /// No description provided for @menuLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get menuLoading;

  /// No description provided for @menuPractice.
  ///
  /// In es, this message translates to:
  /// **'Modo práctica'**
  String get menuPractice;

  /// No description provided for @menuPracticeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puzles infinitos · sin puntos ni racha'**
  String get menuPracticeSubtitle;

  /// No description provided for @difficultyEasy.
  ///
  /// In es, this message translates to:
  /// **'Fácil'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In es, this message translates to:
  /// **'Medio'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In es, this message translates to:
  /// **'Difícil'**
  String get difficultyHard;

  /// No description provided for @noMistakes.
  ///
  /// In es, this message translates to:
  /// **'sin errores'**
  String get noMistakes;

  /// No description provided for @mistakeCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 error} other{{count} errores}}'**
  String mistakeCount(int count);

  /// Se añade al contador de errores al llegar al tope de 5, donde la penalización deja de crecer.
  ///
  /// In es, this message translates to:
  /// **' (tope)'**
  String get mistakeCapSuffix;

  /// No description provided for @hintCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 pista} other{{count} pistas}}'**
  String hintCount(int count);

  /// No description provided for @undo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get undo;

  /// No description provided for @erase.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get erase;

  /// No description provided for @notes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get notes;

  /// No description provided for @practiceDifficultyTitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona el nivel\nde dificultad'**
  String get practiceDifficultyTitle;

  /// Lo que de verdad cambia el nivel (difficulty.dart: medidas y minas) y lo que garantiza el generador (mine_generator.dart: resoluble sin adivinar). Sin cifras a propósito: si cambian las medidas, la frase sigue siendo cierta.
  ///
  /// In es, this message translates to:
  /// **'Cambia el tamaño del tablero y cuántas minas esconde. Todos se resuelven con lógica, sin adivinar.'**
  String get practiceDifficultySubtitle;

  /// No description provided for @difficultyEasyDesc.
  ///
  /// In es, this message translates to:
  /// **'El tablero más pequeño y con menos minas'**
  String get difficultyEasyDesc;

  /// No description provided for @difficultyMediumDesc.
  ///
  /// In es, this message translates to:
  /// **'Más grande y con más minas: hay que rastrear el tablero'**
  String get difficultyMediumDesc;

  /// «Cruzar dos pistas» es la deducción de subconjuntos: el generador descarta todo tablero difícil que no la necesite al menos una vez (mine_generator.dart, `usedSubset`). Por eso puede decir «siempre».
  ///
  /// In es, this message translates to:
  /// **'El más grande, y siempre pide cruzar dos pistas'**
  String get difficultyHardDesc;

  /// Conmutador del modo de práctica. «Senda» es nombre propio del modo: no se traduce.
  ///
  /// In es, this message translates to:
  /// **'Senda (3 vidas)'**
  String get practiceModeSenda;

  /// Conmutador del modo de práctica: el buscaminas de siempre, la primera mina acaba la partida.
  ///
  /// In es, this message translates to:
  /// **'Clásico (1 vida)'**
  String get practiceModeClassic;

  /// No description provided for @keepPlaying.
  ///
  /// In es, this message translates to:
  /// **'Seguir jugando'**
  String get keepPlaying;

  /// No description provided for @closeGame.
  ///
  /// In es, this message translates to:
  /// **'Menú principal'**
  String get closeGame;

  /// No description provided for @hint.
  ///
  /// In es, this message translates to:
  /// **'Pista'**
  String get hint;

  /// No description provided for @newPuzzle.
  ///
  /// In es, this message translates to:
  /// **'Otro puzle'**
  String get newPuzzle;

  /// No description provided for @solved.
  ///
  /// In es, this message translates to:
  /// **'¡Resuelto!'**
  String get solved;

  /// No description provided for @unfinished.
  ///
  /// In es, this message translates to:
  /// **'Por hoy lo dejamos aquí'**
  String get unfinished;

  /// No description provided for @streakDays.
  ///
  /// In es, this message translates to:
  /// **'días de racha'**
  String get streakDays;

  /// No description provided for @keepPlayingPractice.
  ///
  /// In es, this message translates to:
  /// **'Seguir jugando (Práctica)'**
  String get keepPlayingPractice;

  /// No description provided for @points.
  ///
  /// In es, this message translates to:
  /// **'puntos'**
  String get points;

  /// No description provided for @breakdownBase.
  ///
  /// In es, this message translates to:
  /// **'Base del día'**
  String get breakdownBase;

  /// No description provided for @breakdownNoMistakes.
  ///
  /// In es, this message translates to:
  /// **'Sin errores'**
  String get breakdownNoMistakes;

  /// No description provided for @breakdownCompleted.
  ///
  /// In es, this message translates to:
  /// **'{percent}% completado'**
  String breakdownCompleted(int percent);

  /// No description provided for @breakdownTotal.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get breakdownTotal;

  /// No description provided for @streakKept.
  ///
  /// In es, this message translates to:
  /// **'🔥 Racha mantenida'**
  String get streakKept;

  /// No description provided for @streakNeedsFinish.
  ///
  /// In es, this message translates to:
  /// **'La racha pide terminarlo'**
  String get streakNeedsFinish;

  /// No description provided for @done.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get done;

  /// Solo debería verse si se agota el horizonte horneado del banco o si el reloj del aparato está en otra era.
  ///
  /// In es, this message translates to:
  /// **'No hay puzle para hoy.\nRevisa la fecha de tu dispositivo.'**
  String get bankGap;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Del sistema'**
  String get languageSystem;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @shareScore.
  ///
  /// In es, this message translates to:
  /// **'{points} pts'**
  String shareScore(int points);

  /// No description provided for @shareStreak.
  ///
  /// In es, this message translates to:
  /// **'🔥 {days} días de racha'**
  String shareStreak(int days);

  /// No description provided for @shareChallenge.
  ///
  /// In es, this message translates to:
  /// **'¿Puedes con la de hoy?'**
  String get shareChallenge;

  /// No description provided for @statsPracticeByLevel.
  ///
  /// In es, this message translates to:
  /// **'Práctica por nivel'**
  String get statsPracticeByLevel;

  /// No description provided for @statsPlayedShort.
  ///
  /// In es, this message translates to:
  /// **'Jugadas'**
  String get statsPlayedShort;

  /// No description provided for @statsCompletedShort.
  ///
  /// In es, this message translates to:
  /// **'Completadas'**
  String get statsCompletedShort;

  /// No description provided for @statsBestTime.
  ///
  /// In es, this message translates to:
  /// **'Mejor tiempo'**
  String get statsBestTime;

  /// No description provided for @statsBestShort.
  ///
  /// In es, this message translates to:
  /// **'Mejor'**
  String get statsBestShort;

  /// No description provided for @statsDaysPlayed.
  ///
  /// In es, this message translates to:
  /// **'Días jugados'**
  String get statsDaysPlayed;

  /// No description provided for @statsDaysCompleted.
  ///
  /// In es, this message translates to:
  /// **'Terminados'**
  String get statsDaysCompleted;

  /// No description provided for @statsStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha'**
  String get statsStreak;

  /// No description provided for @statsBestStreak.
  ///
  /// In es, this message translates to:
  /// **'Mejor racha'**
  String get statsBestStreak;

  /// No description provided for @statsTotalPoints.
  ///
  /// In es, this message translates to:
  /// **'Puntos'**
  String get statsTotalPoints;

  /// No description provided for @statsAvgMistakes.
  ///
  /// In es, this message translates to:
  /// **'Errores por día'**
  String get statsAvgMistakes;

  /// No description provided for @more.
  ///
  /// In es, this message translates to:
  /// **'Más'**
  String get more;

  /// No description provided for @aboutNona.
  ///
  /// In es, this message translates to:
  /// **'Acerca de Buscaminas'**
  String get aboutNona;

  /// No description provided for @aboutSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Quiénes somos, términos, privacidad y contacto'**
  String get aboutSubtitle;

  /// No description provided for @aboutBody.
  ///
  /// In es, this message translates to:
  /// **'Buscaminas es un juego diario desarrollado por SENDA LLC en Puerto Rico. Cada día hay un puzle nuevo, el mismo para todo el mundo, con la dificultad marcada por el día de la semana. Hay también un modo práctica con puzles ilimitados que no da puntos ni racha, y una clasificación para competir con tus amigos.'**
  String get aboutBody;

  /// No description provided for @boardColourOn.
  ///
  /// In es, this message translates to:
  /// **'Tablero en color'**
  String get boardColourOn;

  /// No description provided for @boardColourOff.
  ///
  /// In es, this message translates to:
  /// **'Tablero en gris'**
  String get boardColourOff;

  /// No description provided for @menuStreak.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{🔥 1 día de racha} other{🔥 {count} días de racha}}'**
  String menuStreak(int count);

  /// Rótulo de la escena del resultado. Se escribe en caja normal: las mayúsculas las pone el widget.
  ///
  /// In es, this message translates to:
  /// **'El buscaminas de hoy'**
  String get sceneTodaysSudoku;

  /// Rótulo del dato de errores en la escena del resultado. Se escribe en caja normal: las mayúsculas las pone el widget.
  ///
  /// In es, this message translates to:
  /// **'Errores'**
  String get sceneMistakes;

  /// Rótulo del dato de puntos en la escena del resultado. Se escribe en caja normal: las mayúsculas las pone el widget.
  ///
  /// In es, this message translates to:
  /// **'Puntos'**
  String get scenePoints;

  /// Debajo del número grande de la racha.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{día de racha} other{días de racha}}'**
  String sceneStreakDays(int count);

  /// Pie de la escena de la racha cuando hoy la alargó.
  ///
  /// In es, this message translates to:
  /// **'Juega mañana y serán {next}.'**
  String sceneStreakTomorrow(int next);

  /// Frase de la escena del hito de racha.
  ///
  /// In es, this message translates to:
  /// **'¡{count} días seguidos!'**
  String sceneMilestoneTitle(int count);

  /// Rótulo de la escena del hito. Se escribe en caja normal: las mayúsculas las pone el widget.
  ///
  /// In es, this message translates to:
  /// **'Un hito de racha'**
  String get sceneMilestoneLabel;

  /// Título de la escena de rachas de amigos.
  ///
  /// In es, this message translates to:
  /// **'Rachas de amigos'**
  String get sceneFriendsTitle;

  /// Subtítulo cuando todos los amigos con racha ya jugaron.
  ///
  /// In es, this message translates to:
  /// **'Hoy jugaron todos.'**
  String get sceneFriendsAllPlayed;

  /// Subtítulo cuando falta un amigo.
  ///
  /// In es, this message translates to:
  /// **'{name} aún no ha jugado hoy.'**
  String sceneFriendsOneMissing(String name);

  /// Subtítulo cuando faltan varios (siempre 2 o más).
  ///
  /// In es, this message translates to:
  /// **'{count} amigos aún no han jugado hoy.'**
  String sceneFriendsManyMissing(int count);

  /// Botón principal de las escenas del final, salvo la última.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get sceneContinue;

  /// Título de la hoja de Quitar anuncios.
  ///
  /// In es, this message translates to:
  /// **'Jugar sin anuncios'**
  String get noAdsTitle;

  /// Enlace a la hoja, debajo del botón principal del resultado. {price} es el de la tienda.
  ///
  /// In es, this message translates to:
  /// **'Jugar sin anuncios · {price}'**
  String noAdsLink(String price);

  /// Lo que dice el enlace si la compra llega con el final abierto.
  ///
  /// In es, this message translates to:
  /// **'Listo: ya no verás anuncios'**
  String get noAdsDone;

  /// Restaurar terminó sin error y sin compra.
  ///
  /// In es, this message translates to:
  /// **'No encontramos ninguna compra que restaurar.'**
  String get noAdsNothingToRestore;

  /// Botón de la escena de rachas de amigos: manda el empujón a quien aún no ha jugado hoy.
  ///
  /// In es, this message translates to:
  /// **'Recordar'**
  String get sceneRemind;

  /// El mismo botón, ya enviado el empujón de hoy.
  ///
  /// In es, this message translates to:
  /// **'Recordado'**
  String get sceneReminded;

  /// Aviso al tocar una cifra sobre un número ya puesto: no se sobrescribe, primero se borra. La tecla no lleva texto, solo el icono de borrar, que el aviso repite.
  ///
  /// In es, this message translates to:
  /// **'Usa el botón de borrar para quitarlo primero.'**
  String get eraseFirst;

  /// Aviso al tocar otra casilla antes de abrir la salida marcada (diaria y práctica Senda). Es la condición de la promesa «sin adivinar»: el generador solo la garantiza abriendo primero la salida (SudokuBoard.faltaLaSalida).
  ///
  /// In es, this message translates to:
  /// **'Empieza por la casilla marcada: es segura, y desde ahí no hace falta adivinar.'**
  String get startOnMarkedCell;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'es':
      return LEs();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
