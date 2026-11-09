# Vertex AI: AI import on staging fails at the Gemini step (BUT-2431 blocker)

Repo copy goes to `tasks/vertex-region-plan.md` on approval. (The previous plan in this file,
the AI-cap signal, is done and lives in `tasks/ai-cap-signal-plan.md`.)

## Context

Malin's card answer, relayed by the parent session: "Ja, laga nu". On staging on 2026-10-21,
every `structureRecipe` call failed with `Invalid hostname: eu-aiplatform.googleapis.com`.
Photo OCR fails the same way, because it goes through the same client. Fas 3 cannot switch AI
on in new prod until this is fixed.

Root cause, from the debugger and Google's docs, measured 2026-10-21:
1. `functions/src/llm/gemini-client.ts` sets `VERTEX_LOCATION = "eu"` (BUT-1187, 2026-06-03).
   `@google-cloud/vertexai` builds the host `${location}-aiplatform.googleapis.com`, which does
   not exist for the multi-region. Google's EU multi-region host is
   `aiplatform.eu.rep.googleapis.com`, per the Vertex locations docs.
2. Even on the correct EU host, `countTokens` returns 404 "model not found or no access" for
   `gemini-2.5-flash-lite`, `-flash` and `-pro` in this project. On `europe-west1` all three
   return 200. The BUT-1187 premise ("2.5 not reliably served in europe-west1") is the reverse
   of what this project shows today.
3. The move has never run: prod shows no Gemini call in the 150 days of logs, and staging's
   first real calls were today's test. The app hides the failure, because Gemini is the last of
   four parsing tiers.

## Judgment call (A)

**① Region: `europe-west1` (recommended).** The models answer there, and both privacy
policies already name it.
- *Alternative:* keep the `eu` multi-region and add `apiEndpoint: "aiplatform.eu.rep.googleapis.com"`.
  The cost is that today the endpoint answers 404 "model not found" for every 2.5 model in this
  project, so imports stay broken until Google or project access changes, and the policies would
  also need rewording.
- *Reply starter:* to keep `eu` with the explicit endpoint instead, say "behåll eu".

**Weakest point:** the 404 on `eu` was measured with `countTokens`, not `generateContent`. That
doesn't change the choice: `europe-west1` returns 200 either way, and the real staging import in
verification is the proof.

## Change

- `gemini-client.ts`: set `VERTEX_LOCATION = "europe-west1"`. That region is the one both
  privacy policies already name ("Vertex AI i regionen `europe-west1`"), so the code goes back
  to what is published. Residency stays in the EU (Belgium), which is a decision in favour of
  the published text, not a new one.
- Strike the false sentences in the same file: the BUT-1187 rationale in the header comment,
  and the "Paired with the … `eu` move" paragraph above `TEXT_MODEL`. Add no replacement prose
  beyond what the code shows.
- `docs/architecture/llm-versions.md` item 4: strike the `eu` claims so the line reads as an
  EU-resident region with a per-project check.
- Test `functions/src/__tests__/vertex-region.test.ts` (new), registered as an npm `test:*`
  script. It pins the invariant behind the bug: the host the SDK will build from
  `VERTEX_LOCATION` must be one Google serves. That means a single-region location
  (`/^europe-west\d+$/`) with no `apiEndpoint`, or else a multi-region with an explicit
  `.rep.` endpoint. It also asserts the location is in Europe (residency). A mutant that sets
  `"eu"` must turn the test red.
- Out of scope, kept as a follow-up card: `@google-cloud/vertexai` is deprecated (its own
  warning gives a removal date of 2026-06-24) and should migrate to `@google/genai`. The
  privacy policy still says "Mistral via Vertex AI", which is stale wording.
- Files owned by Fas 1/2 (`admin/require-project.ts`, `shared/ocr-url-validator.ts`,
  workflows) are not touched.

## Verification

1. `npm --prefix functions run build`. The new test is green and the `"eu"` mutant is red.
   `gemini-cache-telemetry` and `ocr-handwritten-prompt` stay green.
2. Commit gate: `cloud-functions-specialist`, then push to main.
3. Deploy `structureRecipe` to staging only, via the CLI. Run one real import as a test user
   (custom token, App Check). This needs the same temporary signing grant again: the
   `roles/iam.serviceAccountTokenCreator` role on the staging admin service account only. It
   is added just before the run, removed straight after, and the removal is read back.
   Approving this plan approves that one binding.
   Pass means `success: true` with a recipe, and the logs show `modelId gemini-2.5-flash-lite`
   with no error. Leave caps and `system/config` untouched. Delete the test user afterwards.
4. Comment the root cause and proof on BUT-2431.

## Open questions

No architecture-changing unknowns. Assumptions:
- Moving to the region the privacy policies already state needs no legal-text change.
- New prod (Fas 3) gets the fix from main when it deploys its functions.

Checklist self-review:
- Design system, UI states, DI and visual previews do not apply (backend only).
- Security/GDPR: no new data. Residency stays in the EU and matches the policy.
- Testing: a named test plus a mutant, and the existing LLM suites.
- Scope: one constant, struck comments, one test. The SDK migration is deferred.
- Cost: no new calls or reads.

## What this means in plain language (Sammanfattning för Malin)

- Receptimport med AI har aldrig fungerat sedan juni: koden pekade på en AI-adress som inte finns, och appen dolde felet genom att använda de enklare tolkarna.
- Jag flyttar AI-anropen till `europe-west1` i Belgien, den region som integritetspolicyn redan anger. Data stannar i EU.
- Ett test ser till att adressen inte kan bli fel igen på samma sätt.
- Jag provar en riktig import på staging. Nya prod rör jag inte.
- För provet behövs samma tillfälliga behörighet på staging som förra gången. Den läggs till och tas bort direkt efteråt, och godkänner du planen godkänner du den.
- Risk: liten. Det är en rad kod, och den går att ångra lika snabbt.
