# LLM Response Samples — Retention Policy (BUT-1451)

GDPR Article 30 record covering the `llm_response_samples` collection: the
(scrubbed) inputs and outputs of paid Gemini calls, captured to improve the
deterministic parser and the prompts.

## DPO decision

**30-day retention — APPROVED by Malin Gisslén (acting DPO), 2026-06-30.**

Rationale (Art 5(1)(e) storage limitation + 5(1)(c) data minimisation): these
samples are operational debugging / training signal, not a record carrying a
legal-obligation or consent-evidence purpose. 30 days comfortably covers the
prompt-iteration and parser-mining cadence, after which a sample's value decays.
Deliberately **shorter** than the 24-month audit/consent windows and the
family-data window — there is no Art 7 (consent evidence) or Art 6(1)(c) (legal
obligation) purpose here, so the minimal window that still serves the engineering
goal wins.

## Status

Active. Enforced by **Firestore native TTL** on the `expireAt` field —
policy `state: ACTIVE`, enabled 2026-06-30 via
`gcloud firestore fields ttls update expireAt --collection-group=llm_response_samples
--enable-ttl --database='(default)' --project=butlery-app-1`.

Capture: [`functions/src/llm/llm-sample-capture.ts`](../../functions/src/llm/llm-sample-capture.ts)
(`captureLlmSample`), written best-effort from `structureRecipe` and
`ocrRecipeImage` (europe-west1). Runtime off-switch:
`system/config.llmSampleCaptureEnabled` (default on).

## Privacy posture (load-bearing)

- **Input** is PII-scrubbed upstream by `scrubPii` before it ever reaches the
  model; the stored copy is that already-scrubbed text. Image inputs (OCR) store
  **no bytes** — only the model's returned text.
- **Output** is scrubbed again by `scrubPii` *inside* the capture helper before
  storage, so nothing un-scrubbed is persisted even if the model echoes PII.
- **Access:** denied to all clients in `firestore.rules`
  (`match /llm_response_samples` → `allow read, write: if false`); Admin-SDK
  writes only. Proven by `functions/src/__tests__/llm-response-samples-rules.test.ts`
  (11/11).
- **Pseudonymous:** `authUidHash` is a SHA-256 hash, never the raw uid.
- **Bounded:** each text field truncated to 50,000 chars.

## Per-field record (Art 30)

Every field written by `captureLlmSample`. If a field is added there it must be
added here.

| Field | Purpose | Lawful basis | Retention |
|---|---|---|---|
| `mode` | Which call type (extract/enhance/spoken/ingredientLines/ocr) | Art 6(1)(f) — legitimate interest (product quality) | 30d TTL |
| `inputKind` | `text` or `image` | Art 6(1)(f) | 30d TTL |
| `scrubbedInput` | Scrubbed model input (null for image) — find parser-handleable cases | Art 6(1)(f) | 30d TTL |
| `scrubbedInputLength` | True pre-truncation length | Art 6(1)(f) | 30d TTL |
| `scrubbedOutput` | Scrubbed model output — compare vs deterministic parse | Art 6(1)(f) | 30d TTL |
| `outputLength` | True pre-truncation output length | Art 6(1)(f) | 30d TTL |
| `promptVersion` / `promptSource` | Tie a sample to the exact prompt | Art 6(1)(f) | 30d TTL |
| `experimentBucket` / `promptVariant` | A/B slicing | Art 6(1)(f) | 30d TTL |
| `domain` | Recipe-source hostname (no path/query) | Art 6(1)(f) | 30d TTL |
| `authUidHash` | SHA-256 of uid (pseudonym) — dedup / abuse triage only | Art 6(1)(f) | 30d TTL |
| `modelId` / token counts | Cost + model correlation | Art 6(1)(f) | 30d TTL |
| `createdAt` | Server timestamp | Art 6(1)(f) | 30d TTL |
| `expireAt` | TTL field — drives native deletion | Art 5(1)(e) | N/A (the purge field) |

## Account deletion cross-cut

Samples are pseudonymous (`authUidHash`, never a raw uid), scrubbed, and
30-day-TTL'd, so they are **not** synchronously deleted at account close — the
TTL is the erasure schedule (Art 5(1)(c)/(e) satisfied by minimisation +
short window). ⚠️ If a future change makes samples re-identifiable or correlates
them to a specific account for mining, revisit this and wire them into
`account-deletion-cascade.ts`.

## Phase-2 note

Mining (cross-referencing with `parse_corrections_v2`, seeding a recorded-test
corpus) is out of scope here. Any pipeline that *copies* sample content
elsewhere must carry this retention/scrubbing forward — don't let a derived
store outlive the 30-day window without a fresh DPO decision.
