# Lessons Digest — core (auto-loaded)

One line per lesson in `tasks/lessons.md`; the full entries there are the deep reference. The long form each line had before 2026-09-19 is in `tasks/archive/lessons-digest-long-form.md`.
**Sync contract (CLAUDE.md rule #9):** every new lesson gets its one-liner in the same edit.
A Stop-hook tripwire counts the lines across all digest files and warns when they drift.

Routing — put a new line in the file that matches when it is needed:
`lessons-digest.md` (here) for anything that binds any session; `lessons-digest-delivery.md`
for sprint, Linear, worktree and ship-pipeline lessons; `lessons-digest-testing.md` for
lessons that only matter while writing or running tests.

## Workflow

<!-- The four commit-retry lessons live in the commit gate's own block message
     (workflow-guards/require-review-before-commit.mjs, 2026-08-17), which fires at the
     moment they bite. Do not re-add them here — no digest trigger detects "is committing",
     so you would pay for them every session and still not hold them at the retry. -->

- An audit agent's claim about a tool's OUTPUT FORMAT is a guess until reproduced — run the real tool
- Feedback right after a deliverable may target the TOOL/process, not the one artifact
- A multi-part agreed initiative gets ONE written plan before any slice ships — chat scrollback is not a backlog.
- Every proposed improvement must name its mechanical trigger; upgrading an optional command is convenience, not infrastructure.
- Never prune a young system for inactivity — the observation window must exceed its natural cycle
- Don't hand the user judgment/labor you can derive yourself; defer only product intent, irreversible actions, or external facts. ([Workflow], 2026-06-09)
- Bash `cd` persists across calls — use absolute paths.
- A 403 naming a permission can be a WRONG-IDENTIFIER bug, not a credentials bug
- A hook on a RELATIVE path stops firing once Bash cwd drifts into a subdirectory
- Verify Edits actually landed (`git diff`) before committing — never trust the commit-message claim.
- A multi-edit script that asserts before its single write loses EVERY edit when one search string is wrong
- "Unreferenced" must be proven against the WHOLE repo, never a hand-picked subset.
- When the user asks for a new mode, deliver ONE mode — no "normal + extra", no spare variants.
- "Map the workflows" means full coverage against a stated universe — never silently curate a sample.
- When citing a deterministic tool's verdict (router tier, gate, test), RUN it and paste output — never assert what it would say.
- A subagent naming a file as "the X path" proves existence, not routing ([Workflow], 2026-07-02)
- `curl` is a DIFFERENT CLIENT from the app — its 403/empty page is not your feature failing. (2026-08-01)
- A blocked gate is a STOP, not a puzzle to route around — never forge a marker
- A new source file can land as a git binary blob — verify `file` says "text" before committing.
- A registry/structural lint that reddens on a given day is usually pointing at that day's DELETION commit, not at itself
- "It's the tooling, not the app" is a CLAIM, not a default — name the mechanism and show the measurement before writing it. (BUT-1837)
- Adding a CALLER changes the callee, even untouched … Check a callee's logs, bounds and errors against the NEW caller's inputs (BUT-1822)
- An ARB edit rewrites the WHOLE file … compare KEY SETS against `git show HEAD:<file>` as JSON before staging any shared generated file (BUT-1783)
- A subagent's transcript file is NOT a liveness signal … only the completion notification proves an agent finished
- Anything you WRITE about code is an UNTESTED ASSERTION with a half-life … State the RULE, never the current mechanism (BUT-1786, BUT-1418)
- A deploy that DELETES many Cloud Run services … verify per-function `state` from `--json` after any deploy that removes services (2026-08-03)
- "I read very little of what you reply" is a CONFIG bug first — grep the always-on setup
- A verifier's RED COUNT fingerprints the bytes it READ … revert the fix and check whether the claimed signature reproduces exactly
- A model field that reaches Firestore is a RULES change too — `hasOnly` fails CLOSED in silence. (BUT-1482)
- A rules block that ATTESTS on a parent document must first establish WHERE and WHEN that parent is written (2026-08-12)
- "Not a live bug" is a claim about CALLERS, not about a nullable fallback … Trace UP from the WRITE (BUT-1849)
- A source edit made THROUGH another language inherits ITS escape rules … Write `chr(92)+'b'`. (BUT-1901, 2026-08-19)
- A hand-graded set is shaped by the SCREEN that fed it candidates — ask what that screen could not see (BUT-1847)
- Python and Git Bash resolve `/tmp` to DIFFERENT dirs on Windows … Compare sets in ONE language, strip CR, `mktemp -d`. (2026-08-17)
- A ticket's stated harm can be REFUTED, not merely stale — trace the MECHANISM it cites (BUT-1883)
- A shape-based redaction fails in BOTH directions and needs a test each way (BUT-1897)
- Every NUMBER, comparative ("most/every/only"), causal "because" and provenance DATE in a comment must be MEASURED before it is written ([Workflow], 2026-08-20)
- Moving a rule into a SHARED place raises three cross-file questions no single-file reviewer can answer … Run a whole-diff pass ([Workflow], 2026-08-20)
- A check run correctly against the WRONG OBJECT is indistinguishable from a clean bill of health (BUT-1921, 2026-08-26)
- A repo RULE file is an untested assertion too … Assert against the artefact (`tester.getSemantics`), correct the rule (BUT-1904)
- A comment explaining WHY a test or guard is shaped as it is asserts what it CATCHES … Write such a clause only after mutation-probing what it describes (BUT-1929, 2026-08-27)
- A pipeline that has NEVER run hides every fault at once and fails serially — check `gh run list` before calling a failure a regression (BUT-1904)
- `git status` codes and `git diff` are the INDEX's cached view, not a measurement (BUT-1951, 2026-09-05)
- A correction is written in the state least suited to writing one … sweep the PREMISE, not the phrase (BUT-2028, 2026-09-06)
- The text written to REPLACE a struck claim is where it comes back … after striking a rule, re-read its replacement against the measurement (BUT-2037, BUT-2020, 2026-09-06)
- Commit-grindarna är PARALLELLA AGENTER i samma träd, och två av dem skriver … kör den ensam eller sist (2026-09-07)
- En handskriven raderingslista mot en UPPRÄKNANDE sond gör en död namnändring till permanent `gdprCompliant: false` (BUT-2040, 2026-09-08)
- En buggklass ingen kod kan hitta (en död namnändring har inga skrivare) stängs genom att lägga jämförelsen i VERKTYGET, inte i en rutin (BUT-2043, 2026-09-08)
- En vakt kan vara bredare än sin raderare genom TIMING … Fråga alltid var raderaren körs i förhållande till sonden. (BUT-2044, 2026-09-08)
- En rättelse på en grinds fynd är den redigering som oftast blir kvar OSTAGAD … Staga i ett EGET anrop direkt efter varje rättelse (BUT-2016, 2026-09-10)
- En prissättning som går till Malin har högre bevisbörda än en kodkommentar … Mät varje prisuppgift i koden samma dag som frågan ställs, aldrig ur en post (BUT-1917, BUT-2018, 2026-09-09)
- En hårdkodad REGION (eller bucket, plats, prefix) är en handlista ett steg upp … Uppräkna dimensionen som avgör VAR man letar (BUT-2036, 2026-09-10)
- Ett ärendes ord för felet är inte en enum … Mät vilket status den verkliga populationen producerar innan fixen designas kring ett (BUT-2076, 2026-09-11)
- En mening vars HUVUD du redigerar ÅTERUTGER sin svans som ditt påstående … Kör `git show HEAD:<fil>` på den överlevande meningen efter varje strykning (ADR-002, BUT-1718, 2026-09-12)
- En skärpt regel är bara så sann som skrivar-inventeringen: räkna upp skrivare via SKRIVVERBEN i varje fil som nämner samlingen (ADR-0020, 2026-09-14)
- En sanerare som PRÖVAR en sträng och SPARAR en annan har ett hål i avståndet … kör kontrollen på det RETURNERADE värdet efter varje omskrivning (BUT-1819, 2026-09-15)
- Commit-gate coverage is recorded PER RUN with the verdict that run ended on … budget ONE full-file-list pass per gate ending on a pass verdict (BUT-1693, 2026-09-16)
- A JUSTIFICATION is a claim about the code path you did NOT open … open Y's source before the sentence exists (BUT-1954, 2026-09-16)

## UI/UX

- Anchor every "what this product IS" sentence in the doc/code on EVERY run, never in the prior episode ([Workflow], 2026-08-25)
- Heuristic/LLM-derived visible content (headings, tags, parsed amounts) ships WITH its correction UI in the MVP

## Language and Firebase gotchas

- Dart RegExp `\b` is ASCII-only — bound Swedish tokens with explicit lookarounds
- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index
- A FAILED_PRECONDITION's `create_composite` token base64url-decodes to Firestore's OWN index spec
- A boundary/heuristic/attribution bug usually has a TWIN CLASS — grep sibling classes by NAME (not path) (BUT-1691, BUT-1697)
- A harness picking between two on-disk shapes for the same fact must choose on the property that decides TRUTH (2026-08-05, [Workflow])
- A wrong-path Firestore read is a bug CLASS … Grep the CONSTANT for every reader AND writer (BUT-1724)
- "Affected users" is a CLAIM WITH A TIMESTAMP … Date the window at both ends and check live status before any sentence about who is affected (BUT-1846)
- A rule bounding a field's VALUE does not bound a denormalised COPY of it on another collection (BUT-1903)
- A claim can be true per verb, caller, purpose or fixture and false universally (BUT-1838)
- A config artefact in the wrong SHAPE is dead SILENTLY and forever … Existence is not liveness (2026-08-22)
- Read the first three lines of any config/data file before editing it … Fix the SOURCE, re-run the generator ([Workflow], 2026-08-22)
- A guard that stops a bulk sync undoing one kind of human decision is evidence you saw the hazard … Name both directions in the same edit (BUT-1856)
- Strike the numeral instead of re-counting, sweep the WHOLE file (BUT-1856)
- A count that describes a file you are still editing cannot be TYPED … Recompute it from `wc -l` in the SAME call that stages and commits (BUT-1911)
- A CLI's output format is a PLATFORM variable … Reproduce a tool's output on the TARGET platform before parsing it (BUT-1894)
- The paragraph written to BE the correction is where the next false sentences land … Close the gap rather than scope the sentence (BUT-1961, 2026-08-27)
- Never end a reply with a future action in the PRESENT tense — the turn terminates on that sentence and nothing runs. (2026-08-29)
- Before designing a new attribution field's STORAGE or its erasure, grep every construction site of the thing it attributes (BUT-1832, BUT-1971, 2026-08-30)
- A gate reviewing a staged diff must see a FROZEN index … Batch fixes, re-stage once, re-brief (BUT-1957, 2026-09-02)
- A correction is written in the state of mind least suited to writing one … Strike rather than reword (BUT-1957, 2026-09-02)
- A refuted claim has SIBLINGS, and one of them is text you wrote minutes ago … Sweep the CONCEPT (BUT-1922, 2026-09-05)
- Commit-gate ledger coverage is recorded by the `Read` TOOL alone … Tell every gate reviewer to open each file with `Read` (BUT-1922, 2026-09-05)
- The word "Measured" plus a date is a claim about an experiment you can NAME (BUT-1917, 2026-09-05)
- An untested PROMISE and a kept promise are the same artefact … REPAIRING what made a claim untestable is what makes the claim false (BUT-2010, 2026-09-05)
- A correction can contradict the sentence it was written to SAVE … After fixing a sentence, re-read the neighbouring claim the fix was defending. (BUT-2028, 2026-09-07)
- Commit-gate review coverage is keyed on BYTES … Batch every fix, re-stage ONCE, then resume the SAME agent with exactly what changed (BUT-2032, 2026-09-08)
- A chunked migration walks by OFFSET; "re-read and ask what is left" is a DIFFERENT algorithm that looks identical (BUT-2046, 2026-09-08)
- En delta till en ÅTERUPPTAGEN granskare räknas från mottagarens senaste läsning, inte från ditt senaste meddelande (BUT-2046, 2026-09-09)
- En STRYKNING kan göra en mening falsk genom att ta bort satsen som avgränsade den … Läs den ÖVERLEVANDE meningen ensam efter varje strykning (BUT-1943, BUT-2025, BUT-2015, 2026-09-09)
- Att KOPPLA UR ett anrop faller hjälparens EGNA dokument … grepa HJÄLPARENS fil, inte bara anroparen (BUT-2060, BUT-2005, 2026-09-10)
- En GRANSKARE SOM HÅLLER MED är inte en mätning … fråga vad vakten dyrast MÖTER, inte vad den snabbast avvisar (BUT-2037, BUT-2034, 2026-09-10)
- En HÄNGD granskningsagent ser exakt ut som en tänkande, och `running` säger ingenting (BUT-2068, BUT-2022, 2026-09-10)
- En STRYKNING som lägger till text är inte en strykning … Andra underkännandet av en mening = radera satsen (BUT-2062, BUT-2067, 2026-09-10)
- Ett NYTT FÄLT på en samling motbevisar daterade UPPRÄKNINGAR av samlingens form i ORÖRDA filer (BUT-2057, 2026-09-11)
- Ett storleksanspråk gömmer sig i GRAMMATIKEN efter att räkneordet strukits … Stryk räkneordet OCH anaforen som ärver det i samma redigering (BUT-1716, 2026-09-12)
- Läs läsarens schema och fönster och grepa VARJE annan läsare av samlingen innan du ansluter (BUT-1952, 2026-09-11)
- En BREDDAD returtyp är oprövad tills den svit som kör den KOMPONERANDE raden finns (BUT-1925, BUT-2027, 2026-09-12)

- Ett API-svars ORDNING är ett påstående, inte en garanti … en artefakt som SKRIVS OM av sin egen automatik kan inte dateras av `createdAt` (2026-08-28, 2026-09-17)
- En mening i en användarvänd JURIDISK artefakt om vad som HÄNDER MED DATA är ett påstående om en SKRIVARE, aldrig om en avvikelsepost (BUT-1838, 2026-09-17, [Workflow])
- Ett muteringsprov över HELA testfilen krediterar rött till fel påstående — skopa till det enda testet och skriv ut den fallande raden; ett prov på EN variant bevisar ingen klass, och en granskare som håller med är inte en mätning (BUT-1899, 2026-09-20)
- En "är detta aktuellt?"-fråga mäts först mot ärendets EGEN historik (`git log --all --grep=<ID>` + grep på ID:t), sedan mot koden — ett beslut kan vara fattat i ett annat ärendes ändring utan att statusfältet ändrats (BUT-2094, 2026-09-20)
- En granskares VERDIKTRAD registreras separat från dess läsningar och bara om inget står efter den — kräv den som sista raden och verifiera i liggaren, inte i rapporten (2026-09-20)
