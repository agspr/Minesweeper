# Construir Nona, de principio a fin

Todo lo que hay que hacer para que exista una build de Nona, en orden, con lo
que se rompe en silencio en cada paso.

La doctrina que hay detrás —por qué las dos plataformas a la vez, por qué la
versión se lee dentro del binario, qué guarda el archivo— está en
`tools/archivar_build.py`, que vive en este repositorio.

El guion NO se copió al paquete compartido a propósito: hacer que construir
Nona dependa de tener el repo hermano al lado es una atadura que no paga lo que
cuesta. Está escrito para poder copiarse tal cual a otro juego —deduce la
carpeta y el prefijo del repositorio donde vive—, y esa es la forma de
compartirlo que no ata a nadie.
Aquí van **las rutas y las trampas de Nona**.

Antes de este documento, este procedimiento estaba disperso dentro de
`legal/PENDIENTE.md`, que es el registro de traspaso con el agente de ficha: el
sitio equivocado para algo que hay que releer cada vez que se construye.

---

## 0. Antes de tocar nada

```
df -h /                                        # una build de iOS puede llenar el disco
python3 tools/archivar_build.py verificar
```

Dos motivos, los dos con historia:

- **El disco.** Esta máquina ha llegado a cero tres veces; cuando pasa, deja de
  funcionar hasta Bash. Con menos de ~5 GB libres, limpia antes (`limpiar`,
  paso 6) y **no construyas encima**: la segunda build se lleva por delante lo
  que la primera dejó sin archivar. Así se perdió el IPA de la 28.
- **La auditoría.** Contesta en un segundo la pregunta que nadie hizo durante
  cinco días: *¿está todo lo que debería estar?* Si sale un `✖ FALTA EL IPA`,
  resuélvelo o anótalo **antes** de crear una build nueva, porque la nueva borra
  la evidencia de la anterior.

Si hay otro agente vivo trabajando en el disco, pídele turno por mensaje. Las
builds de iOS y las suyas no caben a la vez.

---

## 1. El número de versión

Se sube en `app/pubspec.yaml`, línea `version:`, y **se sube el de versión, no
solo el de build**, siempre que la versión anterior ya esté publicada:

- Apple **no deja reenviar una versión `READY_FOR_SALE`**. 1.0.1 salió a la
  venta con el build 28, así que el 29 tuvo que ser 1.0.2. Un build solo se
  adjunta a una entrada de versión cuyo número **coincida**: con el número mal
  puesto, el build sube bien y **no se puede adjuntar** — media hora de
  compilación tirada y el diagnóstico a kilómetros de la causa. Ya pasó.
- En Play no hay este problema, pero el `versionName` de la release sale de aquí
  igual, así que el agente de ficha tiene que saberlo antes de publicar.
- El porqué del número concreto se escribe **en el propio pubspec**, junto al
  número, para que nadie lo devuelva sin querer.

Que Apple salga sola en cuanto apruebe (`releaseType: AFTER_APPROVAL`) es cosa
del agente de ficha y hay que ponerlo **en cada versión nueva**; no es un ajuste
de la app. Está en `legal/PENDIENTE.md`, regla del 4-9-2026.

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

**Las dos, siempre, seguidas.** Un AAB sin su IPA no es una build: es la mitad
de una, y la mitad que falta ya no se puede reproducir igual (la firma no es
determinista, y App Store Connect rechaza un número de build repetido, así que
ese "28" reconstruido no podría subirse como 28 jamás).

Las tres cosas que no son obvias:

- **`export LANG=en_US.UTF-8`.** Sin esto CocoaPods muere y Flutter cae a SPM
  en silencio. Viene de CINCO, misma máquina y mismo montaje.
- **`--export-options-plist` hace falta.** `flutter build ipa` a secas **falla**
  al exportar: genera sus propias opciones, no dice qué perfil usar, el
  exportador coge uno cualquiera del equipo y suelta `requires a provisioning
  profile with the Push Notifications and Sign In with Apple features`. **El
  perfil está bien** — no hay nada que tocar en el portal de Apple; lo que falta
  es el fichero. Está comentado dentro de `ios/ExportOptions.plist`, pero el
  comentario no impide lanzar el comando corto, así que también está aquí.
- **`--obfuscate --split-debug-info` en las DOS.** Sin ellos no hay `.symbols`
  de Dart que subir a Sentry, y las trazas de esa versión llegan ilegibles. No
  falla nada: llegan, y no se entienden.

Salen en rutas **fijas, sin número de build en el nombre**:

```
app/build/app/outputs/bundle/release/app-release.aab
app/build/ios/ipa/nona.ipa
app/build/symbols/*.symbols
```

Que sean fijas es la causa de fondo de todo este documento: **la build
siguiente las pisa sin avisar.** Hasta que no estén archivadas (paso 4), están a
una compilación de desaparecer.

---

## 3. Los símbolos, a Sentry

```
cd app && dart run sentry_dart_plugin
```

Lo lee todo de `pubspec.yaml` (`sentry: project: nona / org: senda-6q /
upload_debug_symbols: true`) y necesita `SENTRY_AUTH_TOKEN`, que ya está
exportado en `~/.zshenv` — por eso nadie se acuerda de él, y por eso su ausencia
sería invisible hasta que alguien mirase la salida.

**Qué no se puede comprobar después:** nadie guarda el código de salida de este
comando, y no hay log ni `.sentryclirc`. De la build 28 lo único que quedó fue
una huella indirecta —el `sentry-cli` que el plugin se descarga solo, creado un
minuto después de exportarse el IPA— que **corrobora** que se ejecutó pero no
prueba que terminara bien. Si te importa saberlo, mira Debug Files de esa
liberación en Sentry, desde una sesión interactiva con el MCP autorizado (`/mcp`).

Por eso los `.symbols` de Dart **también se guardan en el archivo local**
(paso 4): Apple tiene los dSYMs, pero el mapa de ofuscación de Dart solo existe
aquí y en Sentry.

---

## 4. Archivar — esto es parte de construir, no lo que viene después

```
python3 tools/archivar_build.py archivar
```

Verifica **dentro** de los dos binarios, los copia a `~/Nona-releases/` con su
nombre numerado, escribe el `.sha256` con la procedencia y crea la etiqueta
`v<version>+<build>`. Si algo no cuadra, no archiva y dice qué.

Los tres finales posibles:

- **`✖ UN AAB SIN SU IPA NO ES UNA BUILD` (salida 2).** Falta una mitad. No
  archiva la otra: media pareja archivada es justo lo que hizo que la pérdida de
  la 28 tardara cinco días en verse, porque *parecía* que había algo. Construye
  la mitad que falta desde el **mismo** pubspec y repite.
- **`No archivo: los binarios no son lo que este árbol dice` (salida 3).** La
  versión no casa, o el identificador es de otro juego, o las dos mitades tienen
  números distintos, o hay slice de simulador, o `aps-environment` no es
  `production`, o el esquema de URL no es el `REVERSED_CLIENT_ID` de Nona. Léelo
  entero: cada una de esas comprobaciones existe porque el fallo correspondiente
  ya se envió a una tienda alguna vez, y **ninguno da error en ejecución** —
  dan un botón muerto, un aviso que no llega, un rechazo tres días después.
- **`✔ pareja completa archivada`.** Ahora, y solo ahora, se puede subir.

Si el árbol está sucio lo avisa, pero **archiva igual**: un problema de
metadatos no puede costar un binario. La regla vale para todo lo que hace este
guion — nada que no sea «estas dos mitades no son la misma build» o «esto es de
otro juego» llega a impedir el archivado. Un guion que se planta cuando más
falta hace es un guion que alguien salta con `cp`, y entonces no queda registro
de nada.

> El registro ya está sembrado hacia atrás con `reconstruir`, leyendo los
> binarios que había en el disco: cubre de la build 10 a la 29. No inventa el
> commit de las viejas —deducirlo por marcas de tiempo sería adivinar—, pero fija
> los bytes y el sha256 de cada una, y deja escrito **dentro del archivo** que a
> la 28 le falta el IPA y por qué. Hasta ahora eso solo vivía en la cabeza de
> alguien, y por eso se tardó cinco días en notarlo.

---

## 5. Entregar al agente de ficha

Esta sesión **no sube nada a ninguna tienda**. Se le deja al agente de ficha una
nota en `legal/PENDIENTE.md` con:

- versión y número de build, y **por qué** ese número de versión;
- lo verificado dentro de los binarios (lo imprime `tools/archivar_build.py`: identificador,
  versión, perfil, `aps-environment`, arquitecturas);
- qué cambió respecto a la build anterior, marcando **lo que le afecta a él**
  (una captura desfasada, un texto de ficha, un permiso nuevo);
- dónde están los ficheros: `~/Nona-releases/nona-<version>-<build>.{aab,ipa}`.

---

## 6. Limpiar

```
python3 tools/archivar_build.py limpiar               # dice cuánto
python3 tools/archivar_build.py limpiar --de-verdad   # lo hace
```

Se niega si la build que hay en `app/build` **no** está ya en el archivo con los
mismos bytes. Es a propósito y es el cierre del círculo: en esta máquina el
disco se llena, y cuando se llena alguien borra cosas con prisa. Que la única
forma cómoda de liberar espacio sea *archivar primero* convierte la presión de
disco en el motivo para archivar, en vez de en el motivo para perder un binario.

`app/build` ocupa ~2,1 GB de los que casi todo es reproducible. Lo único que no
está en el archivo son los dSYMs del `.xcarchive` (519 MB), y esos están en
Apple (`uploadSymbols => true` en `ios/ExportOptions.plist`) y en Sentry.

---

## Trampas, con su fecha

| Síntoma | Causa | Cómo se nota |
|---|---|---|
| `flutter build ipa` falla pidiendo un perfil con Push/Sign in with Apple | falta `--export-options-plist` | error al exportar; el perfil está bien |
| CocoaPods muere, Flutter se pasa a SPM | falta `export LANG=en_US.UTF-8` | silencioso hasta que algo no enlaza |
| Los avisos push se registran y no llegan nunca | `aps-environment` ausente del `Info.plist` | **nada**: no hay error en ninguna parte |
| Google Sign-In abre el navegador, completa y la app no reacciona | `CFBundleURLTypes` ausente | **nada**: un botón muerto |
| Igual, pero con el esquema puesto | esquema copiado de CINCO: su `REVERSED_CLIENT_ID` es otro | peor que ausente: pasa una mirada rápida |
| App Store Connect rechaza el IPA (10-8-2026, CINCO) | slice `x86_64`/`i386` de simulador | rechazo días después de subir |
| El build sube y no se puede adjuntar a la versión | el número del pubspec no coincide con la entrada de versión | media hora de compilación tirada |
| El árbol `build/` dice un número y el AAB otro | metadatos rancios de `build/` | por eso la versión se lee **dentro** |

Todas se comprueban solas en el paso 4, menos las dos primeras, que impiden que
llegue a haber binario.

---

## Rescate: exportar sin recompilar

Si el `.xcarchive` ya está hecho y solo falló la exportación:

```
cd app && xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/ios/ipa
```

Sirve mientras el `.xcarchive` sea el de esa build. En cuanto se construye otra
cosa, deja de servir: `build/ios/archive/` también es una ruta fija y también se
pisa. **Ese fue el segundo clavo del ataúd de la 28**: cuando se buscó su IPA,
ni el IPA ni el archive eran ya suyos, y `~/Library/Developer/Xcode/Archives`
estaba vacío.

---

## Lo que esta sesión no hace

Sube a las tiendas el agente de ficha (Play Console, App Store Connect, AdMob,
`legal/`, `store/`). Aquí se construye, se verifica y se archiva. Si hace falta
cruzar esa línea, lo pide André directamente y solo para esa tarea.
