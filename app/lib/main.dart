import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'firebase_options.dart';

/// ARNÉS DE VERIFICACIÓN A4 — no es la app de Nona.
///
/// Existe para contestar UNA pregunta, la que sostiene todo el diseño de
/// cuentas compartidas: ¿la misma cuenta de Apple produce el mismo `uid` de
/// Firebase en CINCO y en Nona?
///
/// Por qué hay que medirlo en vez de razonarlo: el plan de cuentas §2 da por
/// hecho que el identificador de Sign in with Apple es estable por equipo de
/// desarrollo. Ninguna página de documentación de Apple lo afirma tal cual —lo
/// comprobamos—, y el App ID de Nona está *agrupado* bajo el primario de CINCO,
/// que es un matiz distinto. Si el uid NO coincidiera, la identidad compartida
/// se rompería para todo usuario de Apple y habría que enterarse ahora, no
/// después de publicar.
///
/// Dato previo (firebase auth:export sobre cinco-fe5cc): 24 cuentas, TODAS de
/// google.com y ninguna de Apple. Nadie ha completado nunca un Sign in with
/// Apple, así que no hay ningún `sub` establecido que romper y la prueba parte
/// de cero.
///
/// Este fichero se sustituye entero cuando empiece la app de verdad.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const A4Harness());
}

class A4Harness extends StatelessWidget {
  const A4Harness({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nona · A4',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: const _A4Screen(),
  );
}

class _A4Screen extends StatefulWidget {
  const _A4Screen();

  @override
  State<_A4Screen> createState() => _A4ScreenState();
}

class _A4ScreenState extends State<_A4Screen> {
  String? _error;
  bool _busy = false;

  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Mismo flujo que CINCO (`auth_controller.dart`), a propósito: si la prueba
  /// usara otro camino, un resultado distinto no diría nada sobre la app real.
  Future<void> _signInWithApple() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rawNonce = _randomNonce();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final credential = OAuthProvider(
        'apple.com',
      ).credential(idToken: apple.identityToken, rawNonce: rawNonce);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) {
            final user = snap.data;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Nona · verificación A4',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '¿La misma cuenta de Apple da el mismo uid en CINCO y en '
                    'Nona?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  if (user == null) ...[
                    FilledButton(
                      onPressed: _busy ? null : _signInWithApple,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _busy ? 'Abriendo…' : 'Entrar con Apple',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'uid de Firebase',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      user.uid,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'proveedores: '
                      '${user.providerData.map((p) => p.providerId).join(', ')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
