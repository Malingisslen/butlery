# firebase-backend-security — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every security/backend task and **APPEND** to it when
it discovers a new pattern, settles a GDPR question, or is corrected by the
user.

## How to update this file

- **Append-only** — never delete entries; supersede with a newer dated entry.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **One concept per entry** — easier to supersede later.

---

## Repository layer contract

**Every repository in `lib/repositories/` MUST use `PermissionValidationMixin`.**
This is non-negotiable — it's CLAUDE.md rule #3 and the foundation of the
authorization story. If you find a repository that doesn't use it, that is
a Critical-severity finding.

**Service access**: code uses `ServiceLocator.get<T>()` (in widgets/VMs) or
constructor injection (in DI modules). Never `FirebaseFirestore.instance`
directly — inject `FirestoreRepository`.

**DI registration**: `FirebaseRecipeRepository` is registered as the
`RecipeRepository` interface. Use the interface for `ServiceLocator.get`.

## Data-source rules (CLAUDE.md)

| Need | Use |
|---|---|
| Complete user data (settings, avatar, social) | `userService.currentUserProfile` |
| Auth/permission checks only | `permissionService.currentUserId` |

Never mix these — the bug pattern is "settings don't persist" because the
write went through the auth-only handle and the cache wasn't refreshed.

## Firestore rules pairing

`firestore.rules` (~72KB) MUST match repository permissions. When repository
code adds/removes a permission check, the matching rule branch must change
in lockstep. If they drift, either the rule is too permissive (security
hole) or the rule is too strict (rules-reject breaks the app).

The `firestore-rules-tester` agent owns proving rule behavior. Hand off to
it after rule changes — don't write rules tests yourself.

## Cost principles (CLAUDE.md)

- Avoid unnecessary Firebase reads/writes.
- Batch operations (Firestore batch limit: **500 ops per batch**;
  consolidated updates = 1 op per doc).
- Cache aggressively; use efficient queries with indexes.
- Prefer deterministic logic over LLM calls. LLMs only when truly needed
  (free-text, creative generation).

## GDPR compliance baseline

Required for every user-data-touching feature:

- [ ] User consent before data collection
- [ ] Data minimization (only what's needed)
- [ ] Right to access (user can retrieve their data)
- [ ] Right to deletion (cascading where the data lives in subtrees)
- [ ] Right to rectification (user can update)
- [ ] Data portability (export functionality)
- [ ] Privacy policy linked from any consent surface

Critical finding if any of these is missing for a new user-data feature.

## Security best practices

- Input validation and sanitization on every write boundary.
- Error handling must NOT leak sensitive data (no raw Firestore error
  messages to the user).
- Audit logging for security-critical operations (rule grants, role
  changes, deletions).
- No exposed API keys or credentials — `.env` is gitignored; check
  `.env.example` matches the shape but contains no secrets.
- HTTPS-only, encryption at rest where applicable.

## Performance & query optimization

- Compound queries require composite indexes — confirm in
  `firestore.indexes.json` before merging.
- `where()` clauses: indexed fields first.
- Always `limit()` results that could grow large.
- No "read entire collection" queries on user-facing paths.
- Use subcollections for scalable per-user data.

## Real-time listener hygiene

- StreamBuilder/StreamProvider patterns; never raw `onSnapshot` in widgets.
- Listeners attached in `initState`/ViewModel `init`.
- Listeners disposed in `dispose()` — leak finder catches violations.
- Stream errors handled (don't let an unhandled stream crash the UI).

## Severity tagging for findings

- **Critical** — security vulnerability, GDPR violation, data-loss risk,
  memory leak.
- **High** — missing permission check, missing index for a deployed query,
  performance issue at scale.
- **Medium** — optimization opportunity, incomplete validation.
- **Low** — code organization, documentation.

Always include specific code examples and remediation steps.

---

## Discovered patterns

*Append new dated entries below as the agent learns them.*

### 2026-04-25 — initial seed
Knowledge file seeded from CLAUDE.md (rules #3, data-source enforcer, cost
principles), the existing agent description, and `MEMORY.md` gotchas
(Firestore batch limit). Future entries should record genuinely new
permission patterns, GDPR decisions, query patterns, or surprising
Firestore/Firebase behavior — not re-derivations of what's already here.
