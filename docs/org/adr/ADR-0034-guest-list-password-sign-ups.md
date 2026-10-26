# ADR-0034: Password sign-ups while the guest list is on

- **Date:** 2026-10-24
- **Status:** Escalated to Malin → decided 2026-10-24
- **Trigger:** `tasks/signup-allowlist-plan.md` (BUT-2452, epic BUT-2427)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security Architect, Privacy / Data Protection Officer (GDPR), Software Architect, Database Administrator / Data-layer Engineer, Codebase Archaeologist

## The disagreement
The `beforeUserCreated` gate admits a sign-up only if its email is on `signup_allowlist`.
A password sign-up does not prove the person owns that address.

- **Security Architect:** close the gap before building. Either accept only Google/Apple
  while the gate is on, or consume the invite only once the address is verified.
- **Software Architect:** accepts either requiring `email_verified` or recording the risk as
  an accepted deviation.
- **Privacy/DPO:** notes that the gap can bind an account to a third party's address.

## Decision
Escalated to Malin (security stake, interpretive tradeoff between reach and proof of
ownership). The plan recommended Google/Apple only while the gate is on. Malin chose
"Lösenord med verifiering" (2026-10-24): password sign-ups are allowed for an invited address,
and the invite is consumed only once the address is verified; a sign-in blocking function
refuses unverified password sign-ins after the sign-up session.

## Stakes (per role)
- **Security Architect:** whoever knows an invitee's address can take the single-use invite.
  The real invitee is then locked out, with no trace.
- **Software Architect:** keep the code small. A verified-email flow needs a second blocking
  function and a new app flow.
- **Privacy/DPO:** an unverified account under someone else's address is data about the
  wrong person.

## Consequence
- A second blocking function runs on every sign-in while the gate is on.
- A squatter on an invitee's address keeps at most the one sign-up session, and the owner
  ends it with a password reset; that residue is recorded as an accepted deviation.

Panel conditions, carried in the plan:
- an atomic invite consume;
- a kill switch that only an exact `false` turns off;
- a distinct retryable message on a read error;
- the privacy policy live before the first invite;
- an anonymous-off read-back;
- the region checked in the compiled manifest.
