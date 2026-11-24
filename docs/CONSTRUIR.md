# Construir Minesweeper, de principio a fin

Todo lo que hay que hacer para que exista una build de Minesweeper, en orden,
con lo que se rompe en silencio en cada paso.

La doctrina —por qué las dos plataformas a la vez, por qué la versión se lee
dentro del binario, qué guarda el archivo— está en `tools/archivar_build.py`.
Este documento se heredó de Nona y se rehízo para Minesweeper el 23-11-2026,
con la build 15, que fue la primera con AAB e IPA a la vez: las 1-14 se
construyeron solo para Android, desde Windows.

---

## 0. Antes de tocar nada

```
df -h /                                        # una build de iOS puede llenar el disco
python3 tools/archivar_build.py verificar
```

- **El disco.** En el Mac llegó a 239 MB libres el 23-11-2026. Lo que se lo
  come, medido: la caché de Gradle (~5 GB la primera vez que se construye el
  AAB), DerivedData de Xcode (~4,5 GB), el swap (cada simulador encendido
  empuja memoria a disco; con dos a la vez el disco se vació solo) y el primer
  arranque de un simulador de iPad (~1,5 GB de recursos del sistema). Con
  menos de ~5 GB libres, **no construyas encima**: limpia antes (paso 6) y
  apaga los simuladores. Cuando el disco llega a cero deja de funcionar hasta
  Bash.
- **El swap también es disco.** El 24-11-2026, con 8,8 GB libres y la caché de
  Gradle vacía, el AAB se comió la caché (4,8 GB) y el swap creció otros ~3 GB:
  falló por disco. Para que Gradle pida menos memoria (y menos swap) sin tocar
  el `gradle.properties` del proyecto:
  `export GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g"`.
- **Si borras `app/build` a medias, borra también `app/.dart_tool/flutter_build`.**
  Los `.symbols` los escribe el compilador de Dart en `app/build/symbols` como
  efecto lateral, pero el Dart compilado se guarda en `.dart_tool/flutter_build/`.
  Con `app/build` borrado y esa caché viva, la build siguiente reutiliza el
  compilado, no recompila, **y sale `✓ Built` sin un solo `.symbols`** — un AAB
  ofuscado que nadie podrá leer en Sentry. Pasó dos veces el 24-11-2026 (y se
  culpó al disco, que no era). Mira `ls app/build/symbols` antes de archivar.
- **El orden.** AAB primero, IPA después, **nunca a la vez**. Al acabar el AAB,
  `./gradlew --stop` dentro de `app/android` suelta la memoria de los daemons.
- **La auditoría.** En este Mac `verificar` solo puede ver de la 15 en adelante:
  las 1-14 se archivaron en la máquina de Windows y el registro lo dice en cada
  fichero (`podado: … no está en este Mac`). Si sale un `FALTA` de la 15 o
  posterior, resuélvelo **antes** de construir otra: la nueva pisa la anterior.

---

## 1. El número de versión

Se sube en `app/pubspec.yaml`, línea `version:`, con el porqué escrito al lado.

- Mientras Minesweeper **no esté a la venta**, se queda en `1.0.0` y solo sube
  el número de build.
- En cuanto una versión esté `READY_FOR_SALE` en Apple, la siguiente build tiene
  que subir el de versión: Apple no deja reenviar una versión a la venta, y un
  build cuyo número no coincide con la entrada de versión **sube bien y no se
  puede adjuntar**. Le pasó a Nona con la 1.0.1.

---

## 2. Las dos mitades, del mismo pubspec

```
cd app
export LANG=en_US.UTF-8

flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols

flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols \
  --export-options-plist=ios/ExportOptions.plist
```

**Las dos, siempre.** Un AAB sin su IPA no es una build: la firma no es
determinista y App Store Connect no acepta un número de build repetido, así que
la mitad que falte ya no se puede rehacer igual.

Lo que no es obvio:

- **`export LANG=en_US.UTF-8`.** Sin esto CocoaPods muere y Flutter cae a SPM
  en silencio.
- **Firma de Android: la llave de subida es la de PRende.** Minesweeper se
  firma con `~/keystores/prende-upload-keystore.jks` (huella SHA-1
  `35:50:18:4A:…:0F:F7`, la que Play tiene registrada como llave de subida de
  `com.sendallc.minesweeper`). `app/android/key.properties` es una copia del de
  PRende y **no va a git**. Sin ese fichero Gradle firma con la de depuración, y
  Play rechaza el AAB.
- **Firma de iOS: perfil «Minesweeper App Store».** Creado el 23-11-2026 por la
  API de App Store Connect (bundle `ZXF5PV562K`, certificado de distribución
  `U9RBM8PB2M`) e instalado en
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`. Lo nombran
  `project.pbxproj` (Release) y `ios/ExportOptions.plist`. **Caduca con el
  certificado, el 5-6-2027.** Hasta la build 15 los dos ficheros seguían
  apuntando a «Nona App Store», que es de otro bundle id: con él la IPA no
  podía existir.
- **`--export-options-plist` hace falta.** `flutter build ipa` a secas falla al
  exportar pidiendo un perfil con Push y Sign in with Apple: el perfil está
  bien, lo que falta es decirle cuál es.
- **`--obfuscate --split-debug-info` en las DOS.** Sin ellos no hay `.symbols`
  de Dart que subir a Sentry, y las trazas llegan ilegibles.

Salen en rutas **fijas, sin número de build**:

```
app/build/app/outputs/bundle/release/app-release.aab
app/build/ios/ipa/minesweeper.ipa
app/build/symbols/*.symbols
```

La build siguiente las pisa sin avisar. Hasta que estén archivadas (paso 4),
están a una compilación de desaparecer.

---

## 3. Los símbolos, a Sentry

```
cd app && dart run sentry_dart_plugin
```

Lo lee de `pubspec.yaml` (`sentry: project: minesweeper / org: senda-6q`) y
necesita `SENTRY_AUTH_TOKEN`, exportado en `~/.zshenv`.

- **Proyecto propio desde la build 16.** Hasta la 15 incluida Minesweeper
  informaba al proyecto `nona` (DSN copiado al convertir el juego): los fallos
  de esas builds, y sus símbolos, están allí. El DSN de `lib/sentry_config.dart`
  y el `project:` del pubspec tienen que ser **el mismo proyecto**;
  `telemetria_test.dart` lo vigila.
- **Sale con código 1 y no es un fallo de los símbolos.** Al final intenta
  asociar commits a la release y dice `Could not find the SHA of the previous
  release`: los símbolos ya se subieron antes (`☑ uploading debug symbols`).
- **El mapa de ofuscación de Dart no se sube** (`no 'dart_symbol_map_path'
  provided`): ni aquí ni en Nona está configurado. Los `.symbols` sí van, y
  también se guardan en el archivo local (paso 4).
- El token de `~/.zshenv` **solo** sirve para subir releases y símbolos: no
  puede leer ni crear proyectos. Eso se hace en sentry.io.

---

## 4. Archivar — es parte de construir

```
python3 tools/archivar_build.py archivar
```

Verifica **dentro** de los dos binarios (versión, identificador, que no haya
slice de simulador, `aps-environment` de producción…), los copia a
`~/Minesweeper-releases/` con su nombre numerado y su `.sha256`, y apunta la
build en `archivo-de-builds.json` con su `commit` y si el árbol estaba limpio.

- `✖ UN AAB SIN SU IPA NO ES UNA BUILD` (salida 2): falta una mitad. Constrúyela
  desde el **mismo** pubspec y repite.
- `No archivo: los binarios no son lo que este árbol dice` (salida 3): léelo
  entero; cada comprobación existe porque ese fallo ya llegó a una tienda.
- `✔ pareja completa archivada`: ahora, y solo ahora, se sube.

Si el árbol está sucio lo avisa y **archiva igual**; el registro lo apunta
(`arbol_limpio: false`). Después hay que commitear `archivo-de-builds.json`, o
`archivo_de_builds_test.dart` no sabrá que la build existe.

---

## 5. Subir

**Android, a pruebas internas de Play** — lo hace esta sesión:

```
python3 tools/upload_play_internal.py \
  --aab ~/Minesweeper-releases/minesweeper-<versión>-<build>.aab \
  --key ~/.playconsole/prende-publisher.json \
  --notes-es "• …" --notes-en "• …"
```

- Se sube **el AAB archivado**, no el de `app/build`: son los mismos bytes y no
  depende de que nadie haya construido otra cosa entretanto.
- **La cuenta de servicio es la de PRende** (`prende-play-publisher@prende-3dd30`).
  Tiene sobre Minesweeper los mismos 9 permisos que sobre Nona **desde el
  23-11-2026**. Antes solo tenía los de cuenta (leer y preparar ediciones), y
  la subida caía en el último paso con un `403 PERMISSION_DENIED`, sin cambiar
  nada en Play. Si vuelve a pasar: Play Console → Usuarios y permisos →
  esa cuenta → Minesweeper.
- **Las notas van por build** (`--notes-es` / `--notes-en`). Sin ellas la
  release solo lleva el número.
- La comprobación del `versionCode` la hace `archivar` dentro del binario, y
  Play rechaza un número repetido. Después, apúntalo en el registro:
  `python3 tools/archivar_build.py tienda <build> "Play pruebas internas, <fecha>"`.

**iOS, a App Store Connect (TestFlight):**

```
bash tools/subir_testflight.sh <build>
```

Sube la IPA **archivada** (comprueba su sha256 y, dentro, bundle id y número
de build) con la llave del equipo (`VC5Y48T3Z4`, en
`~/.appstoreconnect/private_keys/`). Hasta la 15 la subía André a mano; la 15
la subió esta sesión a petición suya (24-11-2026). Después, el registro:
`python3 tools/archivar_build.py tienda <build> "… · App Store Connect (TestFlight), <fecha>"`.

- **La entrada de versión tiene que decir lo mismo que la IPA.** Se creó como
  «1.0» y la IPA dice «1.0.0»: se cambió a 1.0.0 el 24-11-2026 (Nona aprendió
  con la 1.0.1 que un número distinto sube bien y luego no se puede adjuntar).
- **Cumplimiento de exportación:** desde la 16, `Info.plist` declara
  `ITSAppUsesNonExemptEncryption = false` (como CINCO y Minigrama). La 15 no la
  lleva y espera la respuesta a mano en App Store Connect.

### Cuando ya está a la venta: publicar su número

El aviso «Hay una versión nueva» compara la build del teléfono con
`public/versiones`. Se publica **cuando la versión YA se puede descargar**,
nunca al subirla a pruebas:

```
cd ~/Documents/Coding/"Juegos Senda"/backend
node tools/publicar-version.js minesweeper android <build>
node tools/publicar-version.js minesweeper ios <build>
```

Escribe en producción con permisos de servidor y se niega a bajar un número.

---

## 6. Limpiar

```
python3 tools/archivar_build.py limpiar               # dice cuánto
python3 tools/archivar_build.py limpiar --de-verdad   # lo hace
```

Se niega si la build de `app/build` **no** está ya archivada con los mismos
bytes: la única forma cómoda de liberar espacio es archivar primero.

Lo demás que se puede borrar sin perder nada, por orden de cuánto da:
`~/.gradle/caches` (~5 GB; la próxima build de Android de cualquier juego
vuelve a descargar), DerivedData de Xcode (`~/Library/Developer/Xcode/DerivedData`)
y las carpetas `build/` de los demás juegos (todas en `.gitignore`).
**Nunca** `~/Nona-releases` ni `~/Minesweeper-releases`: son binarios que no se
pueden rehacer.

---

## Trampas, con su fecha

| Síntoma | Causa | Cómo se nota |
|---|---|---|
| `flutter build ipa` falla pidiendo un perfil con Push/Sign in with Apple | falta `--export-options-plist` | error al exportar; el perfil está bien |
| La IPA no se puede firmar (23-11-2026) | Release y `ExportOptions.plist` apuntaban a «Nona App Store» | error de perfil al archivar |
| Play rechaza el AAB por la firma | falta `app/android/key.properties` (firma de depuración) | rechazo al subir |
| La subida a Play cae en el commit con 403 (23-11-2026) | la cuenta de servicio no tenía permisos sobre Minesweeper | todo sube bien y nada se publica |
| CocoaPods muere, Flutter se pasa a SPM | falta `export LANG=en_US.UTF-8` | silencioso hasta que algo no enlaza |
| El disco se vacía durante la build (23-11-2026) | caché de Gradle + swap de simuladores encendidos | Bash deja de responder |
| El AAB sale sin `.symbols` (24-11-2026) | se borró `app/build` y no `app/.dart_tool/flutter_build`: la build reutilizó el Dart compilado | `✓ Built`: solo se ve mirando `app/build/symbols/` |
| Los avisos push se registran y no llegan nunca | `aps-environment` ausente | **nada** |
| Google Sign-In abre el navegador y la app no reacciona | `CFBundleURLTypes` ausente o copiado de otro juego | **nada**: un botón muerto |
| App Store Connect rechaza la IPA | slice de simulador | rechazo días después |
| Los fallos de Minesweeper salen en el proyecto de Nona (hasta la build 15) | DSN copiado de Nona | **nada**: llegan, mezclados |

---

## Rescate: exportar sin recompilar

Si el `.xcarchive` ya está hecho y solo falló la exportación:

```
cd app && xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/ios/ipa
```

Sirve mientras el `.xcarchive` sea el de esa build: `build/ios/archive/` también
es una ruta fija y la siguiente construcción lo pisa.

---

## Lo que esta sesión no hace

Enviar a revisión ni publicar en producción: eso lo decide André. Aquí se
construye, se verifica, se archiva y se sube a pruebas (AAB a pruebas internas
de Play; la IPA a TestFlight cuando André lo pide); y cuando una versión ya está
a la venta, se publica su número (§5).
