import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/nona_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// **Con 24 avatares, lo de debajo de la rejilla tiene que seguir al alcance.**
///
/// El paquete 0.65.0 pasó de doce avatares a veinticuatro, y la rejilla creció
/// en proporción. En CINCO eso rompió su editor de perfil, que era una columna
/// sin desplazamiento: en un 320×568 el país y «Guardar» quedaron fuera de la
/// pantalla, sin forma de llegar a ellos (aviso del agente de CINCO, 17-9-2026).
///
/// Nona no tiene editor propio: monta los del paquete, que sí se desplazan. Pero
/// el paquete no prueba ninguna de estas pantallas en un teléfono pequeño, así
/// que si un día pierden el desplazamiento no lo ve nadie. Se prueban aquí las
/// tres que Nona enseña con lo nuevo: el alta, el editor y la hoja del @usuario.
///
/// En el teléfono más pequeño y con la letra del sistema al máximo, montadas
/// bajo la app de Nona y en sus dos idiomas.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void telefonoChico(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    // Donde la pone la persona: en el sistema. Ver `perfil_ilegible_test`.
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// Lleva [objetivo] a la vista, como haría el dedo, y comprueba que queda
  /// dentro de la pantalla. Si nada se desplaza, `ensureVisible` no puede
  /// moverlo y el control se queda donde cayó: debajo del borde.
  Future<void> alcanzable(WidgetTester tester, Finder objetivo) async {
    expect(objetivo, findsOneWidget);
    await tester.ensureVisible(objetivo);
    await tester.pump();
    final caja = tester.getRect(objetivo);
    expect(
      caja.top >= 0 && caja.bottom <= 568,
      isTrue,
      reason: 'queda fuera de la pantalla y no se puede llegar a él: $caja',
    );
  }

  AuthController sinConexion() =>
      AuthController(gameId: nonaGameId, firebaseReady: false, prefs: null);

  /// Un botón que abre la hoja, porque una hoja solo existe si alguien la abre.
  Widget abridor(void Function(BuildContext) abrir) => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          key: const Key('abrir'),
          onPressed: () => abrir(context),
          child: const Text('abrir'),
        ),
      ),
    ),
  );

  /// Todos los avatares se construyen: la rejilla no se recorta para caber.
  void rejillaEntera(WidgetTester tester) {
    expect(
      find.descendant(
        of: find.byType(AvatarGrid),
        matching: find.byType(GestureDetector),
      ),
      findsNWidgets(Avatars.ids.length),
    );
  }

  for (final idioma in const [Locale('es'), Locale('en')]) {
    final lc = idioma.languageCode;

    testWidgets('$lc: el alta deja llegar a su botón bajo la rejilla', (
      tester,
    ) async {
      telefonoChico(tester);
      await tester.pumpWidget(
        testApp(
          SendaOnboardingScreen(
            auth: sinConexion(),
            reservedHandles: nonaConfig.reservedHandles,
          ),
          locale: idioma,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // El alta es una lista perezosa: lo que cae por debajo del borde no se
      // construye hasta que se baja. Se baja como bajaría el dedo, y si nada
      // se desplaza, esto no llega nunca y la prueba cae aquí.
      final lista = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byType(AvatarGrid),
        150,
        scrollable: lista,
      );
      rejillaEntera(tester);
      await tester.scrollUntilVisible(
        find.byType(FilledButton),
        150,
        scrollable: lista,
      );
      await alcanzable(tester, find.byType(FilledButton));
    });

    testWidgets('$lc: el editor de perfil deja llegar al país, a Guardar y a '
        'borrar la cuenta', (tester) async {
      telefonoChico(tester);
      final prefs = await SharedPreferences.getInstance();
      final auth = sinConexion();
      // Con `deletion`, como lo abre Ajustes: borrar la cuenta es lo último de
      // la hoja, y por eso lo primero que se queda fuera.
      final borrado = SendaAccountDeletion(
        auth: auth,
        gameId: nonaGameId,
        session: SessionSync(
          prefs,
          ownedPrefixes: nonaConfig.ownedPrefKeyPrefixes,
        ),
      );
      addTearDown(borrado.dispose);

      await tester.pumpWidget(
        testApp(
          abridor(
            (context) => showSendaProfileEditSheet(
              context,
              auth: auth,
              config: nonaConfig,
              deletion: borrado,
            ),
          ),
          locale: idioma,
        ),
      );
      await tester.tap(find.byKey(const Key('abrir')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      rejillaEntera(tester);
      final hoja = find.byType(BottomSheet);
      await alcanzable(
        tester,
        find.descendant(
          of: hoja,
          matching: find.byIcon(Icons.expand_more_rounded),
        ),
      );
      await alcanzable(tester, find.byKey(const Key('senda.profile.save')));
      await alcanzable(
        tester,
        find.descendant(of: hoja, matching: find.byType(TextButton)),
      );
    });

    testWidgets('$lc: la hoja del @usuario deja llegar a Guardar', (
      tester,
    ) async {
      telefonoChico(tester);
      await tester.pumpWidget(
        testApp(
          abridor(
            (context) => showSendaUsernameChangeSheet(
              context,
              actual: 'nona',
              ultimoCambio: null,
              cambiar: (_) async {},
              disponible: (_) async => true,
            ),
          ),
          locale: idioma,
        ),
      );
      await tester.tap(find.byKey(const Key('abrir')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await alcanzable(tester, find.byKey(const Key('senda.username.field')));
      await alcanzable(tester, find.byKey(const Key('senda.username.save')));
    });
  }
}
