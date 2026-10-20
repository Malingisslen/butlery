# Staging project (`butlery-app-staging`)

A second Firebase project where rules, indexes and functions are tried before they reach
production (`butlery-app-1`). The closed test group runs against **production**; staging
is our own lab. Plan and decisions: BUT-451, `tasks/firebase-staging-plan.md` (draft PR
#964).

## The order of work

1. Change lands on `main`.
2. Rules, indexes and Storage rules reach staging by themselves:
   `deploy-staging-rules.yml` runs after the "Firestore Rules" suite is green on `main`.
   An index-only change does not trigger that suite; dispatch the workflow by hand.
3. Functions reach staging by dispatching `deploy-firebase.yml` with
   `environment=staging`.
4. Try the change in the staging app.
5. Only then dispatch `deploy-firebase.yml` with `environment=production`. Malin approves
   that run in GitHub before it starts.

Deploy only through the Firebase CLI (the workflows), never through the MCP
`firebase_deploy` tool, and verify every deploy on the resource itself.

## What keeps staging and production apart

- **Credentials.** Production's deploy key lives only in the GitHub environment
  `production`, which requires Malin's approval and accepts only `main` and `v*` tags.
  Staging has no key: CI signs in through Workload Identity Federation, and the pool only
  trusts jobs running in the GitHub environment `staging`. The staging service account
  has no role in production.
- **Guard steps.** Every deploy workflow refuses to run unless its
  `FIREBASE_PROJECT_ID` variable, the `.firebaserc` alias and the credential's project
  all agree.
- **No default project.** `.firebaserc` has the aliases `production` and `staging` and
  no `default`, so a bare `firebase deploy` refuses.
- **Guard test.** `functions/src/__tests__/deploy-project-guard.test.ts` fails CI if a
  workflow names the production id directly, if a `--project` is not taken from the
  environment, or if a workflow or script copies data between the projects.
- **Admin scripts** refuse to start without an explicit `--project`
  (`functions/src/admin/require-project.ts`).
- **No data moves between the projects**, in either direction: no Firestore
  export/import/restore, no copied Auth users. Staging holds synthetic accounts plus
  Malin's own.

## The staging app

Android flavor `staging`, package `se.butlery.app.staging`, next to the production app on
the same phone, with a STAGING banner. Analytics and Crashlytics are off in it. It is
built by `build-staging-apk.yml` (dispatch only, from `main`, signed with the upload key,
short artifact retention).

A password-reset link from staging opens in the browser, not the app: no
`assetlinks.json` naming `se.butlery.app.staging` is published on the staging Hosting
site.

`android/app/src/staging/google-services.json` is gitignored; CI decodes it from the
`staging` environment secret `GOOGLE_SERVICES_JSON_STAGING_BASE64`. Regenerate both
whenever a SHA or sign-in provider changes:

```bash
firebase apps:sdkconfig ANDROID 1:813015847291:android:d7189e15d6845a058e2dde \
  --project butlery-app-staging > android/app/src/staging/google-services.json
base64 -w0 android/app/src/staging/google-services.json \
  | gh secret set GOOGLE_SERVICES_JSON_STAGING_BASE64 --env staging
```

## Test accounts

`functions/scripts/seed-staging.js` creates the synthetic accounts and seeds ingredients
and tag configs. It refuses any project other than staging.

```bash
cd functions && npm run build
STAGING_TEST_PASSWORD='<at least 12 chars>' node scripts/seed-staging.js --project butlery-app-staging
```

## Console settings to keep in step with production

These are set by hand, so they drift unless someone checks them:

- Authentication: email/password and Google; Identity Platform; TOTP MFA; email
  enumeration protection.
- App Check: Play Integrity registration, enforcement **Unenforced** on Firestore,
  Storage and Auth (production is Unenforced too, BUT-1445).
- Remote Config: the same parameters as production.
- `system/config`: kill switches on, LLM caps deliberately low
  (`globalHourlyLimit`, `globalDailyLimit`, `guestDailyImportLimit`).
- Secret Manager: `MFA_RECOVERY_PEPPER` (its own random value),
  `IDENTITY_TOOLKIT_API_KEY` (staging's own browser key), `FEEDBACK_EMAIL_API_KEY` set to
  a placeholder so no feedback mail is sent.
- The Android API key is restricted to `se.butlery.app.staging` and its SHA-1s.
- IAM: the Pub/Sub, Eventarc, Storage and default compute service agents hold the roles a
  functions deploy asks for. The deploy service account cannot grant them, so a deploy
  that prints `gcloud projects add-iam-policy-binding` lines needs them run by hand. For
  the same reason the default compute service account holds
  `roles/secretmanager.secretAccessor` on each of the three secrets, granted by hand.

## Cost

Budget "Butlery staging max 50 kr": alerts to the billing account's owner at 50 % and
100 % of 50 kr, plus a forecast alert. The alert stops nothing. If staging costs more
than 50 kr a month two months in a row, scale it down or delete it.

Artifact Registry: `gcf-artifacts` in europe-west1 carries production's cleanup policy
(`firebase-functions-cleanup`, deletes images older than one day).

## Backups

None, on purpose. Staging holds no data we cannot recreate with the seed script.
Restore drills belong to production (`docs/ops/backups.md`).

## Personal data in staging

Malin signs in to staging with her real Google account (ADR-0032), so staging is a place
where a real person's data is processed:

- **Data subjects:** Malin; the other accounts are synthetic.
- **Purpose:** testing changes before they reach production.
- **Categories:** account data (email, name, Google profile photo) and whatever she enters
  while testing.
- **Recipients/processors:** Google Cloud/Firebase and Vertex AI (EU), as in production.
  Feedback mail is not sent.
- **Location:** Firestore in europe-west3; Storage in US-CENTRAL1, mirroring production.
- **Erasure:** the same TTLs and account-deletion cascade as production run in staging.

## Tearing it down

Delete the GitHub environment `staging`, then `gcloud projects delete
butlery-app-staging` (recoverable for 30 days), then revert the workflow commits.
