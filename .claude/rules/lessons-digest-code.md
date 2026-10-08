---
paths:
  - "lib/**"
  - "functions/**"
  - "firestore.rules"
  - "firestore.indexes.json"
  - "scripts/**"
  - "tools/**"
---

# Lessons Digest — code and Firebase

Lessons that only bind while writing app, Cloud Functions or Firestore code. Counted by the
same drift tripwire as the core digest (`knowledge.digestFiles`).

- An ARB edit rewrites the WHOLE file … compare KEY SETS against `git show HEAD:<file>` as JSON before staging any shared generated file (BUT-1783)
- A deploy that DELETES many Cloud Run services … verify per-function `state` from `--json` after any deploy that removes services (2026-08-03)
- A model field that reaches Firestore is a RULES change too — `hasOnly` fails CLOSED in silence. (BUT-1482)
- A rules block that ATTESTS on a parent document must first establish WHERE and WHEN that parent is written (2026-08-12)
- Dart RegExp `\b` is ASCII-only — bound Swedish tokens with explicit lookarounds
- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index
- A FAILED_PRECONDITION's `create_composite` token base64url-decodes to Firestore's OWN index spec
- Ett värde som fångas för en identitet och läses över ett auth-byte nycklas till identiteten (e-post/uid), aldrig rensas på händelser — och en kapplöpningsrättelse är oprövad tills den körts i riktiga appen (2026-10-05)
- A wrong-path Firestore read is a bug CLASS … Grep the CONSTANT for every reader AND writer (BUT-1724)
- A rule bounding a field's VALUE does not bound a denormalised COPY of it on another collection (BUT-1903)
- Before designing a new attribution field's STORAGE or its erasure, grep every construction site of the thing it attributes (BUT-1832, BUT-1971, 2026-08-30)
- A chunked migration walks by OFFSET; "re-read and ask what is left" is a DIFFERENT algorithm that looks identical (BUT-2046, 2026-09-08)
- Ett NYTT FÄLT på en samling motbevisar daterade UPPRÄKNINGAR av samlingens form i ORÖRDA filer (BUT-2057, 2026-09-11)
- Läs läsarens schema och fönster och grepa VARJE annan läsare av samlingen innan du ansluter (BUT-1952, 2026-09-11)
- En BREDDAD returtyp är oprövad tills den svit som kör den KOMPONERANDE raden finns (BUT-1925, BUT-2027, 2026-09-12)
