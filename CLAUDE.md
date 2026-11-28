# Minesweeper / Buscaminas — el buscaminas del día

Daily minesweeper by SENDA LLC, part of the **Juegos Senda** family (alongside
CINCO, Nona and Minigrama). Flutter, iOS + Android. Bundle id and package
`com.sendallc.minesweeper`; App Store ID `6830734481`. The name is
**Buscaminas** in Spanish (home screen, store listings) and **Minesweeper** in
English. Current version: `1.0.0+16` — **live on Google Play** (production,
2026-11-26). App Store version 1.0.0 with it was submitted 2026-11-25 and
**rejected**; see State below.

Written 2026-11-23, updated 2026-11-24. If this feels stale, check `git log -5`,
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
  **"No guessing" holds only from the marked start**, so until it is opened
  it is the only cell that responds (daily and Senda practice; a tap
  elsewhere shows «Empieza por la casilla marcada»; `SudokuBoard.faltaLaSalida`).
  Before 2026-11-28 (builds ≤ 16) you could start anywhere, and on 263 of
  2026's 365 days some other blank start forces a guess. Clásico practice
  marks no start at all.
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
- **The IPA goes up with `tools/subir_testflight.sh <build>`** (the archived
  IPA, checked against its sha256 and inside before uploading). André uploaded
  it himself until build 15; on 2026-11-24 he had this session do it. The AAB
  goes up with `tools/upload_play_internal.py`.
- Disk on this Mac is tight; Gradle's cache, swap (a Gradle build grows it by
  ~3 GB) and simulators can empty it. One heavy thing at a time.
- **Deleting `app/build` alone breaks the next build's symbols.** The compiled
  Dart is cached in `app/.dart_tool/flutter_build/`; with it alive, the next
  build reuses it, writes no `.symbols`, and still says `✓ Built` (twice on
  2026-11-24). Delete both, and check `app/build/symbols/` before archiving.

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

- **Commit and push after every change — a standing rule for every Senda app**
  (André, 2026-11-24; CINCO already had it). Straight to `main`: no branches,
  no worktrees, and without asking. Each finished change gets its own commit
  (Spanish message, with the why) and is pushed at once; a turn never ends
  with work uncommitted or unpushed. Secrets never go in
  (`app/android/key.properties`, service-account JSON, `.p8` keys).
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

## State as of 2026-11-24

- Legal pages: all six live at `sendapr.com/{privacy,terms,delete-account}/minesweeper/{,en/}`
  (the Spanish delete-account page republished 2026-11-24 with «Borrar Buscaminas»).
- AdMob: apps "Minesweeper — Daily Logic" (Android `~7005873887`, iOS
  `~7754567513`) with their own units; **not linked to the stores yet** (the
  app isn't public), so ad serving is limited until they are.
- Build 16 (2026-11-24): AAB on Play internal testing, IPA on App Store
  Connect (VALID; export compliance answered by its Info.plist) and **attached
  to version 1.0.0**, submitted with Remove Ads on 2026-11-25 and **rejected
  under Guideline 2.1 – Information Needed** (2026-11-26): not a defect.
  Apple wants a screen recording on a physical iPhone (launch, sign-in,
  account deletion, report/block, the purchase) plus written answers. The
  answers are in the review notes (`store/review/notas-app-review-en.txt`,
  saved 2026-11-26); the recording is André's, guided by
  `store/review/grabacion-app-review.md`. Then: attach the video, clean up
  the demo friends, resubmit with Remove Ads. **Demo friends are seeded in
  production right now** (2026-11-26, @ana_rivera, @luis_mendez,
  @marta_ortiz, friends of the test account @aistudio747): run
  `tools/amigos_demo.py --borrar <uid of @aistudio747>` once the video
  exists. Build 15 is also on
  both (export compliance answered by hand, exempt).
- App Store Connect, filled through the API: version **1.0.0** (was "1.0", which
  a 1.0.0 build can't attach to), en-US + es-MX name/subtitle/privacy URL,
  description, keywords, promo text, support/marketing URLs, Games › Puzzle,
  age rating (Nona's answers, 4+, plus "no" to the two questions Apple added
  for new apps — location sharing and dating; Nona has them empty, which only
  passes for existing apps until 2027-01-15), free, Nona's territories minus
  China mainland — **144** (no EEA/UK). China came out on 2026-11-25 for both
  the app and the IAP: with it available, Apple refuses "Add for Review" until
  a Security Assessment and an AIGC filing are provided, and a game there also
  needs a Chinese game licence. Nona still lists it (existing apps have until
  2027-01-31),
  review contact and notes, 20 screenshots. IAP `…removeads` **ready to
  submit** ($1.99, es-MX/en-US texts, Nona's territories, review screenshot of
  the purchase sheet — the old one in `store/iap/` was Nona's).
- Google Play, through the API: en-US + es-419 listing, icon, feature graphic
  (Spanish; English one made from it, `store/icon/store-assets/play-feature-en-1024x500.png`),
  6 phone + 4 tablet screenshots per language, contact details. One-time
  product `…removeads` **active**, Nona's regional prices. Production
  countries = **CINCO's** (André, 2026-11-24): 146 plus "Rest of world", no
  EEA/UK — set in the Console (the API only reads them) and checked equal to
  CINCO's through the API. **Production release `16 (1.0.0)` created and
  confirmed** (es-419/en-US notes, no warnings, 14.6 MB): Publishing overview
  shows "Submit 14 changes for review", not sent. **Managed publishing is
  off**: once Google approves, it goes live by itself — and the App Store
  version is set to release automatically after approval too. Both on
  purpose (André, 2026-11-24: "keep automatic"). Create releases in the
  Console, not the API: for this app `edits.commit` refuses
  `changesNotSentForReview` and would send every pending change for review.
- **Declarations, made 2026-11-24 at André's request, copying Nona's** (same
  package and SDKs; checked against `legal/privacy-policy.en.md`):
  - App Store **App Privacy, published**: name, email, user ID and gameplay
    content linked to the account, for app functionality; device ID and
    advertising data used for tracking (AdMob); product interaction for
    analytics; crash and performance data — the last three not linked.
  - Play App content: privacy policy, ads (yes), sign-in details (no login
    needed; instructions for the reviewer), advertising ID (advertising), not
    a government app, no financial or health features, target audience 13+,
    content rating (IARC: Game; digital purchases; users interact, blockable,
    reportable, friends only — same ratings as Nona), Data safety (same
    answers as Nona, with the `delete-account/minesweeper/` URLs), and store
    settings Game › Puzzle.
  - Play **app-level trader status** (EU DSA), at André's request: **trader
    status applies** — SENDA LLC is a company and the app earns from ads and
    an in-app purchase; answering "no" would tell EEA/UK users consumer law
    doesn't apply. Terms URL `sendapr.com/terms/minesweeper/`. (The Apple
    account declares non-trader, which is why EEA/UK are off on the App
    Store.) Play setup: 12 of 12.
  - Sent for review in both stores on 2026-11-25 (André asked this session
    to do it). Play approved: live 2026-11-26. App Store: rejected, pending.
  App Store "App Compliance" lists China-mainland items as missing info; Nona
  has the same and leaves them.
- Social screenshot done (iPhone, es + en) with a test account and
  `tools/amigos_demo.py`, cleaned up and verified; how, in `store/screenshots/LEEME.md`.

## Where to look

- `LAUNCH_AUDIT.md` — the launch checklist and the audit that produced it.
- `legal/PENDIENTE.md` — handoff log with the sendapr agent.
- `docs/CONSTRUIR.md` — builds, signing, uploads, traps.
- `git log` — commit messages explain the why, in Spanish.
