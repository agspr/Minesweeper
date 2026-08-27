# Capturas de tienda de Nona — 27-8-2026

**16 capturas, sin subir.** Esperan el visto bueno de André.

| | iPhone 6.9" (1320×2868) | iPad 13" (2064×2752) |
|---|---|---|
| **en** | 5 | 3 |
| **es** | 5 | 3 |

Tamaños verificados por cabecera PNG: coinciden **exactos** con lo que exige
Apple para 6.9" y 13".

## Qué enseña cada una

| Fichero | Qué enseña |
|---|---|
| `01-menu` | Menú con la **racha de 12 días** viva |
| `02-daily-board` | Tablero de la diaria, **caja superior izquierda completa**, ×0 fallos |
| `03-notes` | Modo notas con lápiz activo y candidatas 3/4/9 *(solo iPhone)* |
| `04-stats` | Las seis tarjetas de estadísticas *(solo iPhone)* |
| `05-practice-themes` | Tabla de práctica por nivel + los cuatro colores *(solo iPhone)* |
| `03-stats` (iPad) | Estadísticas + tabla + colores **en una sola pantalla** |

En iPad las tres secciones caben juntas, así que **tres capturas cubren lo que
en iPhone necesita cinco**. No es un recorte: es que la pantalla da para más.

## Cómo se hicieron, para poder repetirlas

- **Progreso sembrado** con `tools/sembrar_demo.py` (del agente de desarrollo),
  con una corrección mía en el mapa de días — ver `legal/PENDIENTE.md`.
- **Se siembra con el simulador APAGADO.** Editar el plist con el aparato
  encendido no sirve: `cfprefsd` cachea las preferencias y machaca el fichero al
  arrancar. Tampoco vale `simctl spawn ... defaults write`, que escribe en el
  dominio del sistema (`data/Library/Preferences/`) y **no** en el contenedor
  de la app, que es el que la app lee.
- **Los dígitos del tablero no están inventados**: resolví el puzle del día y
  metí valores correctos, por eso el contador marca **×0 fallos**. Meter dígitos
  al azar habría salido con ×1, ×2… en la captura.
- **Sin banner de anuncios**: `flutter.iap.adsRemoved` puesto en el simulador.
  Es un estado real de la app (quien compró "Quitar anuncios"), no un truco de
  imagen.
- Simuladores `Nona-iPhone69` y `Nona-iPad13`, con los mismos tipos de aparato
  que ya usaban CINCO y transPRte.

## Lo que NO hay, y por qué

**No hay captura de Social/clasificación.** Con sesión invitada esa pestaña no
enseña una clasificación vacía, enseña la pantalla de invitación ("Juega con tus
amigos" + Iniciar sesión). Para que salga la clasificación hace falta cuenta, y
crear cuentas de prueba **quema @usuarios del espacio compartido e inmutable de
la familia**. Está en manos de André: poblada = 4 @usuarios, con tu fila sola =
1, fuera = 0.
