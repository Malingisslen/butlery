# ADR-0033: A new production project in the EU replaces `butlery-app-1`

- **Date:** 2026-10-20
- **Status:** Decided (two conflicts resolved by synthesis; Malin's choices recorded)
- **Trigger:** new-prod-project plan (`tasks/new-prod-project-plan.md`, brief in
  `tasks/new-prod-project-brief.md`, follow-up of BUT-451)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** DevOps/SRE, Security Architect, Privacy/DPO, FinOps,
  Release/App-Store Compliance, Codebase Archaeologist

## The disagreements

**1. The old deploy key.** Security wanted the `butlery-app-1` service-account key revoked
at Google the same day its GitHub secret is deleted. DevOps wanted the secret kept until the
old project is deleted, as the only way back if the new project fails.

**2. The Storage bucket's region.** The plan's first draft put the bucket in europe-west3,
next to Firestore. DevOps flagged that the `moderateUpload` Storage trigger is pinned to
europe-west1 and that a cross-region trigger was untried.

## Decisions

1. Nothing is deleted before the old project is retired. On retirement day the key is
   revoked at Google and the GitHub secret `FIREBASE_SERVICE_ACCOUNT` is deleted, and a
   production deploy afterwards must still go green. Both conditions hold. Resolved by
   synthesis: data-integrity & security (a working rollback) outranks velocity.
2. The bucket goes in **europe-west1**. Firebase's documentation on Cloud Storage triggers
   requires the function and its bucket to share a region, so the bucket follows the
   function rather than the database. Resolved by the documentation, not by priority.

Malin's choices, asked as cards on 2026-10-20: project id `butlery-app` (fallback
`butlery-prod`); `butlery.app` is pointed at the new project during the build; the app is
not in Play Console today, so it is created there with Play App Signing; App Check is
switched on after the phone and web proofs pass; the old project is deleted when the proofs
are green and 7–14 days of silence show no caller but Malin; staging is rebuilt in the EU
first, as the dress rehearsal.

## Stakes (per role)
- **Security:** a long-lived key that outlives its project is a standing credential.
- **DevOps/SRE:** the only tested rollback is a deploy to the old project with the old key.
- **Privacy/DPO:** the new project is where the test group's data will be processed;
  nothing personal moves between projects, only the ML model files.
- **FinOps:** three projects run in parallel during the switch; a billing-account budget is
  the only alarm that sees their sum.
- **Release:** a sideloaded build cannot pass Play Integrity, so Play Console is on the
  critical path.

## Consequence
The conditions are the plan's acceptance criteria (section H). The old project's data
(four test accounts) is erased through the deletion cascade before the project is deleted.
ADR-0032 is closed by the staging rebuild: staging's bucket moves to the EU too.

## Supersession, 2026-10-28

Retires this sentence in Malin's choices above: "`butlery.app` is pointed at the new project
during the build".

What the code and hosting do now: the app's links and hosting use `butlery.se` (Firebase
Hosting site `butlery-prod`; `www.butlery.se` redirects to it). The legal site is
`legal.butlery.se`, on the Hosting site `butlery-prod-legal`. `butlery.app` is not ours and
is not used. The decision is Malin's of 2026-10-27.
