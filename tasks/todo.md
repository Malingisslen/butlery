# Fas 2 (BUT-2430): repot byter till `butlery-prod`

Genomför fas 2 i den godkända planen `tasks/new-prod-project-plan.md` (B, "Fas 2 — Repot";
Malin godkände planen 2026-10-20 och sa "Ja, starta Fas 2" 2026-10-21). Inga nya beslut här;
det här är bara körlistan. Mätta fakta från fas 1: BUT-2429-kommentarerna.

No architecture-changing unknowns — assumptions: the plan's literal list plus a repo-wide grep is
the universe; butlery.app ownership is unverified, so nothing new depends on it and the CORS
lists are left as they are.

## Commits, en per grind-familj
- [x] Arbetsflöden (inga grindar): WIF i alla sju prod-flöden (`measure-production.yml` är
      det sjunde, saknas i planens lista), taggtriggern bort, `_EU`-hemligheten i
      build-validation + emulator-lane, `patch_live_files.py` tar token från gcloud.
- [x] functions (cloud-functions-specialist): `require-project.ts` (+ test),
      `deploy-project-guard.test.ts` (WIF-kontroller), övriga literaler under functions/src.
- [x] Regler (firestore-rules-tester + cloud-functions-specialist): chattbildens
      bucket-regex i `firestore.rules` släpper bara `butlery-app-(1|staging)` — saknas i
      planens lista; utan bytet nekas varje offline-chattbild på butlery-prod.
- [x] Dart (code-reviewer, testing-specialist, integration-reviewer; max 3 filer per runda):
      `firebase_options.dart`, `firebase_env.dart`, `main.dart`, `admin_main.dart`
      (reCAPTCHA Enterprise), tester, `scripts/crf/*.dart`.
- [x] Native + konfig (inga grindar): `.firebaserc`, `firebase.json`, `build.gradle.kts`,
      `Info.plist`, entitlements, `security.txt`, skript, `check_model_versions.py`.
- [x] Docs och runbooks.

## Bevis
- [x] Repo-vid grep på `butlery-app-1` (utom `.dart_tool`, `__pycache__`,
      `functions/fnlist.tmp.json`, `.claude/state`): bara avsiktliga träffar kvar.
- [x] `flutter analyze --fatal-infos`, functions unit-svit, `flutter build apk --flavor prod`
      med oförändrad signatur (F12).
      Lokalt rött i `test:reset-analytics-prune` och `test:erasure-export-coverage`,
      inga fas 2-filer; CI cloud-functions-unit grönt på main.
- [x] F4: `firebase use production` → `butlery-prod`; vakttestet grönt.
- [x] F15a: avkodad `GOOGLE_SERVICES_JSON_BASE64_EU` innehåller `butlery-prod`.
- [ ] Push, sedan Malins byte av miljövariablerna i `production` steg för steg.
- [ ] Bevis på BUT-2430, kort svensk rapport.
