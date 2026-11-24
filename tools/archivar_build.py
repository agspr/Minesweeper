#!/usr/bin/env python3
"""Archiva una build entera, o no archiva nada.

EL FALLO QUE ESTO EXISTE PARA IMPEDIR (builds 28 y 29 de Nona, 3 y 6-9-2026):
`flutter build appbundle` y `flutter build ipa` escriben SIEMPRE en la misma
ruta fija — `build/app/outputs/bundle/release/app-release.aab` y
`build/ios/ipa/<juego>.ipa`. Ningún nombre lleva el número de build. La copia al
archivo es la ÚNICA copia que lo lleva, así que la build siguiente pisa a la
anterior en silencio: no hay error, no hay aviso, y el fichero deja de existir.
Como archivar eran DOS copias manuales (en las builds 10-27 se ven 5-15 minutos
de diferencia entre el .aab y el .ipa del archivo: dos actos separados), bastaba
con olvidar el segundo. Es lo que pasó con el IPA de la 28 — irrecuperable — y
casi con el de la 29, que estuvo dos días sin archivar.

Por eso aquí una build es UN PAR. No existe archivar medio par: los dos ficheros
se copian a nombres temporales, se comprueban por hash, y solo entonces se
renombran los dos. Si falta el IPA, esto sale con código 1 y NO deja nada
escrito — ni el AAB. Un AAB suelto en la carpeta es la mentira que hace creer
que la build está guardada.

La versión se lee DENTRO del binario, nunca de `pubspec.yaml` ni de los
metadatos de `build/`, que se quedan rancios y han llegado a decir un número
distinto del que el AAB llevaba (regla de CINCO/CLAUDE.md, sección Construir).

    python3 tools/archivar_build.py archivar
    python3 tools/archivar_build.py reconstruir      # siembra el registro desde el disco
    python3 tools/archivar_build.py verificar --hash # cotejo completo antes de una entrega
    python3 tools/archivar_build.py saltar 18 "no llegó a salir entera"
    python3 tools/archivar_build.py incidencia 28 "el IPA se perdió: ..."
    python3 tools/archivar_build.py podar --dejar 8
    python3 tools/archivar_build.py limpiar          # borra app/build ya archivado

VALE PARA CUALQUIER JUEGO DE LA FAMILIA sin tocar una línea: la carpeta
(`~/<Repo>-releases`) y el prefijo de los ficheros (el `name:` del pubspec) se
deducen del repositorio donde está el script. Comprobado contra los 77 binarios
archivados de Nona y de CINCO el 8-9-2026: en los 77 la versión de dentro
coincide con la del nombre, y las dos lecturas (AAB y IPA) dan lo mismo que
`bundletool dump manifest` y que `plutil`.
"""
import argparse, datetime, hashlib, json, os, plistlib, re, shutil, subprocess, sys, zipfile

# ── dónde vive todo ────────────────────────────────────────────────────────
REGISTRO = "archivo-de-builds.json"   # en la raíz del repo, versionado en git


def correr(*args):
    return subprocess.run(args, capture_output=True, text=True)


def raiz():
    """Raíz del repositorio, deducida de dónde está ESTE fichero.

    No se usa el directorio de trabajo a propósito: el script se llama tanto
    desde la raíz como desde `app/`, y un cwd equivocado archivaría en la
    carpeta de otro juego."""
    aqui = os.path.dirname(os.path.abspath(__file__))
    r = correr("git", "-C", aqui, "rev-parse", "--show-toplevel")
    if r.returncode != 0:
        sys.exit("ERROR: esto tiene que vivir dentro del repositorio del juego.")
    return r.stdout.strip()


def commit_actual(raiz_):
    r = correr("git", "-C", raiz_, "rev-parse", "HEAD")
    return r.stdout.strip() if r.returncode == 0 else None


def arbol_limpio(raiz_):
    r = correr("git", "-C", raiz_, "status", "--porcelain")
    return r.returncode == 0 and not r.stdout.strip()


# ── leer la versión DENTRO de los binarios ─────────────────────────────────
def _varint(b, i):
    """Varint de protobuf. Las cadenas de versión nunca pasan de 127 bytes,
    pero un `bytes[i]` a pelo se rompería el día que algo crezca."""
    r = s = 0
    while True:
        c = b[i]; i += 1
        r |= (c & 0x7F) << s
        if not c & 0x80:
            return r, i
        s += 7


def _atributo(manifiesto, nombre):
    """Saca un atributo del AndroidManifest.xml en protobuf de un AAB.

    Un AAB NO lleva el manifiesto en XML: lo lleva en el protobuf de aapt2, así
    que `unzip | grep` no sirve. Se busca la marca exacta del campo `name`
    (0x12, longitud, nombre) seguida del campo `value` (0x1a). La longitud
    forma parte del patrón, y por eso `versionCode` no casa dentro de
    `platformBuildVersionCode`, que lo contiene como subcadena.

    Alternativa descartada: `bundletool dump manifest`. Es la autoridad y con
    ella se cotejó esto, pero necesita java y tarda segundos por binario; el
    registro se reconstruye sobre decenas de ficheros."""
    n = nombre.encode()
    patron = b"\x12" + bytes([len(n)]) + n + b"\x1a"
    i = manifiesto.find(patron)
    if i < 0:
        return None
    j = i + len(patron)
    largo, j = _varint(manifiesto, j)
    return manifiesto[j:j + largo].decode("utf-8")


def leer_aab(ruta):
    """(versionName, versionCode, package) leídos de dentro del AAB."""
    with zipfile.ZipFile(ruta) as z:
        m = z.read("base/manifest/AndroidManifest.xml")
    nombre = _atributo(m, "versionName")
    codigo = _atributo(m, "versionCode")
    paquete = _atributo(m, "package")
    if not (nombre and codigo and paquete):
        sys.exit(f"ERROR: no pude leer la versión de dentro de {ruta}.\n"
                 f"       Cotéjalo a mano: bundletool dump manifest --bundle {ruta}")
    return nombre, int(codigo), paquete


def leer_ipa(ruta):
    """(CFBundleShortVersionString, CFBundleVersion, CFBundleIdentifier)."""
    with zipfile.ZipFile(ruta) as z:
        plists = [n for n in z.namelist()
                  if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n)]
        if len(plists) != 1:
            sys.exit(f"ERROR: {ruta} no tiene un único Payload/*.app/Info.plist.")
        # plistlib lee el plist BINARIO directamente: no hace falta plutil.
        d = plistlib.loads(z.read(plists[0]))
    return (d["CFBundleShortVersionString"], int(d["CFBundleVersion"]),
            d["CFBundleIdentifier"])


def sha256(ruta):
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for trozo in iter(lambda: f.read(1 << 20), b""):
            h.update(trozo)
    return h.hexdigest()


# ── el registro ────────────────────────────────────────────────────────────
def version_del_pubspec(raiz_):
    txt = open(os.path.join(raiz_, "app", "pubspec.yaml"), encoding="utf-8").read()
    m = re.search(r"^version:\s*([0-9.]+)\+(\d+)\s*$", txt, re.M)
    if not m:
        sys.exit("ERROR: app/pubspec.yaml no tiene una línea `version: X.Y.Z+N`.")
    nombre_juego = re.search(r"^name:\s*(\S+)\s*$", txt, re.M).group(1)
    return nombre_juego, m.group(1), int(m.group(2))


def cargar(raiz_):
    ruta = os.path.join(raiz_, REGISTRO)
    if not os.path.exists(ruta):
        juego, _, _ = version_del_pubspec(raiz_)
        return ruta, {
            "juego": juego,
            "prefijo": juego,
            "carpeta": "~/%s-releases" % os.path.basename(raiz_),
            "desde": {"build": None, "razon": ""},
            "builds": {},
        }
    with open(ruta, encoding="utf-8") as f:
        return ruta, json.load(f)


def guardar(ruta, reg):
    # Las claves son números de build en texto: se ordenan como NÚMEROS o el
    # diff pone la 10 delante de la 9 y cada entrada nueva mueve medio fichero.
    reg["builds"] = {k: reg["builds"][k]
                     for k in sorted(reg["builds"], key=int)}
    with open(ruta, "w", encoding="utf-8") as f:
        json.dump(reg, f, ensure_ascii=False, indent=2)
        f.write("\n")


def carpeta_de(reg):
    return os.path.expanduser(reg["carpeta"])


def nombre_de(reg, ext, version, build):
    return "%s-%s-%d.%s" % (reg["prefijo"], version, build, ext)


# ── órdenes ────────────────────────────────────────────────────────────────
def orden_archivar(args):
    raiz_ = raiz()
    ruta_reg, reg = cargar(raiz_)
    # Lo que dice el pubspec se guarda para poder AVISAR del desacuerdo,
    # pero no manda: quien manda es lo que lleva el binario dentro.
    juego, version_pubspec, build_pubspec = version_del_pubspec(raiz_)
    version, build = version_pubspec, build_pubspec
    app = os.path.join(raiz_, "app")

    aab = os.path.join(app, "build/app/outputs/bundle/release/app-release.aab")
    ipas = [os.path.join(app, "build/ios/ipa", n)
            for n in sorted(os.listdir(os.path.join(app, "build/ios/ipa")))
            if n.endswith(".ipa")] if os.path.isdir(os.path.join(app, "build/ios/ipa")) else []

    # ── la regla ruidosa ──────────────────────────────────────────────────
    faltan = []
    if not os.path.exists(aab):
        faltan.append("el AAB (build/app/outputs/bundle/release/app-release.aab)")
    if len(ipas) != 1:
        faltan.append("el IPA (build/ios/ipa/*.ipa)" if not ipas
                      else "un IPA único: hay %d en build/ios/ipa/" % len(ipas))
    if faltan:
        print("\n" + "=" * 72)
        print("  NO SE ARCHIVA NADA. Falta: " + ", y ".join(faltan) + ".")
        print("=" * 72)
        print("  Un AAB sin su IPA no es una build. Archivar solo la mitad deja")
        print("  la carpeta diciendo que la build está guardada cuando no lo")
        print("  está — que es exactamente cómo se perdió el IPA de la 28.")
        print("  Construye las dos plataformas desde el mismo version: y vuelve:")
        print("      cd app && export LANG=en_US.UTF-8")
        print("      flutter build appbundle --release")
        print("      flutter build ipa --release "
              "--export-options-plist=ios/ExportOptions.plist\n")
        sys.exit(1)
    ipa = ipas[0]

    # ── la versión, leída de DENTRO ───────────────────────────────────────
    a_nombre, a_codigo, a_paquete = leer_aab(aab)
    i_nombre, i_codigo, i_id = leer_ipa(ipa)

    # **Manda el BINARIO, no el pubspec.** Es la lección de la build 28, que se
    # perdió justo así: se subió la versión, se compiló la siguiente encima, y
    # el par anterior se quedó en el árbol sin archivar. En ese momento el
    # pubspec ya no coincide con lo que hay en `build/` — y si el guion se
    # planta ahí, se planta EXACTAMENTE en el rescate para el que existe. Un
    # guion que se niega en la emergencia es un guion que alguien salta con
    # `cp`, y entonces no hay registro de nada.
    #
    # Así que el desacuerdo con el pubspec se AVISA y se archiva igual, con el
    # nombre y el número que dice el binario. Lo que sí se bloquea es que las
    # dos mitades no sean pareja, o que sean de otro juego: eso no se rescata,
    # se tira.
    version, build = a_nombre, a_codigo

    problemas = []
    if (i_nombre, i_codigo) != (a_nombre, a_codigo):
        # No son pareja. Archivarlos juntos sería peor que no archivar: el día
        # que hagan falta, nadie sabría cuál de los dos miente.
        problemas.append("el AAB lleva dentro %s+%d y el IPA %s+%d: no son la "
                         "misma build" % (a_nombre, a_codigo, i_nombre, i_codigo))
    for clave, visto in (("paquete_android", a_paquete), ("paquete_ios", i_id)):
        esperado = reg.get(clave)
        if esperado and esperado != visto:
            # Cazado esto: con el script copiado a otro juego, un `build/` viejo
            # deja el binario del juego ANTERIOR y se archivaría bajo este nombre.
            problemas.append("%s: el binario dice %s y el registro %s"
                             % (clave, visto, esperado))
    if (version, build) != (version_pubspec, build_pubspec):
        print("\n" + "-" * 72)
        print("  AVISO: el pubspec dice %s+%d y estos binarios son %s+%d."
              % (version_pubspec, build_pubspec, version, build))
        print("  Se archivan igual, con su número de verdad. Es el caso del")
        print("  rescate: la versión ya subió y este par se quedó atrás.")
        print("-" * 72 + "\n")

    if problemas:
        print("\n" + "=" * 72)
        print("  NO SE ARCHIVA NADA. La versión de dentro no cuadra:")
        for p in problemas:
            print("   · " + p)
        print("=" * 72 + "\n")
        sys.exit(1)

    if str(build) in reg["builds"] and not args.rehacer:
        sys.exit("ERROR: el build %d ya está en el registro. Si de verdad lo "
                 "reemplazas: --rehacer" % build)

    destino = carpeta_de(reg)
    os.makedirs(destino, exist_ok=True)
    libres = shutil.disk_usage(destino).free
    necesita = os.path.getsize(aab) + os.path.getsize(ipa)
    if libres < necesita + 2 * (1 << 30):
        # 2 GB de colchón: en esta máquina el disco ha llegado a cero tres veces
        # y una copia a medias deja un fichero truncado con nombre bueno.
        sys.exit("ERROR: %.1f GB libres y el par ocupa %.1f GB. Libera disco "
                 "antes (flutter clean, DerivedData)."
                 % (libres / 2**30, necesita / 2**30))

    # ── la copia, atómica POR PAR ─────────────────────────────────────────
    par = []
    try:
        for origen, ext in ((aab, "aab"), (ipa, "ipa")):
            final = os.path.join(destino, nombre_de(reg, ext, version, build))
            temporal = final + ".parcial"
            shutil.copy2(origen, temporal)
            h_origen, h_copia = sha256(origen), sha256(temporal)
            if h_origen != h_copia:
                raise IOError("la copia de %s no coincide con el original" % ext)
            par.append([temporal, final, ext, h_copia, os.path.getsize(temporal)])
        for entrada_par in par:
            os.replace(entrada_par[0], entrada_par[1])   # los dos, o ninguno
    except BaseException:
        for temporal, _, _, _, _ in par:
            if os.path.exists(temporal):
                os.remove(temporal)
        raise

    entrada = {"version": version,
               "fecha": datetime.date.today().isoformat(),
               "commit": commit_actual(raiz_),
               "arbol_limpio": arbol_limpio(raiz_)}
    for _, final, ext, h, bytes_ in par:
        entrada[ext] = {"fichero": os.path.basename(final), "bytes": bytes_,
                        "sha256": h}
    if i_codigo != build:
        entrada["ipa_build_distinto"] = i_codigo

    # ── los símbolos: 23 MB que no se regeneran ───────────────────────────
    # Lo único de una build que no está ni en el AAB ni en el IPA. El AAB ya
    # lleva dentro los .so.sym y el proguard.map de Android; de iOS no queda
    # nada si se borra build/. Se guarda solo Runner.app.dSYM (7 MB) — los
    # otros 48 dSYM son de plugins y pesan 450 MB — más los .symbols de Dart.
    zsim = os.path.join(destino, "%s-%s-%d-simbolos.zip" % (reg["prefijo"], version, build))
    fuentes = []
    dsym = os.path.join(app, "build/ios/archive/Runner.xcarchive/dSYMs/Runner.app.dSYM")
    if os.path.isdir(dsym):
        fuentes.append(dsym)
    sim = os.path.join(app, "build/symbols")
    if os.path.isdir(sim):
        fuentes.append(sim)
    if fuentes:
        tmp = zsim + ".parcial"
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
            for f in fuentes:
                base = os.path.dirname(f)
                for dir_, _, ficheros in os.walk(f):
                    for n in ficheros:
                        p = os.path.join(dir_, n)
                        z.write(p, os.path.relpath(p, base))
        os.replace(tmp, zsim)
        entrada["simbolos"] = {"fichero": os.path.basename(zsim),
                               "bytes": os.path.getsize(zsim),
                               "sha256": sha256(zsim)}
    else:
        entrada["simbolos"] = None

    # ── el sidecar, en el formato que `shasum -c` sabe leer ───────────────
    # CINCO escribe .sha1 a mano; aquí sha256 porque es lo que ya imprime
    # CINCO/tools/verify-ipa.sh y tener dos hashes para lo mismo dentro de la
    # misma familia ya ha confundido una vez.
    with open(os.path.join(destino, "%s-%s-%d.sha256" % (reg["prefijo"], version, build)),
              "w", encoding="utf-8") as f:
        for _, final, _, h, _ in par:
            f.write("%s  %s\n" % (h, os.path.basename(final)))

    reg.setdefault("paquete_android", a_paquete)
    reg.setdefault("paquete_ios", i_id)
    reg["builds"][str(build)] = entrada
    if reg["desde"]["build"] is None:
        reg["desde"] = {"build": build, "razon": "primera build archivada."}
    guardar(ruta_reg, reg)

    print("Archivado el par completo del build %d (%s):" % (build, version))
    for _, final, ext, h, bytes_ in par:
        print("  %s  %s  %.1f MB  %s" % (ext, os.path.basename(final),
                                         bytes_ / 2**20, h[:16]))
    if entrada["simbolos"]:
        print("  símbolos  %s  %.1f MB" % (entrada["simbolos"]["fichero"],
                                           entrada["simbolos"]["bytes"] / 2**20))
    else:
        print("  símbolos  NO — no había xcarchive ni build/symbols que guardar")
    print("\nFalta un paso, y es el que hace que esto se note: commitea "
          "%s.\nSin ese commit la prueba del repositorio no sabe que la build "
          "existe." % REGISTRO)


def orden_reconstruir(args):
    """Siembra el registro con lo que HAY en la carpeta, leyendo cada binario.

    Se corre una vez, al adoptar el mecanismo. Solo LEE la carpeta: no copia,
    no borra, no escribe sidecars. Lo único que escribe es el registro."""
    raiz_ = raiz()
    ruta_reg, reg = cargar(raiz_)
    destino = carpeta_de(reg)
    if not os.path.isdir(destino):
        sys.exit("ERROR: no existe %s." % destino)
    encontrados = {}
    for n in sorted(os.listdir(destino)):
        m = re.fullmatch(re.escape(reg["prefijo"]) + r"-([0-9.]+)-(\d+)\.(aab|ipa)", n)
        if not m:
            continue
        version, build, ext = m.group(1), int(m.group(2)), m.group(3)
        p = os.path.join(destino, n)
        if ext == "aab":
            dentro_v, dentro_b, paquete = leer_aab(p)
            reg.setdefault("paquete_android", paquete)
        else:
            dentro_v, dentro_b, paquete = leer_ipa(p)
            reg.setdefault("paquete_ios", paquete)
        if (dentro_v, dentro_b) != (version, build):
            print("  ¡OJO! %s lleva dentro %s+%d — el nombre miente"
                  % (n, dentro_v, dentro_b))
        e = encontrados.setdefault(build, {"version": dentro_v, "fecha":
              datetime.date.fromtimestamp(os.path.getmtime(p)).isoformat()})
        e[ext] = {"fichero": n, "bytes": os.path.getsize(p), "sha256": sha256(p)}
        print("  %s  %s+%d  %s" % (ext, dentro_v, dentro_b, e[ext]["sha256"][:16]))
    for build, e in encontrados.items():
        e.setdefault("aab", None)
        e.setdefault("ipa", None)
        if str(build) not in reg["builds"] or args.rehacer:
            reg["builds"][str(build)] = e
    if reg["desde"]["build"] is None and encontrados:
        reg["desde"] = {"build": min(encontrados),
                        "razon": "el archivado empieza aquí; lo anterior es de "
                                 "antes de la costumbre y no existe en ninguna parte."}
    guardar(ruta_reg, reg)
    print("\nRegistro sembrado con %d builds en %s" % (len(encontrados), ruta_reg))
    print("Ahora corre la prueba: se pondrá ROJA por cada build a medias o "
          "saltada que aún no esté explicada. Eso es el mecanismo funcionando.")


def orden_verificar(args):
    """Lo que la prueba del repositorio NO puede permitirse: hashear 2 GB."""
    raiz_ = raiz()
    _, reg = cargar(raiz_)
    destino = carpeta_de(reg)
    fallos = 0
    for build in sorted(reg["builds"], key=int):
        e = reg["builds"][build]
        if "saltada" in e:
            continue
        for ext in ("aab", "ipa", "simbolos"):
            a = e.get(ext)
            if not a or a.get("podado"):
                continue
            p = os.path.join(destino, a["fichero"])
            if not os.path.exists(p):
                print("FALTA    %s" % a["fichero"]); fallos += 1; continue
            if os.path.getsize(p) != a["bytes"]:
                print("TAMAÑO   %s" % a["fichero"]); fallos += 1; continue
            if args.hash and sha256(p) != a["sha256"]:
                print("HASH     %s" % a["fichero"]); fallos += 1; continue
            print("ok       %s%s" % (a["fichero"], "" if args.hash else "  (solo tamaño)"))
    sys.exit(1 if fallos else 0)


def orden_saltar(args):
    raiz_ = raiz()
    ruta_reg, reg = cargar(raiz_)
    reg["builds"][str(args.build)] = {"saltada": args.razon,
                                      "fecha": datetime.date.today().isoformat()}
    guardar(ruta_reg, reg)
    print("Build %d anotada como saltada." % args.build)


def orden_incidencia(args):
    raiz_ = raiz()
    ruta_reg, reg = cargar(raiz_)
    e = reg["builds"].setdefault(str(args.build), {})
    e["incidencia"] = args.razon
    guardar(ruta_reg, reg)
    print("Build %d anotada con incidencia." % args.build)


def orden_tienda(args):
    """Marca una build como repartida por una tienda: `podar` no la tocará.

    Un binario que está en manos de gente es el que más falta hace cuando llega
    un informe de fallo de esa versión exacta; el resto son intentos."""
    raiz_ = raiz()
    ruta_reg, reg = cargar(raiz_)
    e = reg["builds"].get(str(args.build))
    if e is None:
        sys.exit("ERROR: el build %d no está en el registro." % args.build)
    e["tienda"] = args.estado
    guardar(ruta_reg, reg)
    print("Build %d marcada: %s" % (args.build, args.estado))


def orden_podar(args):
    """Libera disco SIN perder el recibo.

    El registro se queda con la versión, el tamaño y el sha256 aunque los bytes
    ya no estén: una build podada es una decisión con fecha, no un hueco. Nunca
    se poda una build marcada `tienda` ni las últimas `--dejar`."""
    raiz_ = raiz()
    ruta_reg, reg = cargar(raiz_)
    destino = carpeta_de(reg)
    builds = [b for b in sorted(reg["builds"], key=int) if "saltada" not in reg["builds"][b]]
    proteger = set(builds[-args.dejar:]) | {b for b in builds if reg["builds"][b].get("tienda")}
    liberado = 0
    for b in builds:
        if b in proteger:
            continue
        for ext in ("aab", "ipa", "simbolos"):
            a = reg["builds"][b].get(ext)
            if not a or a.get("podado"):
                continue
            p = os.path.join(destino, a["fichero"])
            if os.path.exists(p):
                if not args.de_verdad:
                    print("podaría  %s  %.0f MB" % (a["fichero"], a["bytes"] / 2**20))
                else:
                    os.remove(p); print("podado   %s" % a["fichero"])
                liberado += a["bytes"]
            if args.de_verdad:
                a["podado"] = datetime.date.today().isoformat()
    if args.de_verdad:
        guardar(ruta_reg, reg)
    print("%s %.1f GB" % ("Liberados" if args.de_verdad else
                          "Se liberarían (añade --de-verdad):", liberado / 2**30))


def orden_limpiar(args):
    """Borra app/build, pero solo si lo archivado coincide con lo que hay."""
    raiz_ = raiz()
    _, reg = cargar(raiz_)
    _, version, build = version_del_pubspec(raiz_)
    e = reg["builds"].get(str(build))
    if not e or not e.get("aab") or not e.get("ipa"):
        sys.exit("ERROR: el build %d no está archivado entero. Archiva primero: "
                 "borrar build/ ahora es perder el binario." % build)
    destino = carpeta_de(reg)
    for ext in ("aab", "ipa"):
        p = os.path.join(destino, e[ext]["fichero"])
        if not os.path.exists(p) or sha256(p) != e[ext]["sha256"]:
            sys.exit("ERROR: %s no está o no cuadra con su hash. No borro nada."
                     % e[ext]["fichero"])
    # app/build y la caché del Dart compilado van JUNTAS. Los .symbols se
    # escriben en app/build/symbols solo cuando el Dart se compila; si se borra
    # app/build y la caché de .dart_tool/flutter_build sigue viva, la build
    # siguiente reutiliza el compilado y sale «✓ Built» sin símbolos: un
    # binario ofuscado que nadie puede leer en Sentry (dos veces, 24-11-2026).
    rutas = [os.path.join(raiz_, "app", "build"),
             os.path.join(raiz_, "app", ".dart_tool", "flutter_build")]
    tam = sum(os.path.getsize(os.path.join(d, n))
              for ruta in rutas for d, _, fs in os.walk(ruta) for n in fs)
    if not args.de_verdad:
        print("Borraría %s (%.1f GB). Añade --de-verdad."
              % (" y ".join(rutas), tam / 2**30))
        return
    for ruta in rutas:
        if os.path.isdir(ruta):
            shutil.rmtree(ruta)
    print("Borrado %s: %.1f GB libres." % (" y ".join(rutas), tam / 2**30))


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    s = p.add_subparsers(dest="orden", required=True)

    a = s.add_parser("archivar"); a.set_defaults(f=orden_archivar)
    a.add_argument("--rehacer", action="store_true")
    a.add_argument("--desparejo", action="store_true",
                   help="acepta que el IPA lleve un build distinto del AAB")

    r = s.add_parser("reconstruir"); r.set_defaults(f=orden_reconstruir)
    r.add_argument("--rehacer", action="store_true")

    v = s.add_parser("verificar"); v.set_defaults(f=orden_verificar)
    v.add_argument("--hash", action="store_true", help="cotejo completo (lento)")

    k = s.add_parser("saltar"); k.set_defaults(f=orden_saltar)
    k.add_argument("build", type=int); k.add_argument("razon")

    i = s.add_parser("incidencia"); i.set_defaults(f=orden_incidencia)
    i.add_argument("build", type=int); i.add_argument("razon")

    o = s.add_parser("podar"); o.set_defaults(f=orden_podar)
    o.add_argument("--dejar", type=int, default=8)
    o.add_argument("--de-verdad", action="store_true", dest="de_verdad")

    t = s.add_parser("tienda"); t.set_defaults(f=orden_tienda)
    t.add_argument("build", type=int)
    t.add_argument("estado", help='p.ej. "App Store READY_FOR_SALE 1.0.1"')

    l = s.add_parser("limpiar"); l.set_defaults(f=orden_limpiar)
    l.add_argument("--de-verdad", action="store_true", dest="de_verdad")

    args = p.parse_args()
    args.f(args)


if __name__ == "__main__":
    main()
