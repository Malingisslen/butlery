# Data Residency — moved

This file is superseded. Canonical version: [`docs/operations/data-residency.md`](../operations/data-residency.md)

The canonical document records the verified region decision (`europe-west1`,
Belgium) and the mismatch-handling runbook. The stale unverified rows for Firestore and Cloud Storage have been resolved:
the declared canonical region is `europe-west1` per BUT-774 (2026-05-06).
Console verification (`gcloud firestore databases describe`) is still
recommended to confirm the live database region matches the code pin.
