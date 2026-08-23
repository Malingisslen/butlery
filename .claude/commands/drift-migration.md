---
name: drift-migration
description: Scaffold a safe Drift schema migration for the SQLCipher-encrypted local DB. Use when adding/removing/renaming a column, adding a table, or otherwise changing the schema in lib/core/storage/drift/. Generates the schemaVersion bump, the migration step in MigrationStrategy, a rollback consideration, and a regression test that exercises the migration on a populated DB.
disable-model-invocation: true
---

# /drift-migration — Safe Drift schema migration scaffolder

## Why this is user-only

Schema migrations are intentional acts. Claude can compose them, but the
*decision* to migrate (and the destructive consequences if wrong) belongs
to you. Run this skill when you've decided a schema change is needed —
not as a side effect of "I added a column."

## Cost of getting it wrong

The local DB is **SQLCipher-encrypted** and contains user-cached recipes,
sync queue, JSON cache, parse cache, and upload queue. A broken migration
means:

- App crash on next launch (corruption-detected by SQLite)
- Silent data loss (user's offline recipes wiped)
- Sync queue loss (queued writes dropped → server-side data desync)

A correct migration should be **idempotent under retry** (the user might
crash mid-migration) and **forward-only** (no rollback once shipped).

## Pre-flight checklist

Before scaffolding, confirm:

- [ ] What's the current `schemaVersion`? (see `lib/core/storage/drift/app_database.dart`)
- [ ] What's the change? (new table / new column / drop column / rename / index)
- [ ] What existing data must survive the migration?
- [ ] If a new NOT NULL column: what's the default for existing rows?
- [ ] If a rename: rename via copy-table-then-drop, never `ALTER TABLE RENAME COLUMN` (unsupported in older SQLite versions Drift may target).

## Scaffolding workflow

1. **Read** `lib/core/storage/drift/app_database.dart` — note current
   `schemaVersion N` and the existing `MigrationStrategy.onUpgrade`
   structure.
2. **Modify the table** in `lib/core/storage/drift/tables/<name>.dart`.
3. **Bump** `schemaVersion` from `N` to `N+1`.
4. **Add a migration step** inside `onUpgrade(m, from, to)`:

   ```dart
   if (from < N+1) {
     // Migration N → N+1: <one-line description matching the change>
     await m.<addColumn|createTable|dropTable|...>(...);
   }
   ```

   Migrations must be **additive** in `if (from < X)` chains — each block
   must remain runnable for users coming from any older version, not just
   the immediately-previous one.

5. **Regenerate** the Drift code:

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

   Confirm `app_database.g.dart` reflects the change.

6. **Write a regression test** in
   `test/unit/core/storage/drift/migration_<N>_to_<N+1>_test.dart`:

   ```dart
   void main() {
     test('migrates from schema vN to vN+1 preserving existing rows', () async {
       // 1. Create a v(N) DB using NativeDatabase.memory().
       // 2. Insert representative rows via the OLD schema.
       // 3. Open AppDatabase against the same in-memory file with version N+1.
       // 4. Assert: existing rows present, new column has correct default,
       //    foreign keys still pointing where they should.
     });
   }
   ```

7. **Run** `flutter test test/unit/core/storage/drift/` — must pass.
8. **Verify** no other tests broke by `flutter test test/unit`.

## Patterns by migration type

### Add a new table
```dart
if (from < N+1) {
  await m.createTable(myNewTable);
}
```
Lowest risk. Just confirm the table is registered in `@DriftDatabase(tables: [...])`.

### Add a column (nullable)
```dart
if (from < N+1) {
  await m.addColumn(myTable, myTable.newColumn);
}
```
Safe if nullable. Existing rows get `NULL`.

### Add a column (NOT NULL with default)
```dart
if (from < N+1) {
  await m.addColumn(myTable, myTable.newColumn);
  await customStatement('UPDATE my_table SET new_column = <default> WHERE new_column IS NULL');
}
```
Must follow with the UPDATE — Drift's `addColumn` doesn't enforce DEFAULT
on existing rows in older SQLite versions.

### Drop a column
SQLite's `ALTER TABLE DROP COLUMN` is supported only on 3.35+. To stay
portable, **copy table → drop old → rename**:

```dart
if (from < N+1) {
  await m.alterTable(TableMigration(myTable, columnTransformer: { ... }));
}
```
Use Drift's `TableMigration` helper, which does the copy-rename dance for
you.

### Rename a column
Same as drop — use `TableMigration` with `columnTransformer` mapping the
old column expression to the new column.

## What NOT to do

- Do not skip the regression test. A migration without a test is a roll
  of the dice on whatever data the user has.
- Do not edit `app_database.g.dart` by hand — it's regenerated.
- Do not assume users will all come from version `N` — write the
  `if (from < X)` chain to handle any older version.
- Do not delete tables in a migration. Keep the table; just stop using it.
  Removing tables = data loss for users who haven't upgraded the rest of
  the app. If you really must, gate behind a major version bump.
- Do not introduce a migration during a feature branch and merge without
  shipping the corresponding `schemaVersion` bump — partial schemas leave
  some users mid-migration.

## After scaffolding

- Commit: `feat(db): migrate vN → vN+1 — <change>`
- Test on a real device with `flutter run --release` after a fresh install
  of the previous version (or via the install-old-then-upgrade flow).
- Watch Crashlytics for migration-related errors in the 24h after release.
