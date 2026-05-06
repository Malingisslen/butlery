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
