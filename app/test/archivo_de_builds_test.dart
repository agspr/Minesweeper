import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Un binario que se pierde no da error: deja de existir.**
///
/// El 3-9-2026 se archivó el AAB del build 28 y no su IPA. Nadie se enteró
/// hasta cinco días después, porque no hay nada que falle cuando un fichero no
/// se copia: `flutter build ipa` escribe siempre en `build/ios/ipa/nona.ipa`,
/// sin número de build en el nombre, y la exportación de la 29 (6-9, 10:42) lo
/// pisó. El IPA de la 28 no está en este disco ni en ningún respaldo — no hay
/// Time Machine — y no se puede reconstruir: App Store Connect no acepta dos
/// veces el mismo número de build, así que un «28» recompilado sería otro
/// binario con la misma etiqueta. La 29 estuvo a punto de irse por el mismo
/// desagüe: su IPA se archivó el 8-9, dos días tarde.
///
/// La memoria falló dos veces seguidas, así que esta prueba es la memoria.
/// **La autoridad es `archivo-de-builds.json`, que está en git**, no la carpeta
/// `~/Nona-releases`, que está fuera del repositorio y puede no existir en otra
/// máquina. Por eso las reglas que de verdad muerden no tocan el disco: leen el
/// registro y el historial de `pubspec.yaml`. La comprobación contra el disco
/// va aparte y al final, y es la única que puede saltarse.
///
/// El precio, dicho de frente: cada número de build que exista y no se archive
/// hay que justificarlo en una línea del registro
/// (`archivar_build.py saltar N "razón"`). Es lo que convierte una ausencia en
/// una decisión con fecha. Sin ese precio no hay forma de distinguir «esta
/// build nunca existió» de «esta build se perdió», y esa es exactamente la
/// distinción que aquí se perdió con la 18 y la 28.
void main() {
  // Las pruebas de Flutter corren con el cwd en `app/`; el registro vive en la
  // raíz del repositorio, un nivel arriba, porque no es de la app: es del
  // proyecto. Si algún día se corre desde la raíz, el segundo intento acierta.
  final raiz = <String>['..', '.']
      .map((d) => Directory(d).absolute.path)
      .firstWhere(
        (d) => File('$d/archivo-de-builds.json').existsSync(),
        orElse: () => '',
      );

  test('el registro de builds existe y se puede leer', () {
    expect(
      raiz,
      isNotEmpty,
      reason:
          'no encuentro archivo-de-builds.json. Es el único sitio donde consta '
          'qué binarios existen: sin él, perder uno vuelve a ser invisible. '
          'Se siembra con: python3 tools/archivar_build.py reconstruir',
    );
  });
  if (raiz.isEmpty) return; // sin registro, el resto no puede decir nada.

  final registro =
      jsonDecode(File('$raiz/archivo-de-builds.json').readAsStringSync())
          as Map<String, dynamic>;
  final builds = (registro['builds'] as Map<String, dynamic>);
  final desde = (registro['desde'] as Map<String, dynamic>)['build'] as int;
  final prefijo = registro['prefijo'] as String;

  final pubspec = File('pubspec.yaml').readAsStringSync();
  final mVersion = RegExp(
    r'^version:\s*([0-9.]+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec)!;
  final versionActual = mVersion.group(1)!;
  final buildActual = int.parse(mVersion.group(2)!);

  int mayor() =>
      builds.keys.map(int.parse).fold(0, (a, b) => a > b ? a : b);

  test('un AAB sin su IPA no es una build', () {
    // LA REGLA. Copiada de CINCO/CLAUDE.md L34-35, donde ya estaba escrita y
    // donde nadie la comprobaba. Una entrada a medias solo puede quedarse así
    // si alguien escribió POR QUÉ: la incidencia es el acta de defunción del
    // binario, y sin ella una pérdida se lee igual que una build normal.
    final rotas = <String>[];
    for (final n in builds.keys.toList()..sort(_porNumero)) {
      final e = builds[n] as Map<String, dynamic>;
      if (e.containsKey('saltada')) continue;
      final incidencia = (e['incidencia'] as String?)?.trim() ?? '';
      final falta = <String>[
        if (e['aab'] == null) 'AAB',
        if (e['ipa'] == null) 'IPA',
      ];
      if (falta.isEmpty) continue;
      if (incidencia.isEmpty) {
        rotas.add('build $n: falta el ${falta.join(" y el ")} y nadie ha '
            'anotado por qué');
      }
    }
    expect(
      rotas,
      isEmpty,
      reason:
          '${rotas.join("\n  ")}\n\n'
          'O el binario existe y hay que archivarlo, o se perdió y hay que '
          'decirlo:\n'
          '  python3 tools/archivar_build.py archivar\n'
          '  python3 tools/archivar_build.py incidencia N "qué pasó"',
    );
  });

  test('no hay huecos: cada número entre la primera y la última está anotado', () {
    // El hueco es la forma que tiene una pérdida de pasar desapercibida. La 18
    // de Nona es un hueco LEGÍTIMO (b83455d: «El 18 no llego a salir entera»),
    // y precisamente por eso tiene que estar escrito: un hueco explicado y uno
    // olvidado se ven igual desde fuera.
    final huecos = <int>[];
    for (var n = desde; n <= mayor(); n++) {
      if (!builds.containsKey('$n')) huecos.add(n);
    }
    expect(
      huecos,
      isEmpty,
      reason:
          'sin anotar: ${huecos.join(", ")}.\n'
          'Si esa build nunca llegó a salir: '
          'python3 tools/archivar_build.py saltar N "razón".\n'
          'Si salió y no se archivó, el binario ya no existe: anótalo con '
          '`incidencia` para que conste.',
    );
  });

  test('toda versión que estuvo en el pubspec está en el registro', () {
    // Esta es la que habría cazado la 28 EL MISMO DÍA: al subir el pubspec a
    // 1.0.2+29 el 6-9, la 28 ya no era «la build en curso» y no tenía par.
    // El historial de git es la única fuente que dice qué números existieron
    // de verdad; el registro solo sabe lo que alguien le contó.
    final git = Process.runSync('git', [
      '-C', raiz, 'log', '-p', '--format=%H', '--', 'app/pubspec.yaml',
    ]);
    final vistas = RegExp(r'^\+version:\s*[0-9.]+\+(\d+)\s*$', multiLine: true)
        .allMatches(git.stdout as String)
        .map((m) => int.parse(m.group(1)!))
        .toSet();
    // Verde por falta de datos es la forma más común de estar verde por el
    // motivo equivocado: sin historial esta prueba no comprueba NADA, así que
    // se cae en vez de aprobar.
    //
    // Con UNA excepción, y hay que distinguirla o la regla se vuelve ruido: un
    // clon superficial (`git clone --depth 1`) no tiene historial porque nadie
    // se lo dio, no porque algo vaya mal. Ahí ponerse roja no denuncia nada y
    // entrena a saltarse el rojo. Se salta, diciéndolo. En la máquina que
    // archiva —que es donde esta prueba tiene que morder— el clon es completo
    // y la regla sigue entera.
    final superficial = Process.runSync('git', [
      '-C', raiz, 'rev-parse', '--is-shallow-repository',
    ]);
    if ((superficial.stdout as String).trim() == 'true') {
      markTestSkipped(
        'clon superficial: no hay historial de app/pubspec.yaml que leer. '
        'SALTADA NO ES APROBADA — en un clon completo esta prueba corre.',
      );
      return;
    }
    expect(
      vistas.length,
      greaterThan(4),
      reason:
          'no pude leer el historial de app/pubspec.yaml (git dijo: '
          '${(git.stderr as String).trim()}). Esta prueba no puede estar en '
          'verde sin datos.',
    );
    final sinArchivar = vistas
        .where((n) => n >= desde && n != buildActual && !builds.containsKey('$n'))
        .toList()
      ..sort();
    expect(
      sinArchivar,
      isEmpty,
      reason:
          'estos números de build existieron en el pubspec y no constan en el '
          'archivo: ${sinArchivar.join(", ")}.\n'
          'Cada uno es un binario que puede haberse construido y perdido.',
    );
  });

  test('el nombre de cada fichero dice la misma versión que el registro', () {
    // El nombre es lo ÚNICO que lleva el número de build: `flutter build` no
    // lo pone. Si el nombre y el contenido se separan, el archivo miente con
    // toda la seguridad del mundo.
    final malos = <String>[];
    builds.forEach((n, valor) {
      final e = valor as Map<String, dynamic>;
      if (e.containsKey('saltada')) return;
      for (final ext in ['aab', 'ipa']) {
        final a = e[ext] as Map<String, dynamic>?;
        if (a == null) continue;
        final esperado = '$prefijo-${e["version"]}-$n.$ext';
        if (a['fichero'] != esperado) {
          malos.add('build $n: el registro llama "${a["fichero"]}" a lo que '
              'debería ser "$esperado"');
        }
        if ((a['sha256'] as String).length != 64) {
          malos.add('build $n ($ext): el sha256 no tiene 64 caracteres');
        }
        if ((a['bytes'] as int) <= 0) {
          malos.add('build $n ($ext): tamaño cero');
        }
      }
    });
    expect(malos, isEmpty, reason: malos.join('\n  '));
  });

  test('el pubspec no va por detrás del archivo', () {
    // Un registro por delante del pubspec significa que alguien rebobinó la
    // versión: el siguiente build reutilizaría un número ya gastado y Apple lo
    // rechazaría — o, peor, pisaría la entrada del que sí existe.
    expect(
      buildActual,
      greaterThanOrEqualTo(mayor()),
      reason:
          'el pubspec dice $versionActual+$buildActual y el archivo ya tiene '
          'la ${mayor()}',
    );
  });

  test('los ficheros que el registro promete siguen en el disco', () {
    // LA ÚNICA QUE MIRA FUERA DEL REPOSITORIO, y por eso es asimétrica:
    // · no existe la carpeta  → se salta (esta máquina no archiva; no hay nada
    //   que esta prueba pueda afirmar, y ponerse roja aquí entrenaría a todo el
    //   mundo a ignorar el rojo);
    // · existe la carpeta y falta un fichero → ROJA (eso es una pérdida).
    // Se comprueba tamaño exacto, no sha256: cotejar los hashes son ~2,3 GB de
    // lectura y esto corre en cada `flutter test`. El cotejo de verdad es
    // `python3 tools/archivar_build.py verificar --hash`, antes de una entrega.
    final carpeta = Directory(
      (registro['carpeta'] as String).replaceFirst(
        '~',
        Platform.environment['HOME'] ?? '~',
      ),
    );
    if (!carpeta.existsSync()) {
      markTestSkipped(
        'no existe ${carpeta.path}: esta máquina no guarda el archivo de '
        'binarios. SALTADA NO ES APROBADA — en la máquina que archiva, esta '
        'prueba tiene que correr.',
      );
      return;
    }
    final problemas = <String>[];
    // Lo que hay de verdad en la carpeta, para poder cotejar en los dos
    // sentidos: que esté lo que el registro promete Y que no esté lo que el
    // registro niega.
    final enDisco = carpeta
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    builds.forEach((n, valor) {
      final e = valor as Map<String, dynamic>;
      if (e.containsKey('saltada')) {
        // **Una build saltada no puede tener ficheros suyos en la carpeta.**
        // Antes esto era un `return` y ahí estaba el agujero: bastaba escribir
        // `"saltada": "luego lo miro"` para que una build a medio archivar
        // dejara de mirarse, con su AAB huérfano todavía en el disco. La
        // salida de emergencia era más barata que hacer el trabajo, que es la
        // forma exacta en que una prueba deja de proteger nada.
        final suyos = enDisco.where((f) => RegExp('-$n\\.[a-z]').hasMatch(f));
        for (final f in suyos) {
          problemas.add(
            'build $n dice que nunca salió, pero $f está en el disco: '
            'o salió, o ese fichero sobra',
          );
        }
        return;
      }
      for (final ext in ['aab', 'ipa', 'simbolos']) {
        final a = e[ext] as Map<String, dynamic>?;
        if (a == null || a['podado'] != null) continue;
        final f = File('${carpeta.path}/${a["fichero"]}');
        if (!f.existsSync()) {
          problemas.add('build $n: ${a["fichero"]} ya no está en el disco');
        } else if (f.lengthSync() != a['bytes']) {
          problemas.add('build $n: ${a["fichero"]} mide ${f.lengthSync()} y el '
              'registro dice ${a["bytes"]}');
        }
      }
    });
    expect(
      problemas,
      isEmpty,
      reason:
          '${problemas.join("\n  ")}\n\n'
          'Si el borrado fue a propósito, se anota como podado: '
          'python3 tools/archivar_build.py podar --dejar N --de-verdad',
    );
  });
}

int _porNumero(String a, String b) => int.parse(a).compareTo(int.parse(b));
