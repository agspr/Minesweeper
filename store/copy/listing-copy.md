# Copia de tienda de Buscaminas / Minesweeper

Redactada el 22-11-2026 para las fichas de Google Play y App Store Connect.
Cada dato refleja fielmente el código y las reglas de `app/lib/game/`:
- Mapa semanal (`difficulty.dart`): Fácil (8×8, 8 minas) lunes, miércoles y viernes; Medio (9×12, 16 minas) martes y jueves; Difícil (10×14, 28 minas) sábado y domingo.
- Solucionador lógico sin adivinanzas (`mine_generator.dart`): casilla de salida segura (`0`) y resolución garantizada por pura deducción.
- Dos modos en práctica (`practice_controller.dart`): Modo Senda (3 vidas) y Modo Clásico (1 vida).

---

## ESPAÑOL (`es-419` / `es-ES`)

### Play — título (≤30 caracteres)
Buscaminas — Reto diario

### Play — descripción corta (≤80 caracteres)
Un buscaminas lógico cada día, sin adivinar. ¿Podrás mantener tu racha?

### App Store — nombre (≤30 caracteres)
Buscaminas — Reto diario

### App Store — subtítulo (≤30 caracteres)
Un tablero al día, con racha

### App Store — texto promocional (≤170 caracteres)
Cada día, un buscaminas nuevo: el mismo para todo el mundo y 100 % resoluble por lógica, sin adivinar a suerte. Mantén tu racha y compite con tus amigos.

### Descripción completa (Play y App Store, ≤4000 caracteres)
Buscaminas es el reto diario de lógica de Juegos Senda. Cada día hay un tablero nuevo, exactamente el mismo para todo el mundo: si tú lo despejas y tus amigos también, jugaron el mismo campo de minas.

CERO ADIVINANZAS: PURA LÓGICA
Olvídate de perder al final por un 50/50 a cara o cruz. Todos los tableros están verificados para resolverse desde la casilla de salida segura usando únicamente deducción lógica.

EL RITMO DE LA SEMANA
La dificultad cambia con el día de la semana:
• Lunes, miércoles y viernes: Fácil (8×8 · 8 minas) para soltar la mano.
• Martes y jueves: Medio (9×12 · 16 minas).
• Sábado y domingo: Difícil (10×14 · 28 minas), donde entran deducciones avanzadas.

EL RETO DIARIO
• Un tablero único al día con salida segura marcada.
• Hasta 3 vidas (minas) en el modo diario: un tropiezo resta puntos, pero te deja terminar y conservar tu racha.
• El reloj corre para tus récords personales, pero nunca resta puntos: juega a tu propio ritmo.
• Acorde rápido (chording) al tocar un número cuyas minas ya abanderaste, y bandera instantánea con pulsación larga.

MODO PRÁCTICA ILIMITADO
• Puzles infinitos generados al instante en Fácil, Medio y Difícil.
• Elige entre el modo Senda (3 vidas, ideal para aprender) o el modo Clásico (1 sola vida, al estilo tradicional).
• Funciona 100 % sin conexión, incluso en modo avión.

JUEGA CON TUS AMIGOS
• Añade amigos por su @usuario y compite en la clasificación semanal, mensual e histórica.
• Mantén rachas compartidas con tus amigos y envíales un recordatorio si aún no han jugado hoy.
• Comparte tu resultado diario sin destripar el tablero.

UNA CUENTA PARA TODA LA FAMILIA
Buscaminas forma parte de Juegos Senda (junto a CINCO y Nona). Tu @usuario, tu avatar y tu lista de amigos son los mismos en todos los juegos de la familia, y tu progreso te sigue si cambias de teléfono o tablet.

¿Prefieres jugar sin cuenta? Entra directo: el reto diario y el modo práctica funcionan completos sin registrarse.

SIN TRUCOS
• Sin barras de energía, sin esperas y sin pagar para ganar.
• Una única compra opcional: quitar los anuncios para siempre.
• Cuatro paletas de color expresivas (Cobalto, Menta, Lavanda y Coral), en español y en inglés.

Hecho por SENDA LLC en Puerto Rico.

### App Store — palabras clave (≤100 caracteres, sin espacios tras las comas)
minas,puzle,lógica,diario,racha,clásico,tablero,amigos,estrategia,mental,cerebro,sin conexión,senda

---

## ENGLISH (`en-US`)

### Play — title (≤30 chars)
Minesweeper — Daily Logic

### Play — short description (≤80 chars)
One no-guess minesweeper board every day. Can you keep your streak alive?

### App Store — name (≤30 chars)
Minesweeper — Daily Logic

### App Store — subtitle (≤30 chars)
One board a day, no guessing

### App Store — promotional text (≤170 chars)
Every day brings one new minesweeper board — the same for everyone, and 100% solvable by pure logic without coin-flip guessing. Keep your streak and compete with friends.

### Full description (Play and App Store, ≤4000 chars)
Minesweeper is the daily logic challenge from Juegos Senda. Every day brings one new board, identical for everyone: when you and your friends clear today's puzzle, you tackled the exact same minefield.

ZERO GUESSING — 100% PURE LOGIC
Forget losing a great run to a 50/50 coin flip on the last two tiles. Every single board starts from a marked safe opening tile and is verified to be solvable through deduction alone.

A WEEKLY RHYTHM
Difficulty follows the day of the week:
• Monday, Wednesday & Friday: Easy (8×8 · 8 mines) to warm up.
• Tuesday & Thursday: Medium (9×12 · 16 mines).
• Saturday & Sunday: Hard (10×14 · 28 mines), requiring subset logic and deeper deduction.

THE DAILY CHALLENGE
• One shared puzzle every day with a guaranteed safe start.
• 3-strike shield in the daily challenge: hitting a mine costs points, but lets you finish the board and keep your streak alive.
• The timer tracks your personal bests but never affects your score — think at your own pace.
• Fast chording on satisfied number clues and instant long-press flagging.

UNLIMITED PRACTICE MODE
• Endless no-guess puzzles across Easy, Medium, and Hard.
• Choose between Senda Mode (3 lives) or Classic Mode (1 life, sudden death).
• Works 100% offline — play on a plane or anywhere without signal.

PLAY WITH FRIENDS
• Add friends by their @username and compare scores on the weekly, monthly, and all-time leaderboards.
• Build shared streaks with friends and send a nudge when they haven't played today's board yet.
• Share your spoiler-free result card in one tap.

ONE ACCOUNT FOR THE WHOLE FAMILY
Minesweeper is part of Juegos Senda (alongside CINCO and Nona). One account — your @username, avatar, and friends list — works across every game in the family, and your progress syncs seamlessly across your phone and tablet.

Prefer not to sign up? Play right away: both the daily challenge and full practice mode work without an account.

NO TRICKS
• No energy bars, no wait timers, and no pay-to-win mechanics.
• One optional one-time purchase: remove ads forever.
• Four expressive color themes (Cobalt, Mint, Lavender, and Coral), in English and Spanish.

Made by SENDA LLC in Puerto Rico.

### App Store — keywords (≤100 chars, no spaces after commas)
mines,puzzle,logic,daily,streak,classic,grid,friends,strategy,brain,offline,no guess,buscaminas,senda
