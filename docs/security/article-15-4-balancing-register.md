# Art. 15(4) balancing register — what a data export discloses about other people

Accountability record (Art. 5(2)) for the data-subject-access export. Article 15(4): the right
to a copy must not adversely affect the rights and freedoms of others. Each row below is one
decision about another person's data inside the requester's Art. 15 bundle: what is kept, what
is withheld, who decided, and when. Companion to the Art. 30 records in this folder
(`account-subcollections-retention.md`, `notification-analytics-retention.md`,
`family-data-retention.md`).

The full reasoning stays in the decision records this table points at, which remain the source
of truth: `docs/architecture/ACCEPTED_DEVIATIONS.md` (cited by a heading, or by the ticket id
inside a heading's section) and `docs/org/adr/`. Each row states the CURRENT outcome; where a
decision was superseded, the row or the list below names what replaced it.

"Malin" is the founder. "Default, then Malin" means the code shipped a conservative default
first and Malin kept it on the second date.

## Decisions

| # | Decided | Ticket | Export section | Other people's data KEPT | Other people's data WITHHELD | Decided by | Rationale |
|---|---|---|---|---|---|---|---|
| 1 | 2026-06-30 | BUT-1450 | Notification delivery records | The counterparty's uid (`senderId` / `targetUserId`) | Nothing; uids are not resolved to names | Malin, over a Privacy/Legal panel that recommended stripping the uid | ACCEPTED_DEVIATIONS: "notification_delivery counterparty is exported, not anonymised (BUT-1450)" |
| 2 | 2026-07-30 | BUT-1732 | `shared_shopping_lists` | Other members' uids, permission levels, `contributorUserIds`, per-row uids | Six cached display names of everyone but the requester | Malin | ACCEPTED_DEVIATIONS: "Shared shopping lists export other members' UIDs but not their display names (BUT-1732)" |
| 3 | 2026-07-30 | BUT-1772, BUT-1767, BUT-1775 | `messages` (`conversation_info`, message rows); `shared_recipes_received`, `shared_menus_received`, `shared_shopping_lists_received` | Participants' display names and uids, `lastMessage` | Every other person's avatar URL (one helper, `dropAvatarUnlessOwn`) | Malin | ACCEPTED_DEVIATIONS: "The conversations export keeps other participants' display names …" |
| 4 | 2026-07-30 | BUT-1774 | `messages` (`conversation_info`) | `lastReadTimestamps` | Other participants' `perUserSettings` (mute, pin, archive) | Malin | Same section as row 3 |
| 5 | 2026-08-01 | BUT-1798 | `shared_content` received rows | Other recipients' uids; the sharer's display name | — (avatar per row 3) | Malin | ACCEPTED_DEVIATIONS: "The `shared_content` export keeps other recipients' UIDs and the sharer's display name (BUT-1798)" |
| 6 | 2026-08-01 | BUT-1798, BUT-2093 | Nested `listData` copy inside a shared shopping list | Other members' uids and permission levels | Other members' display names. Since BUT-2093 (Malin, 2026-10-10) new shares are stored without names; the export still redacts older ones | Malin | ACCEPTED_DEVIATIONS: "Inside a shared shopping list's nested copy, other members' names are stripped (BUT-1798)"; "BUT-2318 and BUT-2093 — …" |
| 7 | 2026-08-12 | ADR-0005 (D5) | Household allergen sharing | — | Other members' shared allergen lists (Art. 9 health data); only the requester's own share and consent record are exported | Malin | `docs/org/adr/ADR-0005-household-allergen-sharing.md`, D5 |
| 8 | 2026-08-13, 2026-09-17 | BUT-1838 | `messages` (group conversations) | — | Other members' `memberSince` (the requester's own is kept) | Default, then Malin | ACCEPTED_DEVIATIONS: "Art. 15 — the four open withholding questions, answered (2026-09-17)", row 1 |
| 9 | 2026-08-26 | ADR-0009, BUT-1955 | `messages` | The requester's own vote on a withheld row (`your_poll_votes_on_withheld_messages`, BUT-1955, 2026-10-09) | Another participant's duplicate-guard blocked row with empty content; a stamped row that carries text is kept | Malin (the filter); the BUT-1955 own-vote export is not recorded as hers | `docs/org/adr/ADR-0009-the-duplicate-guard-marks-instead-of-deleting.md` ("DECIDED 2026-08-26"); ACCEPTED_DEVIATIONS: "BUT-2082 and BUT-1955 — …" |
| 10 | 2026-08-29 | BUT-1971 | Group weekly menu | Other members' per-dish provenance (`proposedBy`, `votedInBy`) | — | Malin | ACCEPTED_DEVIATIONS, BUT-1971: "Art. 15, group weekly menu: other members' per-dish provenance is KEPT" |
| 11 | 2026-08-29 | BUT-1971, ADR-0010 | Group weekly menu edit trail | Rows where the requester is the actor or the subject | Every other row of the edit trail | Malin | ACCEPTED_DEVIATIONS, BUT-1971: "the edit trail is FILTERED …"; `docs/org/adr/ADR-0010-edit-trail-is-not-an-audit-row.md` |
| 12 | 2026-09-17 | BUT-1971, ADR-0021 | Group weekly menu | — | `contributorUserIds` | Malin (she first chose keep, then reversed it) | `docs/org/adr/ADR-0021-the-erasure-handle-stays-out-of-the-bundle.md`; ACCEPTED_DEVIATIONS: "Art. 15 — the four open withholding questions, answered", row 2 |
| 13 | 2026-09-05 | BUT-2018, BUT-2056 | Blocks | — | Who has blocked the requester: no uids, no count. The section's note reads the same whatever the answer (BUT-2056, Malin, 2026-09-09) | Malin | ACCEPTED_DEVIATIONS, BUT-2018 ("count (BUT-2018, 2026-09-05)") and BUT-2056 ("A `data_minimisation` note that carries a THIRD PARTY's fact is byte-invariant") |
| 14 | 2026-09-07, 2026-09-17 | BUT-2028 | `ingredient_suggestions` | — | The moderator's uid (`reviewedBy`) and internal moderation text (`reviewNotes`) | Default, then Malin | ACCEPTED_DEVIATIONS, BUT-2028; "Art. 15 — the four open withholding questions, answered", row 3 |
| 15 | 2026-09-08 | BUT-2046, ADR-0017 | Moderation counters (`user_moderation`) | — | The reporters' identities. The requester's own `totalReports` / `lastReportedAt` ARE exported: withholding a subject's own data would need an Art. 23 measure, and none was found | Malin (she reversed a same-day call to withhold the count too) | `docs/org/adr/ADR-0017-withholding-a-subjects-own-moderation-count.md`; ACCEPTED_DEVIATIONS, BUT-2046 |
| 16 | 2026-09-10 | BUT-1957 | `delivered_notifications` | Another user's name inside the text of a friend-share push the requester received | — | Malin | ACCEPTED_DEVIATIONS, BUT-1957: "The Art. 15 `delivered_notifications` section exports another user's NAME …" |
| 17 | 2026-09-10 | BUT-2062, BUT-2082 | Comments and ratings | `recipe_title`, as the requester can read it today (BUT-2082, 2026-10-09) | `recipeOwnerId`, `sharedWithUserIds`, and the `reactions` map (who reacted with what) | Review panel; Malin confirmed the uid half in BUT-2414 (row 22) | ACCEPTED_DEVIATIONS, BUT-2062: "The Art. 15 comments and ratings sections are PROJECTED …"; "BUT-2082 and BUT-1955 — …" |
| 18 | 2026-09-30 | BUT-2151, ADR-0023 | Live collaboration (`realtime_resources`) | Other participants' uids | Other participants' display names | Malin | `docs/org/adr/ADR-0023-live-collaboration-collection-and-export-names.md` |
| 19 | 2026-10-07, 2026-11-11 | BUT-2169 | `shared_*_received` | — | `blockHeldUserIds` and `blockHeld` (which two people a block stands between), not named in the section's note; a held person's bundle lacks the held rows until unblock | Shipped as a default; Malin kept it 2026-11-11 | ACCEPTED_DEVIATIONS: "BUT-2169 — a block hides one-off shares in both directions (2026-10-07)"; "BUT-1805 and BUT-2169 — Malin's two export decisions (2026-11-11)" |
| 20 | 2026-10-08 | BUT-1747 | `shared_lists_left` | On rows naming the requester: the requester's and the list owner's uids | Every other person's uid on those rows; rows that do not name the requester | Malin | ACCEPTED_DEVIATIONS: "BUT-1747 — lists the requester LEFT, and `shared_content` items, in the Art. 15 bundle (2026-10-07)" |
| 21 | 2026-10-09 | BUT-1842 | Moderation counters | — | The server's text copy of reported content (`report_evidence`), since together with the report it can identify the reporter | Malin | ACCEPTED_DEVIATIONS: "BUT-1842 — a report keeps a text copy of what it names (2026-10-09)" |
| 22 | 2026-10-20 | BUT-2414 | Erasure residue (`others_documents` known gap) | — | Where the requester's uid sits on other people's documents (`recipeOwnerId`, `sharedWithUserIds`, a recipe's `memberPermissions` key): not the rows, not a count | Malin ("Inte alls") | ACCEPTED_DEVIATIONS: "BUT-2414 — Malin's three export choices (2026-10-20)" |
| 23 | 2026-10-20 | BUT-2414, ADR-0030 | Household (diner profiles, family ratings) | Creator: every diner profile. Joiner: profiles they entered. Sole remaining member: every profile and rating, departed members' uids as stored | A group-link owner with joiners left does not get the joiners' own verdicts | Malin ("Behåll koden"); the owner case by the panel's priority order (ADR-0030) | `docs/org/adr/ADR-0030-a-group-owners-export-leaves-out-the-joiners-verdicts.md`; same BUT-2414 section |
| 24 | 2026-11-11 | BUT-1805 | Audit logs (`removed_from_groups`) | The fact and time of the requester's removal from a group by an admin, and the group id | Which admin removed them (`userId`, `metadata.actor`). In a group with one admin the requester can still infer it | Malin | ACCEPTED_DEVIATIONS: "BUT-1805 and BUT-2169 — Malin's two export decisions (2026-11-11)"; "BUT-1805 — the admin-removal audit row (2026-10-09)" |

## Superseded

- **BUT-1716 (2026-09-12)** — `shared_content/{id}/items` attribution "erasable, not exportable".
  Replaced by row 20 (BUT-1747), which exports the rows naming the requester.
- **BUT-1718 (2026-09-12)**, and the BUT-1732 "Known gap" — a list the requester left was not in
  the export. Replaced by row 20.
- **BUT-1805 (2026-10-09)** — the admin-removal audit row was in the admin's export only, with
  no recorded balancing. Replaced by row 24.
- **ADR-0017's original call (2026-09-08)** — withhold the moderation count too. Reversed the
  same day; row 15 is the current outcome.

## Export decisions that are not about other people

Reviewed for this register and left out of the table, because each one concerns the requester's
own data, an anti-abuse exemption, or the bundle's form rather than a third party: BUT-2413 and
BUT-1832 (own poll votes), BUT-2040 and ADR-0020 (rate-limit exemption), BUT-2138
(`system_rate_limits`), BUT-1981 (the bundle no longer names Article 30), BUT-1693 (a failed
audit write), BUT-2106 (rating review text), BUT-1850 (a removed section), BUT-2112, BUT-2114,
BUT-2115, BUT-2318 and BUT-2398 (own likes and reactions), BUT-2330 (the moderation decision
record; an emailed request is answered from it), ADR-0038 (AI samples), and BUT-2414's
`storage_files`.

## Keeping this register current

A new or superseding accepted-deviation line about the Art. 15 export gets its ticket id here in
the same change: a row when it decides what the bundle says about someone else, otherwise the
list above. `test/architecture/article_15_4_register_test.dart` fails when a line in
`.claude/rules/accepted-deviations.md` that mentions the export carries no id listed here.
