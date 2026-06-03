# Sprint Backlog

## Active: BUT-581 — `?? ''` → `.orEmpty()` migration (multi-chunk) — 2026-06-03

The sweep is COMPLETE (chunks 1–8: models, repositories, viewmodels+core, widgets, views,
services ×3). ~185/226 sites converted to `.orEmpty()`; ~41 legitimate `?? ''` remain — all
un-convertible (Firestore `data['k']`/`dynamic` receivers + chained `a ?? b ?? ''`) plus 3
inside the extension-definition file itself.

### Final step (next iteration)
- [ ] **Architecture-test guard** banning NEW `?? ''` in `lib/` — allowlist the ~41 legitimate
      dynamic/chained sites (migrate-then-guard pattern, like the BUT-885 CircularProgressIndicator
      guard). Then close BUT-581 → Done.

### Codemod gotchas (documented for the guard + future work)
- Skip `dynamic`-typed receivers — `.orEmpty()` on `dynamic` throws NoSuchMethodError at runtime
  (extensions are static-dispatch). Firestore `data()['k']` is the common trap.
- Precedence: `a?.b ?? ''` → `(a?.b).orEmpty()` (parenthesize the whole chain).
- Skip chained `a ?? b ?? ''`.
- `default_value_extensions.firstOrNull`/`lastOrNull` collide with `package:collection` (analyze flags it).

---

## Awaiting Malin (loop can't do these — need prod/console access)
- **BUT-1187** (Urgent): `firebase deploy --only functions` — recipe-import LLM is 404ing in prod
  until the gemini-2.5-flash-lite migration is deployed.
- **BUT-1049**: `firebase deploy --only firestore:rules,storage` — activates comment images.
- **In Review** (your sign-off): BUT-1185 (tag multi-select UI), BUT-1049 (comment images), BUT-1187.
- **BUT-1169** (Tier-D): legacy shopping-doc backfill — needs prod telemetry + a Cloud Function.

## Shipped this `/loop` session (all green on main)
Tagging cluster (BUT-1042/1185/1186/1188), comment-images (BUT-1049/1189), GDPR-deletion
coverage (BUT-1009/1191), the BUT-1187 prod-model fix, a de-flaked menu_service test, 2 lessons,
and BUT-581 chunks 1–8. Follow-ups filed: BUT-1185/86/87/88/89/90/91. Obsolete: BUT-995/1032.
