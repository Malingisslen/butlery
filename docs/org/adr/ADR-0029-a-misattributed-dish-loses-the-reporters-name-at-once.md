# ADR-0029: A misattributed dish loses the reporter's name at once

- **Date:** 2026-10-10
- **Status:** Decided (CTO priority order)
- **Trigger:** BUT-2339, the report path for a dish in a shared menu and the creator's name
  on every dish (plan in the project's `plans/but-2339-plan.md`)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security Architect, Trust & Safety / Content Moderation,
  Privacy / Data Protection Officer (GDPR), Legal Counsel, Codebase Archaeologist

## The disagreement

1. **Acting on "Det här är inte min rätt" without a moderator.** The DPO asked that a
   report by the person the dish names hides their name on that dish at once, since an
   objection that leaves the name up is not an effective Art. 16/21 remedy. Legal Counsel
   asked that nothing is done automatically on the reporter's assertion, because
   `createdBy` is forgeable and the assertion is unverified.
2. **Which reports skip the strike.** The plan skipped the strike for every `menu_dish`
   report. Trust & Safety asked to skip it only for the reason `misattribution`, so an
   abusive dish reported as abuse, harassment or CSAM still counts against the sharer.
3. **Consent for the wider scope.** The DPO and Legal Counsel asked that consents given
   under the "menus you have shared" text are not reused for every menu.

## Decision

1. The server removes `createdBy` from the reported dish only where it equals the
   reporter's own uid. That withdraws the reporter's own name and decides nothing about
   anyone else, so Legal Counsel's condition holds: no action is taken against the sharer
   or a member, and the case still goes to a moderator. Decided by the priority order
   (user safety and privacy over velocity).
2. Only `misattribution` skips the strike, the strike's `report_history` row and the
   erasure hold; other reasons on a dish count against the sharer as on any shared
   content. Trust & Safety's position, by the same order.
3. No consent was given under the old text: the last TestFlight build (run 5, commit
   d3912fa) predates the toggle (#647), and no web build of the app is published. The text
   changes before any build carries the toggle, so no reset is needed.

## Stakes (per role)

- **Privacy / DPO:** an objection must take effect; the sharer must not be held for
  erasure over a case that accuses nobody.
- **Legal Counsel:** a notice needs an action a moderator can take; nothing is decided on
  an unverified assertion.
- **Trust & Safety:** the repeat-offender signal must survive for real abuse in a dish;
  a misattribution report must not burn the reporter's 24-hour slot for a serious report.
- **Security Architect:** `dishId`, `menu_dish` and `misattribution` are bound as a pair in
  the rules, and `dishId` is a key, never a path.

## Consequence

A moderator gets a removal action for a reported dish (admins may read a shared menu and
change only its `menuSnapshot`). A misattribution report reads no throttle and writes none. The forgery itself
(`createdBy` written by any member) stays possible and is filed as BUT-2352.
