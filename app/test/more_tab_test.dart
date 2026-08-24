import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';
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
          auth: AuthController(firebaseReady: false, prefs: prefs),
          friends: FriendsService(firebaseReady: false),
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

  test('Nona pide expresamente que Más NO enseñe los bloqueados', () {
    // Se lee el CÓDIGO, no la pantalla, y no por comodidad: la sección solo se
    // monta con `showBlocked && auth.signedIn`, y una sesión de verdad necesita
    // Firebase. Una prueba de widget aquí pasaría igual con el interruptor
    // puesto al revés — lo comprobé mutándolo, y no se enteró. Más vale una
    // prueba que mira el sitio raro y sirve, que una que mira el sitio bonito
    // y no distingue nada.
    //
    // Lo que vigila: que nadie quite la línea. El dueño sacó los bloqueados de
    // esta pantalla, y volverían solos con el valor por defecto del paquete.
    final fuente = File('lib/screens/settings_tab.dart').readAsStringSync();
    expect(fuente, contains('showBlocked: false'));
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
