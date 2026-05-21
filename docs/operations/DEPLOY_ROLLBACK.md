# Deploy Rollback Runbook (BUT-452)

This runbook covers rolling back a bad deploy of Cloud Functions, Firestore
rules, Realtime Database rules, Storage rules, or Hosting. Companion doc:
`RELEASE_POLICY.md` (deploy gating + change windows).

## Decision matrix

| Symptom | Surface | Rollback tier |
| ------- | ------- | ------------- |
| New CF version throwing on every invocation | Functions | T0 — `gcloud functions deploy` previous |
| Rule change locks legitimate users out | Firestore / RTDB / Storage | T0 — checkout prior commit + redeploy |
| Hosting build pushes broken web client | Hosting | T1 — channel revert |
| Index missing post-rule-change | Firestore indexes | T1 — re-add index, wait for build |
| Client release crashing on launch | App (Play / TestFlight) | T1 — Play "Halt Rollout" / TestFlight revoke |

> **Solo-dev guidance:** before any rollback, capture the diff that caused
> the issue (`git log -p <bad-commit>`) so the post-mortem has the evidence.
> The rolled-back code is gone from prod but not from git history.

## 1. Cloud Functions rollback (T0)

Each deployment of a function creates a new revision. The previous one
remains available — switch traffic back to it.

```sh
PROJECT=butlery-app-1
REGION=europe-west1
FN=onUserCreated

# Inspect revisions to find the last known-good one.
gcloud functions describe $FN \
  --project=$PROJECT \
  --region=$REGION \
  --gen2 \
  --format='value(serviceConfig.revision)'

# Re-deploy from the last-known-good commit.
git checkout <known-good-sha> -- functions/src
npm --prefix functions ci
npm --prefix functions run build
firebase deploy --only functions:$FN --project=$PROJECT
```

For a **broad blast radius** (many functions broken simultaneously): roll
back the entire `functions/` tree from git.

```sh
git checkout <known-good-sha> -- functions/
npm --prefix functions ci
npm --prefix functions run build
firebase deploy --only functions --project=$PROJECT
```

Deploy emits per-function revisions — if a single one fails, others stay on
the new version. After the deploy, verify with one canary invocation per
critical function.

## 2. Firestore rules rollback (T0)

The most common cause of a same-day P1: a `match` clause tightening that
locks legitimate users out.

```sh
PROJECT=butlery-app-1

# Confirm the active rules version.
gcloud firestore databases describe \
  --project=$PROJECT \
  --database='(default)'

# Roll back the file from git + redeploy.
git checkout <known-good-sha> -- firestore.rules
firebase deploy --only firestore:rules --project=$PROJECT
```

Run the rules unit-test suite **before** redeploying to catch a second
self-inflicted wound:

```sh
npm --prefix functions test -- --testPathPattern=rules
```

## 3. Realtime Database / Storage rules

Same flow as Firestore rules:

```sh
git checkout <known-good-sha> -- database.rules.json
firebase deploy --only database --project=$PROJECT

git checkout <known-good-sha> -- storage.rules
firebase deploy --only storage --project=$PROJECT
```

## 4. Hosting rollback (T1)

Firebase Hosting keeps the last 10 releases. Promote a prior release back
to `live`.

```sh
PROJECT=butlery-app-1
SITE=butlery-app-1  # Hosting site ID, usually same as project

# List recent releases — note the `version` field of the one you want.
firebase hosting:releases:list --site=$SITE --project=$PROJECT

# Promote a prior version to live (cloning is the canonical way).
firebase hosting:clone $SITE:<prior-version-id> $SITE:live \
  --project=$PROJECT
```

If a static asset is the issue (bad image / wrong CSP) and you can't wait
for a re-clone, push a one-line fix and let the new deploy roll forward
instead of rolling back.

## 5. Firestore indexes

You cannot "roll back" an index removal — the index has to rebuild. If a
rule change removed the wrong index:

```sh
git checkout <known-good-sha> -- firestore.indexes.json
firebase deploy --only firestore:indexes --project=$PROJECT
```

Then expect a multi-minute to multi-hour build window depending on
collection size. During the build, queries that need the index return
`failed-precondition`. The app should already handle this — if not, file
a bug.

## 6. Mobile client rollback (T1)

### Android (Play Console)

1. Console → Production → Releases → "Halt rollout" on the current release.
2. New users get the prior version; existing users on the new version stay
   on it until they uninstall.
3. To force a roll-down: file a new release with a higher versionCode
   containing the prior code (you cannot publish a *lower* versionCode).

### iOS (App Store Connect)

1. App Store Connect → My Apps → Butlery → App Store → "Remove from Sale"
   stops new downloads of the bad version.
2. Submit a new build with the prior code (must be a higher build number).
3. Use TestFlight to validate before pushing the rollback to production.

## Validation after any rollback

- [ ] Run a representative request through the rolled-back surface.
- [ ] Check Crashlytics — error rate should drop within 5 min.
- [ ] Check Firebase Functions logs — no recurring exceptions.
- [ ] Notify any affected users (see `INCIDENTS.md` §Communications).
- [ ] File a post-mortem ticket within 72h.
