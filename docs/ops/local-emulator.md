# Local test mode (Firebase emulators)

Runs the web app against the local emulator suite, so user journeys can be walked end to
end with throwaway accounts. Plan it serves:
`/mnt/project-files/anvandarresor/kontroll-av-alla-resor-2026-10-05.md` (project files).

## Start

```bash
bash scripts/emulator/start.sh        # emulators + seed; leave it running
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
```

Needs Node 22, Java 21 and `firebase-tools` (CI pins 15.13.0). Emulator UI:
http://localhost:4000.

`flutter build web` without `--profile` is a release build, and local mode refuses to
start in release.

## What keeps it away from production

- The app runs as project `demo-butlery`. A `demo-` project has no production
  counterpart, so a call that misses the emulator wiring fails.
- `EmulatorBootstrap.configure()` throws if Firebase was initialised with any other
  project, and both entry points throw in a release or native build.
- `functions/scripts/seed-emulator.js` refuses to run without emulator hosts and a
  `demo-` project id.

## What it seeds

The ingredient snapshot (`scripts/crf/data/firebase_ingredients.json`) into `ingredients`,
and `scripts/output/tagConfigs/*.json` into `tag_configs`. Regenerate the tag configs with
`dart run scripts/migrate_tag_configs.dart` when tag code changes. Accounts are created
through the app's own registration.

## Known gaps

- Web only.
- App Check: the app sends an unsigned token in local mode. The functions emulator skips
  App Check signature checks but rejects a call that carries no token.
- `scripts/emulator/admin-namespace-shim.js` works around a firebase-tools bug that
  strips `admin.firestore.FieldValue` inside the functions emulator. The header comment
  has the details.
- Gemini/Vertex calls (URL LLM tier, photo import) and scheduled functions do not run
  locally. Remote Config falls back to in-app defaults.
- Uploaded image URLs point at `localhost:9199`, which the recipe form's image check
  (`ImageUploadValidator.isFirebaseUrl`) does not recognise.
