# ADR-0027: List admins manage members

- **Date:** 2026-10-09
- **Status:** Decided (CTO priority order)
- **Trigger:** BUT-2013, reviewed together with BUT-1924 in PR #621. The BUT-1924 half of
  that panel was not shipped from #621; BUT-2321 (`handOverGroup`, PR #629) replaced it.
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security Architect, Privacy / Data Protection Officer (GDPR),
  Database Administrator / Data-layer Engineer, Trust & Safety / Content Moderation,
  Software Architect, Codebase Archaeologist

## The disagreement

A list admin seating any uid. Trust & Safety and the DPO asked for a friends-only or block
check on new keys, or a recorded decision; the Security Architect noted the owner can
already do it and asked for a size cap.

## Decision

Keep Malin's 2026-09-05 product call (an admin can do everything the owner can) and bound
the map at 200 keys; record the shared BUT-2169 exposure as an accepted deviation. A
friendship check on added keys is not built: rules cannot iterate added keys, and the owner
path has never had one.

## Stakes (per role)

- **Security Architect:** the owner's entry must be untouchable by an admin, absent
  included, and the map needs a bound.
- **Trust & Safety / DPO:** an admin seating strangers widens who can be seated across a
  block; recorded rather than built.
- **Software Architect:** the "may manage members" predicate must not drift again between
  the client guard and the rule.
