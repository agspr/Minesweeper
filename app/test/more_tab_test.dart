import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:nona/screens/settings_tab.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:nona/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// La pestaña Más de Nona, en lo que el dueño pidió que fuera igual que CINCO.
///
/// La FORMA la comprueba el paquete. Lo que solo se puede comprobar aquí es lo
/// que Nona elige al montarla, y eso no se ve leyendo ninguna de las dos partes
/// por separado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> montar(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      testApp(
        SettingsTab(
          practice: PracticeController(prefs),
          auth: AuthController(
            gameId: nonaGameId,
            firebaseReady: false,
            prefs: prefs,
          ),
          friends: FriendsService(firebaseReady: false, gameId: nonaGameId),
          purchases: PurchaseService(prefs, const IapConfig(removeAdsId: 'x')),
          notifications: NotificationsService(
            firebaseReady: false,
            gameId: nonaGameId,
          ),
          prefs: prefs,
          locale: LocaleController(prefs),
          theme: ThemeController(prefs),
          progress: ProgressController(prefs),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la fila de "Acerca de" lleva el nombre del juego', (
    tester,
  ) async {
    await montar(tester);
    // La fila vive al final de una lista larga: sin traerla a pantalla, el
    // ListView ni siquiera la construye.
    await tester.scrollUntilVisible(find.text('Acerca de Nona'), 200);
    expect(find.text('Acerca de Nona'), findsOneWidget);
  });

  test('«Bloqueados» sale solo si hay alguien bloqueado, y la lista se carga', () {
    // Como en CINCO (André, 5-10-2026). Estuvo apagada del todo, y quien solo
    // tiene Nona y bloqueaba a alguien no podía deshacerlo desde Nona —y el
    // aviso de bloquear del paquete le manda a «Bloqueados»—.
    //
    // Se lee el CÓDIGO, no la pantalla, y no por comodidad: la sección solo se
    // monta con `showBlocked && auth.signedIn`, y una sesión de verdad necesita
    // Firebase. Una prueba de widget aquí pasaría igual con el interruptor al
    // revés: se comprobó mutándolo.
    final fuente = File('lib/screens/settings_tab.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(fuente, contains('showBlocked: widget.friends.blocked.isNotEmpty'));
    // Sin cargarla, `blocked` está vacía y la sección no sale nunca.
    expect(fuente, contains('widget.friends.loadBlocked()'));
    // Y Más se repinta cuando la lista llega.
    expect(fuente, contains('widget.friends]'));
  });

  test('quitar la sección no desarma el filtro de bloqueo', () {
    // La otra mitad, y la que de verdad importa: `findByUsername` filtra con
    // `friends.blocked`, y esa lista la llenaba el propio bloque que se ha
    // quitado. Si nadie más la carga, se puede volver a pedir amistad a quien
    // bloqueaste, porque la regla de Firestore solo mira el bloqueo del
    // RECEPTOR. La pantalla de Amigos del paquete la carga al abrirse.
    final amigos = File(
      '../../Juegos Senda/package/lib/src/screens/friends_screen.dart',
    );
    if (!amigos.existsSync()) return; // el paquete puede venir de la caché
    expect(amigos.readAsStringSync(), contains('loadBlocked()'));
  });
}
