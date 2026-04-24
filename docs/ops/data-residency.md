# Data Residency — EU / GDPR Chapter V

Single-page reference for where Butlery user data is processed. GDPR Chapter V prohibits cross-border transfer without appropriate safeguards; this file records each processing location and how to verify it.

## Regions

| Service | Region | Verified by | Verified on |
|---|---|---|---|
| Firestore (Native) | **USER MUST VERIFY** | Firebase Console → Firestore Database → header shows location | — |
| Cloud Storage (default bucket) | **USER MUST VERIFY** | Firebase Console → Storage → Files → bucket location | — |
| Cloud Functions (2nd gen) | `europe-west1` | `functions/src/index.ts:20` — `setGlobalOptions({ region: "europe-west1" })` | 2026-04-24 |
| Vertex AI (Gemini models) | `europe-west1` | `functions/src/llm/gemini-client.ts:28` — `VERTEX_LOCATION = "europe-west1"` | 2026-04-24 |
| Firebase Authentication | Global (managed by Google) | Not region-pinnable. User credentials governed by Google Cloud DPA. | n/a |

## Verification commands

```bash
# Firestore — authoritative region (immutable after creation)
gcloud firestore databases describe --project=butlery-app-1 --database="(default)"

# Cloud Storage — default bucket
gcloud storage buckets describe gs://butlery-app-1.appspot.com --project=butlery-app-1 --format="value(location)"

# Cloud Functions — per-function region (expect europe-west1)
gcloud functions list --project=butlery-app-1 --format="table(name,region)"
```

## Escalation: Firestore region is NOT EU

Firestore region is **immutable** after database creation. Non-EU region requires:

1. Stop writes to the existing project.
2. Create a new Firebase project with EU region (`eur3` multi-region or `europe-west1`).
3. Export from the old project via `gcloud firestore export gs://<bucket>/<path>` and import into the new one.
4. Migrate Auth users (Admin SDK export/import — hashed passwords preserved).
5. Swap `lib/firebase_options.dart` and `firebase.json` project id across every platform target.
6. Re-deploy Cloud Functions, rules, indexes to the new project.
7. Update client builds, push out an app update.

This is days of work with a mandatory maintenance window. **Do not proceed without explicit go-ahead.**

## Migration history

- **2026-04** — BUT-614: Gemini calls migrated from Google AI Studio (`generativelanguage.googleapis.com`, US egress) to Vertex AI `europe-west1`. Privacy policy data-processor inventory updated (Swedish + English). Commit landed in prior session.
- **2026-04** — BUT-607: This document created. Firestore + Storage region verification still requires a Firebase Console check by the account holder — the CLI (`gcloud firestore databases describe`) returns the authoritative answer.

## What "EU" means for GDPR Chapter V

If Firestore, Storage, Functions, and Vertex AI all resolve to an EU region (`europe-*` or `eur3`), no Chapter V transfer occurs for the data flows those services touch. Firebase Authentication is the remaining carve-out: it is globally managed and governed by the Google Cloud DPA + EU-US Data Privacy Framework, which is disclosed in the privacy policy.

## Privacy policy sync

Data-processor inventory in `assets/legal/privacy_policy_{sv,en}.md` must stay aligned with this document. Any region change requires a privacy-policy update in both locales and a bump of `Senast uppdaterad` / `Last updated`.
