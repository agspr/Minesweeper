# Reglas de R8 para el build de release.
#
# ## Por qué existe este fichero: la app se cerraba al arrancar en Android
#
# La v1 y la v2 morían antes del primer fotograma, en un Pixel, con:
#
#   java.lang.RuntimeException: Unable to get provider
#       androidx.startup.InitializationProvider
#   Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
#       at androidx.work.WorkManagerInitializer
#
# La causa, confirmada leyendo la salida de R8 y no deduciéndola:
# `mapping.txt` no tenía ninguna entrada para `WorkDatabase_Impl` —o sea que no
# fue renombrada— y `usage.txt` la lista como **eliminada**, junto con
# `PreferenceDao_Impl` y `RawWorkInfoDao_Impl`.
#
# Room genera esas clases `_Impl` en tiempo de compilación y las busca en
# ejecución **por reflexión, por su nombre**. R8 no ve ninguna referencia
# estática a ellas, así que las borra por muertas. Sin la implementación,
# `Room.databaseBuilder(...).build()` falla, `WorkManagerInitializer` revienta
# y como corre dentro de `androidx.startup.InitializationProvider` —antes de
# `Application.onCreate`— se lleva el proceso por delante.
#
# Detalles que hacen esto especialmente difícil de cazar, y que conviene
# recordar antes de "simplificar" estas reglas:
#
# - **Nona no usa WorkManager.** Entra sola, transitivamente, por la cadena de
#   anuncios (`play-services-ads` → `androidx.work:work-runtime`). Nadie la
#   pidió y nadie la llama desde el código de la app.
# - **Ocurre antes de que arranque Dart**, así que ninguna prueba de Flutter
#   puede verlo: las 189 estaban en verde mientras la app no abría.
# - **Ocurre antes de que se inicialice Sentry**, así que el panel está vacío.
#   Que no haya nada ahí no significa que no haya pasado nada.
# - **Solo pasa en release**: en debug no hay R8, así que en el simulador y en
#   `flutter run` funciona perfectamente.
#
# La alternativa habría sido quitar el inicializador de WorkManager del
# manifiesto con `tools:node="remove"`, ya que la app no lo usa. No se hace:
# quien SÍ lo usa es el SDK de anuncios, y desactivarlo cambiaría su
# comportamiento de formas que no controlamos. Es más honesto conservar la
# clase que quitarle a una biblioteca algo que ella cree tener.

# Room: conservar las implementaciones generadas y su constructor, que es lo
# que instancia la reflexión. `extends` cubre toda la jerarquía, así que esto
# alcanza a WorkDatabase_Impl a través de WorkDatabase.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.RoomOpenHelper$Delegate { *; }

# Los DAO generados no extienden RoomDatabase: implementan una interfaz, así
# que la regla anterior no los alcanza. Se conservan por nombre.
-keep class androidx.work.impl.**_Impl { <init>(...); *; }

# WorkManager instancia workers y su inicializador también por reflexión.
-keep class * extends androidx.work.ListenableWorker { <init>(...); }
-keep class androidx.work.impl.WorkDatabase { *; }
-dontwarn androidx.work.**
