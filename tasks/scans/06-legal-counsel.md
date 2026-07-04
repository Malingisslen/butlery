# Scan — Role #6 Legal Counsel

Date: 2026-06-27
Passes: 2 (PASS 1 legal-doc accuracy vs data practices; PASS 2 consent records, guidelines-vs-moderation, disclosure contact)
Scope: LICENSE, NOTICE, SECURITY.md, assets/legal/**, account_deletion_service, consent_service, data_export_service, report_service

Note: per the dossier, Legal items default to `escalate-human` authority. Every finding below is flagged `stakeholder: need-malin?` because each is a legal-text / policy decision (or a domain/contact-ownership fact only Malin can confirm), not a code defect Claude should silently fix.

## Verified-good (no finding — confirms the dossier is current)
- Privacy policy correctly names **Vertex AI / Gemini** as the LLM processor (privacy_policy_en.md:124–129, :165). No stale "Mistral" anywhere. (PASS 1 — the suspected stale-processor issue does not exist.)
- Age limit is a single **15** across ToS (terms_of_service_en.md:13), privacy policy (privacy_policy_en.md:286–288, with the correct *Dataskyddslag* 2 kap. 4 § basis, not GDPR Art 8), and SECURITY.md (:27). The earlier docs-13/UI-15 mismatch is resolved per ADR-0001/0002.
- COPPA / underage-discovery incident runbook is present and complete (SECURITY.md:25–50).
- Data-processor inventory (privacy_policy_en.md:157–169) matches processors actually wired in code (Vertex/Gemini, OCR.space, Algolia behind feature flag, Firebase/GA).

---

## NEW findings

### F1 — Appeals contact uses an unverified `butlery.app` domain; everything else is `butlery.se`
**Severity:** High · **stakeholder: need-malin?** YES (only Malin knows whether `butlery.app` is a controlled, mailbox-backed domain)

`appeals@butlery.app` is the sole `.app`-domain address in the whole legal corpus — every other contact (privacy, support, security) is `@butlery.se`. It appears in **both** language ToS and is the only published route to exercise the content-removal appeal right.
- terms_of_service_en.md:54 (`appeals@butlery.app`)
- terms_of_service_sv.md (same address, appeals paragraph)
- All other addresses: `support@butlery.se`, `privacy@butlery.se`, `security@butlery.se`.

If `butlery.app` is not a domain Malin controls with a monitored mailbox, the appeals channel published in the Terms is **non-functional**. A broken/contradictory appeals route is a consumer-law and DSA Art. 20 (internal complaint-handling) exposure, and undermines the moderation due-process the ToS promises (terms_of_service_en.md:52–54, community_guidelines_en.md:46–53). Either point appeals to `appeals@butlery.se` (likely intent) or confirm `butlery.app` is live.
**Verify:** terms_of_service_en.md:54, terms_of_service_sv.md (appeals paragraph), SECURITY.md:5 (`security@butlery.se`), privacy_policy_en.md:23/317 (`privacy@butlery.se`).

### F2 — No persisted Terms-acceptance record (consent-record completeness; affects SSO path too)
**Severity:** High · **stakeholder: need-malin?** YES (accountability-record design; legal decision on what to store)

Terms acceptance at registration is a **UI-only local checkbox** — `_termsAccepted` is a `bool` in `_AuthViewState` gating the submit button, and nothing is ever written to Firestore. Grep for `termsAcceptedAt|acceptedTerms|termsAccepted|tosVersion|termsVersion` across `lib/` returns **only** auth_view.dart. So Butlery cannot demonstrate *when*, *which ToS version*, or *whether* a given user accepted the Terms.
- auth_view.dart:43 (`bool _termsAccepted = false`), :351 (checkbox), :606–609 (gate).
- Contrast with `ConsentService` (consent_service.dart), which *does* persist `grantedAt`, `consentVersion`, `deviceInfo`, and a consent-history audit trail for GDPR-purpose consents. ToS acceptance has no equivalent.

This is the SSO/"second sweep" gap the task flagged: `google_sign_in` is a declared dependency (NOTICE:21), and social/OAuth sign-in is on the post-beta roadmap. A social-login signup path that skips the email/password form would bypass even the in-memory checkbox entirely, so the record gap will widen, not just persist. Recommend a `termsAcceptedAt` + `termsVersion` record written at account creation (mirroring the consent pattern), enforced for *every* signup path including SSO. Note: ToS has no version field at all — terms_of_service_en.md:3 carries only a "Last updated: 2026-02-28" date, so even a stored record would have nothing semantic to pin to. Pair with adding a `version:` to the ToS header.
**Verify:** lib/views/auth_view.dart:43,351,606–609 · grep `termsAcceptedAt|acceptedTerms|termsAccepted` → auth_view.dart only · lib/services/account/consent_service.dart:109–123 (the pattern to mirror) · NOTICE:21 (`google_sign_in`) · assets/legal/terms_of_service_en.md:3 (no version field).

### F3 — No `security.txt` / published vulnerability-disclosure contact (RFC 9116)
**Severity:** Medium · **stakeholder: need-malin?** YES (decision to publish a security contact + scope URL on the public web origin)

SECURITY.md documents a disclosure process and `security@butlery.se`, but there is **no `.well-known/security.txt`** on the web origin. Glob for `**/security.txt` → none; `web/.well-known/` contains only `apple-app-site-association`, `assetlinks.json`, `README.md`. RFC 9116 `security.txt` is the now-standard machine-discoverable disclosure channel (and is increasingly checked by automated researchers and some app-store / enterprise reviews). For a public repo accepting a coordinated-disclosure window (SECURITY.md:23), a `web/.well-known/security.txt` pointing at `security@butlery.se` + the SECURITY.md policy is low-effort and closes the gap.
**Verify:** SECURITY.md:5,23 · `web/.well-known/` (no security.txt) · glob `**/security.txt` → no files.

### F4 — Community Guidelines list no enforceable AI / image-content rules and predate current moderation surfaces
**Severity:** Low–Medium · **stakeholder: need-malin?** YES (UGC-liability policy scope; what the guidelines promise vs what moderation enforces)

Community guidelines (community_guidelines_en.md, "Last updated 2026-02-28") cover harassment, spam, copyright, impersonation, and an enforcement ladder — but the moderation code (`report_service.dart`) now actions content types the guidelines never mention or scope:
- `ReportService` moderates **cookSnap** images (report_service.dart:250–253) and **profile** takedowns (`suspendReportedProfile`, :195–227). The guidelines' "inappropriate content" section (community_guidelines_en.md:28–32) only says "do not share images unrelated to food" — there is no policy basis stated for hiding a profile or removing a cook-snap, nor any mention of AI-generated / user-uploaded image misuse, sexual or violent imagery, or the `moderate-upload.ts` SafeSearch-style controls the backend is moving toward.
- `kCurrentGuidelineVersion` is pinned in code and stamped onto every report (report_service.dart:57) for versioned enforcement — but the guidelines doc itself carries only a date, not a matching version string, so the report-time "which guidelines applied" link cannot be resolved to a versioned document.

Recommend: add an explicit image-content / impersonation-image clause and a guidelines **version field** that matches `kCurrentGuidelineVersion`, so the moderation audit trail (report → guidelineVersion) points to a real, versioned policy. This is the UGC-liability "what we promise = what we enforce" alignment.
**Verify:** assets/legal/community_guidelines_en.md:3,28–32,46–53 · lib/services/moderation/report_service.dart:57,195–227,250–253 · functions/src/storage/moderate-upload.ts (image moderation backend, referenced).

---

COVERAGE: Reviewed both passes. PASS 1 (legal-doc accuracy vs data practices): privacy policy processors/Gemini/age-limit/COPPA all verified accurate against code — no findings, suspected stale-Mistral issue does not exist. PASS 2 (consent records, guidelines-vs-moderation, disclosure contact): 4 NEW findings — F1 broken appeals domain (`butlery.app` vs `.se`), F2 no persisted Terms-acceptance record (widens on SSO), F3 missing RFC 9116 security.txt, F4 community-guidelines scope/version drift vs moderation behavior. Not covered (out of owned-path scope or already-ticketed): age-gating enforcement (ADR-0001/0002, BUT-1386 in-progress), OCR image-retention disclosure (existing watch-item), EU AI Act Art. 50 (existing need-malin ticket), Google Play Data Safety form (existing deferred ticket). All findings flagged `need-malin` per escalate-human authority.
