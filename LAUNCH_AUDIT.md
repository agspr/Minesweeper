# Minesweeper / Buscaminas — Full Audit & Launch Readiness Handoff

**Last Updated:** November 22, 2026  
**Repository:** `https://github.com/agspr/Minesweeper.git` (`main`)  
**App Identifiers:**
- **`gameId`:** `minesweeper` (`users/{uid}/apps/minesweeper`)
- **Android `applicationId`:** `com.sendallc.minesweeper`
- **iOS `bundleId`:** `com.sendallc.minesweeper`
- **App Store ID:** `6830734481` (`https://apps.apple.com/app/id6830734481`)
- **Remove Ads IAP Product ID:** `com.sendallc.minesweeper.removeads`
- **Current Version in `app/pubspec.yaml`:** `1.0.0+14` (live on Google Play Internal Testing)

---

## 1. Completed Security & Performance Audit (Already Patched & Deployed)

The following vulnerabilities, multi-device sync bugs, and rendering/algorithmic bottlenecks were discovered and patched in commits `e79a5f9` and `85c4550`, and deployed to Firebase project `cinco-fe5cc`:

### A. Backend & Client Scoring / Streak Sync Fixes
1. **Missing Backend Scoring Table (`Juegos Senda/backend/functions/scoring/minesweeper.json`)**:
   - **Root Cause**: `minesweeper` was registered in `games.js`, but `scoring/minesweeper.json` did not exist. Every time a player finished a daily game, `onDayRecorded` logged `"día en apps/minesweeper de ...: juego sin registro o sin tabla"` and aborted without updating `users/{uid}/apps/minesweeper`. This caused new devices (e.g., Pixel Tablet) to see `0` points and stale completion state.
   - **Resolution**: Created `scoring/minesweeper.json` and deployed `onDayRecorded` to `cinco-fe5cc`.
2. **Server-Side Defeat Scoring Inflation & Streak Desync**:
   - **Root Cause**: In Minesweeper, losing by detonating 3 mines awards a **15% fixed participation floor** (`8` Easy / `15` Medium / `23` Hard) and **extends the daily streak** (`DailyScore.extendsStreak => completed || lost`). Previously, `DayRecord.toJson()` did not serialize `lost: true`, `ProgressController.record()` only called `_extendStreak()` when `score.completed` was true, and backend `FORMAS.tramos` fell through to partial tier calculation (`raw.percent`), awarding up to 40% (`60` pts on Hard) for a loss at ≥75% board completion and failing to extend the server streak.
   - **Resolution**:
     - Added `if (lost) 'lost': true` to `DayRecord.toJson()` in `app/lib/services/progress_controller.dart`.
     - Updated `ProgressController.record()` and `weekDoneAsOf()` to use `score.extendsStreak` / `record.finished`.
     - Updated `Juegos Senda/backend/functions/scoring.js` (`FORMAS.tramos` and `extendsStreak`) to honor `t.defeat.participationFraction` (`0.15`) and extend the streak when `raw.lost === true`.
     - Redeployed `onDayRecorded` to Firebase `cinco-fe5cc`.
3. **In-Progress Cloud Document Namespace & Defeat Guard**:
   - **Root Cause**: `AlmacenDePartidaFirestore.kDocumento` in `app/lib/services/partida_en_la_nube.dart` was hardcoded to `'partidaEnCurso_nona'`, colliding with Nona. Additionally, `PartidaEnLaNube._alGuardar`, `partidaQueSeAdopta`, and `HomeScreen` only treated `completa == true` as finished, ignoring `perdida == true`.
   - **Resolution**: Updated `kDocumento` to `'partidaEnCurso_minesweeper'` and updated all completion guards to check `isFinished` (`completa || perdida`).
4. **Hardcoded Local Service Account Path**:
   - **Root Cause**: `tools/upload_play_internal.py` had a hardcoded local workstation path to the service account JSON.
   - **Resolution**: Replaced with `argparse` flags (`--key`, `--aab`, `--pkg`) and `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` environment variable support.

### B. Performance & Frame-Rate Optimizations
1. **Board Rendering (`O(N²)` → `O(N)` per pointer event in `app/lib/widgets/sudoku_board_view.dart`)**:
   - Hoisted `board.revealedSafeCount` and `board.isLost` out of the 140 `_Cell` widgets' `build()` methods (saving ~78,000 loop iterations per pointer-down/up frame), converted `selPeers` to a `Set<int>` for `O(1)` lookup, and wrapped the board `Stack` in a `RepaintBoundary`.
2. **Flood-Fill Cascade (`O(N²)` → `O(N)` in `app/lib/game/sudoku_board.dart`)**:
   - Replaced `queue.removeAt(0)` and `Set<int> visited` with an index-pointer queue (`head++`) and preallocated `List<bool>.filled(solution.length, false)`.
3. **Isolate Mine Generator Solver (`app/lib/game/mine_generator.dart`)**:
   - Eliminated per-iteration `a.toSet()` and intermediate `diff` list allocations inside the subset deduction loop.

---

## 2. What Is Blocking Launch Right Now (Actionable Checklist by Owner)

> **Estado al 24-11-2026** (lo de abajo es la auditoría tal como se entregó; el
> estado vivo está en `CLAUDE.md` § State):
> - **Bloqueo 1, páginas legales:** hecho. Las seis en 200; la de borrar cuenta
>   (ES) republicada el 24-11 con «Borrar Buscaminas de tu cuenta».
> - **Bloqueo 2, capturas e IPA:** hecho. 20 capturas (con `06-social`, solo
>   iPhone), subidas a las dos tiendas. Builds 15 y 16 con sus dos mitades
>   archivadas y en pruebas (Play interno y TestFlight); la 16, adjunta a la
>   versión 1.0.0 de App Store, sin enviar a revisión.
> - **Bloqueo 3, AdMob:** hecho el 23-11. Unidades propias; falta enlazar las
>   apps de AdMob a las tiendas cuando la app sea pública.
> - **Bloqueo 4:** backend desplegado y handles reservados (23-11). IAP en las
>   dos tiendas (activa en Play; lista para enviar en App Store, con su captura
>   de revisión nueva: la de `store/iap/` era de Nona). Fichas de las dos
>   tiendas rellenas por API desde `store/copy/listing-copy.md`, con las minas
>   corregidas (10 y 18, no 8 y 16). Faltan las declaraciones, que firma André:
>   privacidad de la app (Apple); seguridad de datos, clasificación, público y
>   anuncios (Play). Y enviar a revisión.

### Blocker 1: Publish Legal Pages on `sendapr.com` *(For the `sendapr` Website Agent)*
**Status:** Markdown & generator are **100% ready in `legal/`**. Live URLs currently return `HTTP 404`.

The app (`app/lib/nona_config.dart:65-74`) links to these exact URLs, which Apple App Review (Guideline 5.1.1(v)) and Google Play Console require to be live:
- **Privacy Policy (ES):** `https://sendapr.com/privacy/minesweeper/`
- **Privacy Policy (EN):** `https://sendapr.com/privacy/minesweeper/en/`
- **Terms of Service (ES):** `https://sendapr.com/terms/minesweeper/`
- **Terms of Service (EN):** `https://sendapr.com/terms/minesweeper/en/`
- **Account Deletion (ES):** `https://sendapr.com/delete-account/minesweeper/`
- **Account Deletion (EN):** `https://sendapr.com/delete-account/minesweeper/en/`

#### Instructions for the `sendapr` Agent:
1. All 6 bilingual Markdown files in `Minesweeper/legal/` (`privacy-policy.md`, `privacy-policy.en.md`, `terms-of-service.md`, `terms-of-service.en.md`, `account-deletion.md`, `account-deletion.en.md`) and `Minesweeper/legal/build-sendapr-legal.js` have already been updated for **Minesweeper / Buscaminas** with the Cobalt (`#4FA8FF`) theme and `/minesweeper/` routes.
2. Run the generator from `Minesweeper/legal/`:
   ```bash
   cd legal
   node build-sendapr-legal.js
   ```
   This writes all 6 HTML pages directly into `../sendapr-landing/public/{privacy,terms,delete-account}/minesweeper/`.
3. Update the index pages in `sendapr-landing` (`public/privacy/index.html`, `public/terms/index.html`, `public/sitemap.xml`) if desired to list Minesweeper alongside CINCO and Nona.
4. Commit and push `sendapr-landing` to trigger the Vercel production deploy, and verify the 6 URLs return `HTTP 200`.

---

### Blocker 2: Capture Store Screenshots & Build iOS `.ipa` *(For the MacBook Session)*
**Status:** Store copy is ready in `store/copy/listing-copy.md`, but `store/screenshots/` still has Nona's Sudoku PNGs and Build 14 needs its matching iOS `.ipa`.

#### Instructions for the MacBook Session:
1. **Pull latest `main`**:
   ```bash
   git pull origin main
   ```
2. **Capture Minesweeper Screenshots (`store/screenshots/es/` and `store/screenshots/en/`)**:
   - Required sizes: `iphone69` (iPhone 16 Pro Max / 6.9") and `ipad13` (iPad Pro 13").
   - Replace the old Sudoku PNGs in `store/screenshots/{es,en}/{iphone69,ipad13}/`:
     - `01-menu.png` (Main menu showing two-line `BUSCA`/`MINAS` or `MINE`/`SWEEPER` expressive tiles)
     - `02-daily-board.png` (Mid-game Minesweeper board with revealed clues, flags, and 3-strike chip)
     - `03-notes.png` / `03-chording.png` (Flagging / chording interaction or Hard board)
     - `04-stats.png` (More tab showing streak, completed boards, and practice best times table)
     - `05-practice-themes.png` (Practice mode difficulty & Senda/Classic mode selector or themes)
     - `06-social.png` (Social leaderboard & friends streaks)
3. **Build Release `.aab` and `.ipa` on macOS (per `docs/CONSTRUIR.md`)**:
   - Note: Since code changed after Build 14 was uploaded to Play Internal Testing, bump `version:` in `app/pubspec.yaml` to `1.0.0+15` before building the final dual-platform release so both Android and iOS share the exact same commit and build number:
   ```bash
   cd app
   export LANG=en_US.UTF-8

   flutter build appbundle --release \
     --obfuscate --split-debug-info=build/symbols

   flutter build ipa --release \
     --obfuscate --split-debug-info=build/symbols \
     --export-options-plist=ios/ExportOptions.plist
   ```
4. **Archive and Upload**:
   - Run `python3 tools/archivar_build.py` to record both binaries in `archivo-de-builds.json` and upload symbols to Sentry.
   - Upload the `.ipa` to App Store Connect (`xcrun altool` / Transporter) and the `.aab` to Google Play (`python3 tools/upload_play_internal.py`).

---

### Blocker 3: Production AdMob App IDs & Ad Unit IDs *(Verify Before Public Store Release)*
**Status:** Currently using Nona's AdMob IDs.

Check these three files:
1. `app/lib/nona_config.dart` (lines 56–61):
   - `bannerAndroid`: `ca-app-pub-5030233210775781/8790973745`
   - `bannerIos`: `ca-app-pub-5030233210775781/5154197249`
   - `interstitialAndroid`: `ca-app-pub-5030233210775781/2444273423`
   - `interstitialIos`: `ca-app-pub-5030233210775781/2528033906`
2. `app/android/app/src/main/AndroidManifest.xml` (line 53):
   - `com.google.android.gms.ads.APPLICATION_ID`: `ca-app-pub-5030233210775781~4088527589`
3. `app/ios/Runner/Info.plist` (line 10):
   - `GADApplicationIdentifier`: `ca-app-pub-5030233210775781~5728912318`

**Action Required:** Create the **Minesweeper** Android and iOS apps in your AdMob console (`ca-app-pub-5030233210775781`), generate its 2 App IDs and 4 Ad Unit IDs (Banner + Interstitial for Android & iOS), and replace the IDs in those 3 files before building the final store release. Also assure `app-ads.txt` on `sendapr.com/app-ads.txt` is reachable.

---

### Blocker 4: Backend Firestore & Store Console Configuration
1. **Commit & Push `Juegos Senda` Backend Repo**:
   - In `Juegos Senda/backend/functions`, `games.js`, `scoring.js`, `scoring/minesweeper.json`, and `test/scoring.test.js` have been updated and `onDayRecorded` is already deployed to `cinco-fe5cc`.
   - Seed the reserved handles (`@minesweeper`, `@buscaminas`) into Firestore so no user can claim them:
     ```bash
     cd "Juegos Senda/backend"
     GCLOUD_PROJECT=cinco-fe5cc node tools/seed-reserved.js --apply
     ```
2. **In-App Purchase (`com.sendallc.minesweeper.removeads`)**:
   - Ensure the non-consumable IAP `com.sendallc.minesweeper.removeads` is created, priced, and active in **Google Play Console** and attached to the first version submission in **App Store Connect** (using a screenshot of the More → Remove Ads sheet in `store/iap/`).
3. **Store Listing Metadata**:
   - Paste the bilingual titles, subtitles, promotional text, descriptions, and keywords from `store/copy/listing-copy.md` into App Store Connect and Google Play Console, and set the Privacy Policy URL to `https://sendapr.com/privacy/minesweeper/`.
