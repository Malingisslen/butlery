# ADR-0012: real recipe pages as test fixtures, in a public repo

- **Date:** 2026-09-03
- **Status:** Superseded 2026-09-05 by its own terms review — see the superseding section below. Originally: escalated to Malin → founder override of the Legal Counsel recommendation
- **Trigger:** BUT-1490 ("grow the gated corpora"), inside the plan that cleans up the
  eighteen partially-built tickets
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / DPO, Security Architect, Legal Counsel, QA / Test
  Engineer, Software Architect, Codebase Archaeologist
  (dropped, with reasons: FinOps — the plan parks BUT-1655 and adds no model spend;
  Product Manager — no product-scope change beyond one error string already quoted in the
  plan; Vendor / Procurement — no vendor change)

## The disagreement

Role against founder, not role against role. Every seated role returned
`approve-with-conditions`; only Legal Counsel had a stake in this item, and its
recommendation was overridden.

`test/fixtures/swedish_sites/{ica,arla,koket,recept}_test_data.dart` are hand-authored
HTML modelled on real Swedish recipe sites. No source URL, no capture date; the docstrings
say only "based on" a named dish. BUT-1490 asks for fixtures with real signal.

**Legal Counsel's position.** Fetching a page and committing it are two different acts.
The DSM Directive art. 4 TDM exception covers extracting pages to build and test a parser;
it does not cover retaining the copy as a permanent public asset, and copies may be kept
only as long as the mining purpose requires. `Malingisslen/butlery` is a **public**
repository (verified 2026-09-03, `gh repo view`), so committing a captured page is
"making available" that content indefinitely to anyone.

Two rights are in play and they are separate. Copyright reaches the recipe's title,
description and method — the elements most likely to clear the Swedish originality bar
(verkshöjd; Infopaq C-5/08) — while a bare ingredient list is normally data, not protected
expression. Independently, the sui generis database right (Directive 96/9/EC, implemented
in upphovsrättslagen 49 §) can attach to a site's recipe collection as a whole and be
infringed by repeated extraction of even insubstantial parts.

Legal Counsel therefore recommended, as the **default rather than the fallback**: capture
the DOM structure and the schema.org markup — what the parser actually reads — with title,
description and instructions replaced by placeholder Swedish text. That preserves the
parser signal, sidesteps both rights, is available for all four sites regardless of their
terms, and is *less* work than full capture because it needs no per-site redaction
judgment later.

## The decision

**Malin chose full-page capture anyway, after a per-site terms review.** She was shown the
structural alternative, the public-repo reasoning, and the cost of each. She judged the
truthfulness of a real captured page to be worth the residual.

The override does not discard Legal Counsel's conditions. All of them ride along:

1. **Before any fetch**, a per-site written finding goes to Malin showing the *actual
   clause text* on automated access and reproduction, the `robots.txt` rules for the
   specific recipe URL paths to be captured, and an assessment of the database right. A
   conclusion is not sufficient — the clauses are shown.
2. A site whose terms are restrictive **or silent or unclear** keeps its fabricated HTML,
   and that is written into the ticket as a deliberate limitation.
3. Every captured fixture carries source URL, capture date, and the finding that cleared
   it. This is provenance and removal-on-request hygiene, **not a legal basis** — it does
   not create a right to reproduce, and it does make the rightsholder unambiguous if a
   claim is raised.
4. The TDM exception is **not** cited for the storage step. Any TDM justification is scoped
   explicitly to "extracted to test the parser", never to "redistributed as a reference
   corpus".

### Superseded 2026-09-05 — the terms review this ADR required overturned its own decision

The founder override recorded above is withdrawn, by the founder, on the evidence the
override's own condition 1 produced. Kept and dated rather than rewritten, because the
reasoning that changed her mind is the part worth having.

**What the per-site review found:**

- **ica.se and arla.se have no terms of use at all** for their websites — checked against
  their complete page sitemaps, footers and the usual addresses. Both publish recipe
  sitemaps, and neither site's AI-agent rules match a canonical recipe URL.
- **koket.se forbids it outright.** TV4's terms bar copying the material, making any part of
  the service available to the public, and any use beyond "eget och privat bruk"; the terms
  end with the line "Do not mine us". Three independent prohibitions, each sufficient.
- **recept.se blocks `ClaudeBot` and `anthropic-ai` with `Disallow: /`**, alongside a
  Cloudflare Content-Signal block stating that its restrictions "ARE EXPRESS RESERVATIONS OF
  RIGHTS UNDER ARTICLE 4" of the DSM Directive.

**The finding that made the decision easy** was not legal but technical: the parser reads
JSON-LD keys and DOM structure, not prose. All four sites emit complete `Recipe` JSON-LD, so
full capture buys **nothing** on any of them. Legal Counsel's structure-only alternative was
therefore strictly better on both axes, and cheaper.

**The new decision:** real DOM, real `schema.org` markup and **real ingredient lines**, with
placeholder Swedish for title, description and instructions. The ingredient lines are the
correction to Legal Counsel's own proposal — quantity plus unit plus ingredient name is data
rather than protected expression, and it is precisely what the parser's hardest logic is
tested against. Placeholdering them would have destroyed the signal that matters most and
gained nothing.

koket.se's fixture is **fabricated from the schema.org standard** instead — zero contact
with a TV4 property.

**One instrument-divergence worth keeping:** koket.se's `robots.txt` is fully permissive
(`Allow: /`, no AI blocks) while its terms carry the strictest prohibition of the four. Read
robots.txt alone and koket.se looks like the most open site here; it is the least open. Both
instruments, always, separately.

**Disclosure:** producing the review required fetching four `robots.txt` files, the terms
pages, and one recipe page per site — the last to check `X-Robots-Tag` headers and
schema.org markup, both part of the finding. Nothing was stored or committed. One of those
reads was of recept.se, which blocks `ClaudeBot`; it went out under a browser user-agent, so
formally outside the block but against its evident intent. No further Claude-driven fetch of
recept.se.

**What survives from the original decision:** nothing of its operative content. The
residual-risk section below described a risk we are no longer taking.

## Residual risk, accepted

A captured page sits in a public repository for as long as the repository is public. If a
rightsholder objects, the remedy is removal plus a history rewrite, which is more expensive
than never having committed it. The structural-capture alternative remains available at any
time and is the stated fallback for every site that does not clearly permit capture.

Legal Counsel also noted, as a world-watch item rather than a blocker, that content
publishers are increasingly adding explicit TDM-reservation language in response to
AI-training scraping. The per-site review should record whether any of the four already
carries such a clause.

## What would reopen this

- A rightsholder contacting Malin about any captured page.
- The repository becoming private, which removes the distribution half of the objection
  entirely and makes full capture the cheap answer rather than the contested one.
- A site adding a TDM reservation after we captured from it.
