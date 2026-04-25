---
name: permission-audit
description: Audit lib/repositories/ for PermissionValidationMixin compliance. For each repository class, verifies (a) the mixin is applied via 'with PermissionValidationMixin', and (b) every public, non-getter method body invokes at least one validate* call from the mixin (validateOwnership, validateWritePermission, validateSelfOperation, validateRequiredFields, hasReadAccess, getDocumentWithPermissionCheck). Outputs a markdown report at tasks/permission-audit-<YYYY-MM-DD>.md grouped by severity.
disable-model-invocation: true
---

# /permission-audit — Repository permission compliance sweep

## Why this is user-only

It's a quarterly diagnostic, not a continuous behavior. Run when:
- After a refactor that touched many repository files
- Before a security review or release
- Quarterly maintenance

`firebase-backend-security` reviews diffs as they happen — this skill does
the **static sweep across the whole repo layer** that no diff-time review
would catch (drift in pre-existing files, files that predate the rule).

## What it produces

A markdown report at `tasks/permission-audit-<YYYY-MM-DD>.md` with three
sections, ordered by blast radius:

1. **Critical — repositories without the mixin** — entire classes that
   bypass the security layer. Highest priority fix.
2. **High — public methods missing a validate\* call** — partial coverage:
   the mixin is wired up but specific methods don't appear to use it.
3. **Review — uncertain matches** — methods where static analysis can't
   tell (forwarder calls, runtime-resolved permission checks, etc.).
   Manual eyes needed.

## Workflow

### 1. Enumerate repository files

```bash
find lib/repositories -name "*.dart" -not -name "*.g.dart" \
  -not -name "*_test.dart" -not -name "*.freezed.dart"
```

Skip:
- `lib/repositories/mixins/` (the mixin itself, plus other mixins)
- Generated files (`.g.dart`, `.freezed.dart`)
- Abstract interfaces (no implementation to audit)

### 2. Parse each file

For each file, extract:

- **Class declarations** (`class Foo extends Bar with X, Y, Z implements I`).
- **Whether `PermissionValidationMixin` appears in the `with` clause** (or
  any superclass — note the inheritance chain when relevant).
- **Public method bodies** — defined as: starts with a non-underscore
  identifier, has a parameter list, has a body block. Skip:
  - Constructors
  - Getters (`Foo get bar => ...`)
  - Forwarders (`void method(...) => other.method(...);`) — body is a
    single expression, no logic to gate.
  - Methods marked `@protected`, `@override` of a non-public interface.

### 3. Check each method body

Look for any of these calls **inside the body** (not in the signature, not
in dartdoc):

- `validateOwnership(`
- `validateWritePermission(`
- `validateSelfOperation(`
- `validateRequiredFields(`
- `hasReadAccess(`
- `getDocumentWithPermissionCheck(`
- `logPermissionCheck(`

Plus any other validate-prefixed call that's defined in the mixin (re-grep
the mixin file at audit time to keep this list current — append new
methods to the list if the mixin grows).

### 4. Classify

| Finding | Severity |
|---|---|
| Repository class has no `with PermissionValidationMixin` AND has any public method touching Firestore | **Critical** |
| Class has the mixin but a public method body has zero validate* calls | **High** |
| Public method is a single-line forwarder to a method that DOES validate | **Skip** (false positive) |
| Public method's body has a validate* call only inside a conditional that may not execute | **Review** |
| Cannot statically resolve method body (extension methods, dynamic dispatch) | **Review** |

### 5. Write the report

```markdown
# Permission audit — <YYYY-MM-DD>

Scanned: N repository files in `lib/repositories/`.

## Summary

- ✅ Compliant: N
- ⚠️  High-severity findings: N
- 🛑 Critical findings: N
- 🔍 Manual review needed: N

---

## Critical — repositories without PermissionValidationMixin (N)

### `lib/repositories/firebase/firebase_xxx_repository.dart`
**Class**: `FirebaseXxxRepository`
**Why critical**: Performs Firestore writes without going through the mixin.
**Methods touching Firestore**: `methodA`, `methodB`, ...
**Suggested fix**: Add `with PermissionValidationMixin` to the class
declaration and add `await validateOwnership(...)` to each Firestore-touching method.

---

## High — public methods missing a validate* call (N)

### `lib/repositories/firebase/firebase_yyy_repository.dart` → `updateThing()`
**Body excerpt**:
```dart
Future<void> updateThing(...) async {
  await firestore.doc(...).update(...);  // <-- no validate* call before this
}
```
**Suggested fix**: Add `await validateOwnership(...)` or
`await validateWritePermission(...)` before the Firestore call.

---

## Review — uncertain matches (N)

### `lib/repositories/firebase/firebase_zzz_repository.dart` → `complexFlow()`
**Why uncertain**: validate* call is inside an `if (isOwner)` branch only.
**Action**: Manually verify whether the else-branch is also gated.
```

### 6. Append to the audit-history index

Add a one-line entry to `tasks/permission-audit-history.md`:

```markdown
- 2026-04-25 — N compliant, M high, K critical. See [audit](./permission-audit-2026-04-25.md).
```

This gives a longitudinal record of compliance drift over time.

## What NOT to do

- Do not auto-fix findings. The point of an audit is to surface — fixes are
  per-repository decisions that should go through `firebase-backend-security`.
- Do not lower severity to make numbers look better. The audit's value is
  honesty.
- Do not rerun more than quarterly without reason. Stable repositories
  produce identical reports; the freshness lives in **drift detection**,
  not refrequent runs.
- Do not include this report in commit messages or PR descriptions.
  Reports go in `tasks/` (gitignored or similar) — they're working
  documents, not deliverables.

## After the report

Three follow-up patterns work well:

1. **Critical findings** → spawn `firebase-backend-security` agent on each
   one with the report excerpt as context.
2. **High findings** → batch into a single Linear ticket "Permission
   coverage gaps — <date>".
3. **Review findings** → walk through manually with a 10-minute timer per
   item.

The audit's value is the *initial* sweep. Subsequent runs are diff-detection.
