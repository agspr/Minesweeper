# Nona — Sudoku del día

Daily sudoku app by SENDA LLC, part of the **Juegos Senda** family (alongside
CINCO and Minigrama). PRende and transPRte are standalone non-game apps and are
NOT in the family; neither is Leo. Flutter, iOS + Android. Bundle/package id
`com.nonaapp.nona`. Current version at time of writing: `1.0.0+27`, first
submission in review on both stores.

Written 2026-08-28. If this file feels stale, check `git log -5` and
`legal/PENDIENTE.md` before trusting anything below — both move faster than
this document will.

## What the app actually is

One new sudoku puzzle a day, the same for everyone, difficulty set by weekday
(`app/lib/game/difficulty.dart`): Mon/Wed/Fri easy, Tue/Thu medium, weekends
hard. Also an offline practice mode (unlimited puzzles, no points/streak). The
clock never scores — only mistake count does. Works fully offline and without
an account; signing in only unlocks social features (friends, leaderboard).

## Repo layout

```
app/          Flutter app (this is the actual game)
  lib/game/         puzzle generation, scoring, difficulty, daily bank
  lib/screens/       game_screen, home_screen, practice_screen, settings_tab
  lib/services/      progress_controller, progress_sync, theme_controller
  lib/nona_config.dart   everything that makes Nona not-CINCO (see below)
  lib/main.dart          wiring order; heavily commented, read it before touching
android/, app/ios/    platform projects
legal/        privacy policy, ToS, account-deletion — ES + EN, plus PENDIENTE.md
store/        icons, screenshots, store copy, IAP review assets
docs/         CONSTRUIR.md — how a build is made, archived and pruned
tools/        sembrar_demo.py, amigos_demo.py — simulator/Firestore seeding for screenshots
              archivar_build.py — archives a build; refuses to archive half of one
archivo-de-builds.json   the record of every build that exists, in git
```

## Construir y archivar

**Un AAB sin su IPA no es una build.** Both platforms are built together, from
the same `version:`, and archived to `~/Nona-releases/` with their sha256 by
`tools/archivar_build.py archivar`, which refuses — loudly, exit 1, writing
nothing — if either half is missing. Full procedure in `docs/CONSTRUIR.md`.
Nothing is uploaded to a store from here; that's the listings agent's.

The archive folder is outside the repo, so the repo's memory of it is
`archivo-de-builds.json`, and `app/test/archivo_de_builds_test.dart` guards it:
a half-archived build, an unexplained gap in build numbers, or a version that
lived in `pubspec.yaml` and never got archived all turn it red. That test is
there because archiving was done from memory and memory failed twice in a row —
the IPA of build 28 is gone for good, and 29 came within two days of it.
A build that never shipped must be written down (`saltar`), and a lost binary
must be written down (`incidencia`); an unexplained absence stays red.

## Architecture: the shared package model

Nona owns almost none of its own platform code. Accounts, friendships,
leaderboard, invitations, purchases, ads, and the social UI all come from the
`juegos_senda` git package, pinned by **tag, never branch**
(`pubspec.yaml`: `ref: package-v0.30.1`). This matters: store builds depend on
that tag meaning the same thing tomorrow that it means today. Don't move it to
a branch ref for convenience.

`app/lib/nona_config.dart` is the single file that tells the shared platform
what makes Nona *Nona* and not CINCO: game id (`'nona'` — Firestore namespace,
**never change post-launch**, changing it orphans everyone's data), Apple
bundle id, AdMob unit ids, IAP product id, legal URLs, default color palette
(Cobalto — deliberately not CINCO's Menta, so store listings don't look like
the same app), reserved handles, and which local pref-key prefixes belong to
one account (`ownedPrefKeyPrefixes` — if a key is missing here, a new user on
the same phone inherits the previous user's local progress).

**One account for the whole family.** Signing into Nona creates/uses a Juegos
Senda account. @username, display name, avatar, country, friends list are
shared across every game in the family; only game progress (streak, points,
daily records) is per-game, stored under `users/{uid}/apps/nona/`.

**Apple Sign In shows "CINCO", not "Nona".** All family games share one Apple
App ID grouped under CINCO's, so `Settings → Sign in with Apple` lists the
authorization as "CINCO" even for someone who only has Nona. This is measured
behavior (2026-08-17), not a bug — see `nona_config.dart`'s
`appleSignInEntryName` comment, and it's documented in the account-deletion
legal page so it doesn't blindside anyone revoking access.

## Key conventions

- **Spanish in commit messages, code comments, and internal docs.** English in
  UI strings only where the ARB file calls for it (`app_en.arb` / `app_es.arb`,
  both currently at parity — 64/64 keys, and the shared package at 128/128).
- **Comments explain the non-obvious "why", not the "what".** Read `main.dart`
  and `nona_config.dart` for the style — every non-trivial line has a comment
  about what breaks silently if it's removed. Match that density; don't add
  comments that just restate the code.
- **Family-wide rules apply even when Nona's code doesn't obviously need
  them.** Analytics/Crashlytics/Sentry are declared and initialized in *every*
  game from day one, even before there's a DSN or a reason — because the
  failure mode of skipping it is silent (compiles, runs, collects nothing).
  Nona shipped this wrong once (SDKs present, `Analytics.init()` never called)
  and it went unnoticed for a while.
- **A cadena that looks like a typo may be a deliberate decision.** Example:
  the app says "Anuncios removidos" (anglicism) instead of "Anuncios
  eliminados/quitados" — André chose to keep it, deliberately, in both CINCO
  and Nona, after the inconsistency was flagged. Ask before "fixing" copy;
  don't just change it.
- **Ownership split (as of this session): the listings agent owns Play
  Console, App Store Connect, AdMob, and everything under `legal/` and
  `store/`. The dev agent owns app code, builds, signing, Firebase config, the
  Xcode project.** One-off cross-overs happen only when the account owner
  (André) asks directly, scoped to that one task. Don't assume this split is
  permanent — it's how this project has been run, not a rule enforced by
  tooling.
- **The `legal/` docs describe what the code actually does, not what it's
  aspirational to do.** Before widening what §3.8 of the privacy policy
  declares (or any data-collection claim), verify the event actually fires in
  code — line and file, not the description someone gave you. This has caught
  real drift more than once.
- **Never hand-edit `Nona/legal/*.md`'s "Última actualización" date for a
  cosmetic change.** Only bump it for a substantive change to what's
  collected/declared. Wording-only edits keep the old date.

## Environment quirks (cost real time to discover)

- **Disk space is tight on this machine** — as of writing, ~9.5 GB free.
  iOS builds and simulator data eat it fast. If Bash itself stops working,
  that's the actual failure mode; clean iOS build caches first (they
  regenerate), never touch anything unversioned without checking first.
- **Seeding simulator local state (`SharedPreferences`) requires the
  simulator to be *shut down* while you write the plist.** Editing the
  container's `Library/Preferences/*.plist` with the device booted gets
  silently overwritten by `cfprefsd` on next launch. `simctl spawn ... defaults
  write` also doesn't work for this — it writes to the *system* domain
  (`data/Library/Preferences/`), not the app's sandboxed container, which is
  what the app actually reads. Shut down → edit plist directly → boot →
  launch. `tools/sembrar_demo.py` does this correctly; read it before writing
  a similar script.
- **Firebase App Check debug tokens are per *installation*, not per app.** A
  new simulator (or a reinstall) needs its own token registered in
  App Check → nona (ios/android), or every Firestore call returns
  `permission-denied` with no obvious cause once enforcement is on.
- **`Info.plist` is a verification surface, not settled config.** Two
  silent-failure bugs have shipped from missing keys there: `aps-environment`
  absent (push notifications register but never arrive, no error anywhere),
  and `CFBundleURLTypes` absent (Google Sign-In opens the browser, completes,
  and the app never receives the callback — no error, just a dead button).
  Both were caught late. If touching iOS auth or push, check this file
  explicitly; don't assume "it built and installed" means it's wired.
- **A URL scheme copied from CINCO's `Info.plist` would have been *worse*
  than missing** — CINCO's `REVERSED_CLIENT_ID` differs from Nona's, so a
  copy-paste leaves a present-but-wrong scheme that passes a casual glance and
  still doesn't work.

## Store/legal state (as of 2026-08-28)

- Both stores hold Nona's **first submission** — no prior rejection history.
  Apple: `WAITING_FOR_REVIEW`, build 27. Play: `In review`, release 27
  (1.0.0), 146 territories (EU-27 + Iceland/Liechtenstein/Norway/UK excluded,
  Switzerland kept — territory list matches on both stores).
- Six legal pages live at `sendapr.com/{privacy,terms,delete-account}/nona/`
  and `.../en/` — ES + EN, published by the sendapr/PRende agent, sourced from
  `legal/*.md` and `legal/*.en.md` in this repo.
- Play promo codes and Apple promo codes are **not obtainable pre-approval**
  — Apple's console says so outright ("Promo Codes can only be generated for
  approved versions"). Don't promise them in App Review notes before the app
  is approved once.
- Store listing copy (`store/copy/listing-copy.md`) and all 20 screenshots
  (`store/screenshots/{en,es}/{iphone69,ipad13}/`) are uploaded to both
  consoles. Screenshot generation method — solved puzzle for the board shots
  (so mistake count reads ×0, not invented), seeded progress via the
  shutdown-plist method above, `tools/amigos_demo.py` for the populated
  Social/leaderboard shot (writes and then *cleans up* fake friend accounts in
  production Firestore — never run without a paired cleanup call).

## Open items (check `legal/PENDIENTE.md` for current status — it's the living doc)

- **Retention figure mismatch between apps**: Nona's privacy policy correctly
  says 400 days (measured); CINCO's says "14 months" — CINCO's is the one that
  needs fixing, not Nona's. Tracked in CINCO's own `PENDIENTE.md`.
- **English legal-page format questions** for the sendapr agent were answered
  once already; if a future generator run needs the format again, it's
  recorded in `legal/PENDIENTE.md` under the "PARA EL AGENTE DE SENDAPR.COM"
  section.
- **App name across surfaces is intentionally inconsistent**: binaries say
  "Nona Sudoku", store listings say "Nona — Daily Sudoku" / "Nona — Sudoku del
  día", legal docs say plain "Nona". Confirmed as deliberate by André, not a
  bug — each surface names what the product does at different levels of
  formality.
- **transPRte** was asked to get an English account-deletion page (CINCO and
  PRende stay Spanish-only). That's transPRte's repo, not this one — noted
  here so it isn't lost.

## Where to look for more

- `legal/PENDIENTE.md` — the actual up-to-the-minute handoff log between the
  listings agent, the dev agent, and André. Longer and more current than this
  file will ever be; read it first for anything store/legal/launch related.
- `git log` — commit messages are written to be read later, in Spanish, and
  usually explain the "why" not just the "what".
