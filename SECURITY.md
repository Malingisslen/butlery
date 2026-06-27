# Security Policy

## Reporting a vulnerability

If you discover a security vulnerability in Butlery, please email
**security@butlery.se** with the details. Do not file a public GitHub issue
or open a PR — that exposes the issue before users can be protected.

A useful report includes:
- Affected component (Flutter app, Cloud Functions, Firestore rules, etc.)
- Reproduction steps or proof of concept
- Impact assessment (data exposure, privilege escalation, denial of service…)
- Your suggested fix, if you have one

## Response timeline

We aim to:

| Step | Target |
| ---- | ------ |
| Acknowledge receipt | within **48 hours** |
| Provide a fix or mitigation plan | within **7 days** for High/Critical, **30 days** for Medium/Low |
| Coordinated disclosure window | **90 days** by default, negotiable |

## Incident response: underage user discovered

Butlery's single minimum age is **15** (ADR-0001; Sweden's Dataskyddslag 2 kap. 4 §
for information-society services with a social component). If we discover — via a
report, a parent/guardian contact, or moderation — that an account belongs to someone
under 15, treat it as a data-protection incident and run this sequence:

1. **Suspend** the account immediately (hide the public profile; revoke active sessions)
   so no further personal data is processed while we act.
2. **Delete** the account and all associated personal data under **GDPR Article 17**
   (right to erasure), using the existing server-side deletion cascade
   (`functions/src/account/account-deletion-cascade.ts` → `request-account-deletion`).
   This is the same own-data + cross-user cascade used for user-initiated deletion.
3. **Assess notification duty within 72 hours.** Decide whether the discovery is a
   personal-data breach under GDPR Art. 33. If so, notify the **IMY**
   (Integritetsskyddsmyndigheten) within 72 hours of becoming aware, and the affected
   data subject under Art. 34 where required. Record the assessment even when the
   conclusion is "no notification required."
4. **Owner + timeline.** The maintainer (Malin) owns the decision and the IMY contact.
   Log the discovery time, suspension time, deletion time, and the Art. 33 assessment
   outcome in the incident record. Target: suspend within hours of discovery, delete
   and complete the assessment within the 72-hour window.

**COPPA scope.** Butlery does not currently distribute in the US, so COPPA (the US
under-13 regime) does not yet apply. If/when US distribution begins, extend this runbook
with COPPA's under-13 verifiable-parental-consent and deletion obligations before launch.

## Supported versions

Only the latest released build is supported. We do not backport security
fixes to older releases.

## Scope

Findings in any of the following are in-scope:
- The Butlery mobile/web app (Flutter, this repository)
- The Cloud Functions backend (`functions/` directory)
- Firestore security rules (`firestore.rules`)
- Storage security rules (`storage.rules`)
- CI/CD workflows that produce production artifacts (`.github/workflows/`)

Out-of-scope:
- Third-party services we depend on (Firebase, Vertex AI, Algolia, etc.) — please
  report those directly to the vendor.
- Findings that require physical device access or a compromised root account.
- Social engineering of the maintainer.

## Safe harbor

We will not pursue legal action against researchers who:
- Make a good-faith effort to avoid privacy violations, data destruction,
  or service degradation.
- Only access data necessary to demonstrate the vulnerability.
- Give us reasonable time to remediate before public disclosure.

Thank you for helping keep Butlery and its users safe.
