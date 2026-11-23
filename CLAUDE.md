# Minesweeper / Buscaminas — el buscaminas del día

Daily minesweeper by SENDA LLC, part of the **Juegos Senda** family (alongside
CINCO, Nona and Minigrama). Flutter, iOS + Android. Bundle id and package
`com.sendallc.minesweeper`; App Store ID `6830734481`. The name is
**Buscaminas** in Spanish (home screen, store listings) and **Minesweeper** in
English. Current version: `1.0.0+15` — on Google Play internal testing; the
App Store has no submission yet.

Written 2026-11-23. If this feels stale, check `git log -5`,
`LAUNCH_AUDIT.md` and `legal/PENDIENTE.md` before trusting anything below.

## Born from Nona — read this before renaming anything

The codebase is a conversion of Nona (the family's daily sudoku), and many
**internal** names still say Nona or sudoku: the Dart package is `nona`, the
config file is `lib/nona_config.dart` (`nonaConfig`, `nonaGameId`), colors are
`NonaColors`, the board class is `SudokuBoard` in `sudoku_board.dart`, and the
local pref keys are `game.nona.today`, `game.nona.practice*`. **Leave them.**
The pref keys are players' saved progress — renaming them silently wipes every
in-progress game and practice stat — and the rest is churn with no user-visible
gain. What users see (strings, store, legal, ads, signing, Sentry) has been
moved to Minesweeper; when you find a user-visible Nona/sudoku leftover, that
*is* a bug.

## What the game is

- **One daily board**, the same for everyone, from the bank in
  `app/assets/bank/<year>.json` (solution + safe start cell). Difficulty by
  weekday (`lib/game/difficulty.dart`): Mon/Wed/Fri easy (8×8, 10 mines),
  Tue/Thu medium (9×12, 18), weekends hard (10×14, 28). Every board is
  solvable **without guessing** from its safe start; hard boards are rejected
  by the generator unless they need at least one two-clue (subset) deduction.
- **Three strikes**: the third detonated mine loses the board.
- **Scoring** (`lib/game/scoring.dart`, mirrored server-side in
  `Juegos Senda/backend/functions/scoring/minesweeper.json` + `scoring.js`):
  cleared = base − 15 % per mine (capped at 3); **lost = fixed 15 % of base and
  the streak is kept** (a loss is a finished game, not an abandoned one);
  unfinished = partial tiers by % revealed. Bases 50/100/150. The clock never
  scores.
- **Practice**: unlimited boards, no points or streak; modes Senda (3 lives)
  and Clásico (1 life); hints exist only here and never open a mine.
- Works fully offline and without an account; an account (shared across the
  family) unlocks friends, leaderboard and invitations.

## Repo layout

```
app/          Flutter app
  lib/game/        board, generator, bank, scoring, difficulty, controllers
  lib/screens/     game, home, practice, settings (Más)
  lib/services/    progress, cloud sync of the in-progress daily, theme, share
  lib/nona_config.dart   everything that makes this game not-CINCO (see below)
android/, app/ios/ platform projects
legal/        privacy, terms, account deletion — ES + EN — and PENDIENTE.md
store/        icons, screenshots (+ LEEME.md), store copy, IAP review assets
docs/         CONSTRUIR.md — how a build is made, archived and uploaded
tools/        archivar_build.py, upload_play_internal.py, sembrar_demo.py, amigos_demo.py
archivo-de-builds.json   the record of every build, in git
```

## Building — read `docs/CONSTRUIR.md`

**An AAB without its IPA is not a build.** Both halves from the same
`version:`, archived to `~/Minesweeper-releases/` by
`tools/archivar_build.py archivar` (builds 1–14 were archived on the Windows
machine and are marked as such in the registry). Key facts that each cost time
to find:

- Android signs with **PRende's upload keystore** (`app/android/key.properties`,
  not in git). Play uploads use **PRende's service account**
  (`~/.playconsole/prende-publisher.json`), which has Minesweeper permissions
  since 2026-11-23.
- iOS signs with the **"Minesweeper App Store"** provisioning profile (expires
  2027-06-05 with the distribution certificate).
- **The IPA is André's to upload.** This session builds, verifies, archives and
  uploads the AAB to Play internal testing.
- Disk on this Mac is tight; Gradle's cache and booted simulators can empty it.
  One heavy thing at a time.

## Architecture: the shared package

Accounts, friendships, leaderboard, invitations, purchases, ads and the
platform screens (Más, sign-in, account deletion) come from the `juegos_senda`
package, pinned **by tag, never by branch** (`ref: package-v0.89.2`). Moving
the pin pulls in everything since; the 0.90.x line changes ads, so Minesweeper
gets patch tags on its own line when it needs a fix (as with 0.89.2).

`lib/nona_config.dart` tells the package what this game is: `gameId:
'minesweeper'` (Firestore namespace `users/{uid}/apps/minesweeper` — **never
change it**, it orphans everyone's data), bundle id, AdMob units (Minesweeper's
own since 2026-11-23), IAP id `com.sendallc.minesweeper.removeads`, legal URLs
(`sendapr.com/{privacy,terms,delete-account}/minesweeper/`), palette (Cobalto),
reserved handles, and `ownedPrefKeyPrefixes`. The package prints
`config.appName` verbatim, so the screens that show it get
`nonaConfigNamed(l.appName)` — "Buscaminas" in Spanish.

**One account for the whole family**, and Sign in with Apple shows up as
"CINCO" in iOS settings for every family game (measured, not a bug; the
account-deletion page says so).

Backend lives in the `Juegos Senda` repo (`agspr/juegos-senda`), Firebase
project `cinco-fe5cc`. **Deploy Functions only from that repo's `main`.**
`onDayRecorded` was deployed twice from a stale copy on another machine
(2026-11-11 and -22) and lost six weeks of `main` each time; it was redeployed
from `main` and verified byte-for-byte on 2026-11-23.

Crash reporting: Firebase Crashlytics + Sentry project **`minesweeper`** (org
`senda-6q`) from build 16 on; builds ≤ 15 reported to the `nona` project.

## Key conventions

- **Spanish in commit messages, code comments and internal docs.** UI strings
  in both languages via the ARB files (`app_es.arb` is the template).
- **Comments explain the non-obvious "why"**, with what breaks silently if the
  line goes. Match that density.
- **Ask before "fixing" copy.** Some odd strings are deliberate (the family
  keeps "Anuncios removidos" on purpose).
- **`legal/` describes what the code actually does.** Before adding or widening
  a data-collection claim, find the event in code (file and line). Bump
  "Última actualización" / "Last updated" only for substantive changes.
- **The website is the sendapr agent's.** Edit the Markdown in `legal/`, leave a
  note in `legal/PENDIENTE.md`, and let that agent generate and publish.

## Environment quirks

- **Simulator prefs must be seeded with the simulator shut down**
  (`tools/sembrar_demo.py <udid> es|en`): with it booted, `cfprefsd` overwrites
  the plist, and `simctl spawn … defaults write` writes the wrong domain.
- **iPad screenshots need full-screen apps** (Settings → Multitasking): windowed
  mode puts the app name in the status bar and a resize handle in the corner.
- **Firebase App Check debug tokens are per installation**: a new simulator
  needs its own token registered, or Firestore returns `permission-denied`.
- **`Info.plist` is a verification surface.** Missing `aps-environment` or a
  wrong `CFBundleURLTypes` scheme fail silently (no push; dead Google sign-in).
- **`tools/amigos_demo.py` writes fake accounts to production** and must always
  be paired with its `--borrar` cleanup.

## State as of 2026-11-23

- Legal pages: all six live at `sendapr.com/{privacy,terms,delete-account}/minesweeper/{,en/}`.
- AdMob: apps "Minesweeper — Daily Logic" (Android `~7005873887`, iOS
  `~7754567513`) with their own units; **not linked to the stores yet** (the
  app isn't public), so ad serving is limited until they are.
- Store screenshots: 18 in `store/screenshots/` (see its `LEEME.md`); the
  Social one is still missing.
- Pending, André: upload the build 15 IPA, the Remove Ads IAP in both consoles,
  the store listings (`store/copy/listing-copy.md`), the Social screenshot.

## Where to look

- `LAUNCH_AUDIT.md` — the launch checklist and the audit that produced it.
- `legal/PENDIENTE.md` — handoff log with the sendapr agent.
- `docs/CONSTRUIR.md` — builds, signing, uploads, traps.
- `git log` — commit messages explain the why, in Spanish.
