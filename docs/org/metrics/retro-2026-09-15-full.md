# Org retro — full — 2026-09-15

Period: 2026-07-04 (last retro, shakedown) .. 2026-09-15. Ran as step 3 of a local `/janitor`.
Source: `docs/org/metrics/events.jsonl` (253 rows), `docs/org/adr/`, `docs/org/world-watch/state.json`,
GitHub issues, Linear. First full retro, so there is no earlier full retro to trend against.

## Worst first

1. **The freshness loop was blind in the cloud for ten weeks.** `.gitignore` ignores
   `docs/org/dossier-staleness/*.stale`, while the directory README says the markers are committed.
   The cloud janitor never sees them. Its stamps for 2026-08-31, 09-07 and 09-14 each reported zero
   refreshes, and the 09-14 stamp says "No stale dossier markers". Meanwhile 27 of 28 markers had
   built up on this machine, the oldest `stale_since` being 2026-07-16 (Security Architect).
   The 2026-07-04 shakedown retro already named this as its headline. It is still not fixed.
   Zero `freshness` events have been logged, so the freshness false-positive rate cannot be measured.
2. **Review events are missing for panel decisions.** Four ADRs record a stakeholder panel:
   ADR-0009, 0010, 0011 and 0020. A grep for those ids and the rate-limit plan finds only 1 row in
   events.jsonl. The newest review row is dated 2026-09-13, while ADR-0020 is dated 2026-09-14.
   So the rubber-stamp and cost figures below undercount real reviews.
3. **Triggers over-suggest.** 168 `trigger` rows (71 in the last 30 days). Only 41 of the 168
   (24%) were followed by a held review within 6 hours.
   Of the 33 held ad-hoc (non-sprint) reviews, 15 had a trigger less than 6 hours before them.
   The 17 `manual` rows explain most of the rest.
4. **The Google Play sources are egress-blocked in cloud scans.** `support.google.com` and
   `play.google.com` were blocked in the 2026-09-07 cycle for both Security and Release roles. Three
   high-stakes sources were carried forward unchecked ("Re-verify next cycle").

## Scorecard

| Line | Result | Data |
|---|---|---|
| Phase-2 rubber-stamp rate | 0 / 51 held reviews (0%) | 50 rows carry `rubber_stamp:false`, 1 legacy row has 6 conditions. Every held review has at least 3 must-haves. The panel never approves clean. That means either it earns its cost, or conditions are inflated. Judge that against item 2 before tuning. |
| Owed-and-declined reviews | 26 (`ran:false`), all 2026-08-13..08-23 | Most often owed: Software Architect 18, Product Manager 17, Vendor/Procurement 15, DBA 14, Security 14 |
| Escalations | 19 of 51 held reviews escalated | ADRs cited by review rows: 0004-0008, 0012-0019 |
| Trigger calibration (ad-hoc subset) | 24% of triggers followed by a review | Fired 168, followed 41 |
| World-watch signal | Material items reached tickets | GitHub #215, #220, #223, #235. Only 1 `world-watch` event is logged; the rest lives in state.json snapshots, so a noise ratio is not computable |
| Freshness accuracy | insufficient data | 0 `freshness` events. See item 1 |
| Cost per review | avg ~698k tokens (n=32 with `approx_tokens`) | single ~458k vs full ~861k (single ≈ 53% of full). Last 30 days avg ~789k |

## False-negative spot-check — PASS

Checked change: the Google Play policy announcement of 2026-07-15 (anonymous/random-chat child-safety
rules; third-party AI integrations under the User Data policy; developer verification enforced from
2026-09-30).

Result: it reached the system. The Legal Counsel snapshot records all four parts. The AI-integration
part is GitHub #220. Developer verification is GitHub #223, **still OPEN, 15 days before the
2026-09-30 date.** Legal judged the anonymous-chat part inapplicable because Butlery's chat is not
anonymous or random. That reading is plausible, but the app does have chat that minors can reach,
so it deserves a second look by Trust & Safety.

## Tuning recommendations (founder decides — none applied)

1. Make the freshness markers visible to the cloud janitor. Either un-ignore
   `docs/org/dossier-staleness/*.stale` (which is what the README describes) or run the janitor
   locally. Also fix the cloud janitor so it reports "markers not visible" instead of "no stale markers".
2. Make stakeholder-review panels write their `review` event when the ADR is written, and backfill
   ADR-0009/0010/0011/0020.
3. Narrow the plan-review trigger's signal list. 76% of firings are not followed by a review.
4. Re-verify the three blocked Google Play sources from a local session, and close or act on #223
   before 2026-09-30.
5. Have Trust & Safety confirm that the Play anonymous/random-chat rules do not reach group chats
   that include minors.
