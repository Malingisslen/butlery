/// BUT-2033: the `ingredient_suggestions` burst guard, made mechanical.
///
/// `firestore.rules` carries a paragraph promising something no test held:
/// *"Whoever builds the client path adds `rateLimitStamped` here AND the stamp
/// there, in one change."* A paragraph is not a guard. The person who builds
/// that path in six months does not read it, and nothing reddens when they
/// skip it — the collection simply becomes spammable by any signed-in account,
/// with `create` already open to clients since BUT-2038.
///
/// This file turns that sentence into a red test, in BOTH directions:
///
/// 1. A Dart writer without `rateLimitStamped` — the spammable state.
/// 2. `rateLimitStamped` without a Dart writer — the rule reads a stamp nobody
///    writes, so EVERY create is denied, silently and forever. That is the same
///    fail-closed silence that cost three weeks on `configRevision`
///    (see `rules_allowlist_drift_test.dart`'s header), and it is the direction
///    a reviewer thinking only about spam would never look at.
/// 3. A writer that carries the rule but not the stamp — `rateLimitStamped`
///    requires `lastDocId == <the guarded document's id>` written in the SAME
///    request, so a writer that skips `stampRateLimit` is denied just as
///    silently.
///
/// Measured 2026-09-21: `lib/` contains no writer to this collection. The file
/// exists to flip to red inside the same CI run as the first writer, not to
/// describe today.
///
/// **What this does NOT cover.** It reads Dart and rules as TEXT; it never
/// evaluates a rule. Whether `rateLimitStamped` is actually reached — as
/// opposed to present — is the emulator suite's question, and
/// `functions/src/__tests__/ingredient-suggestions-rules.test.ts` is where it
/// belongs. A `rateLimitStamped(...)` sitting behind a flipped `&&`, or beside
/// a second permissive `allow`, is green here.
///
/// It also does not cover the DELETION half of BUT-2033's original wording.
/// That half was refuted when this was planned: `account-deletion-cascade.ts`
/// has swept this collection since BUT-2028, with its own probe leg and cap,
/// and `every collection this repo knows about is decided` in
/// `account-deletion-cascade.test.ts` already forces a deletion decision for
/// any new collection. Nothing was rebuilt for it.
///
/// **Residual, named rather than left to be found.** The write-verb scan below
/// is a BOUNDED WINDOW around each reference to the collection. A writer that
/// parks the `CollectionReference` in a field and writes through it far away is
/// invisible to it. Widening the window to whole files was measured and
/// rejected: the five pinned files below contain 19 unrelated `.add(`/`.set(`/
/// `.update(` calls between them (list and map calls, plus writes to other
/// collections), so a file-wide scan is noise, not coverage. What closes that
/// hole instead is the census: a held reference still has to be CONSTRUCTED in
/// some file, and a NEW file reddens no matter how it holds what it built.
///
/// A second false-negative path runs through the comment strip itself.
/// `withoutCStyleComments` was written for `firestore.rules`, and on Dart it can
/// delete live code: a `/*` inside a string or doc comment opens a block match
/// that runs to the next `*/`. Erased text is invisible to BOTH detectors — a
/// reference the census would have counted, or a verb the write scan would
/// have caught.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rules_source.dart';

/// Where the rule lives. Bounded at the next `match ` by [rulesBlock], so
/// nothing here can read a neighbouring block's text.
const _anchor = 'match /ingredient_suggestions/{suggestionId}';

/// The helper the rule's burst guard is spelled with.
const _ruleGuard = 'rateLimitStamped(';

/// The Dart helper that writes the stamp the rule reads.
///
/// `lib/repositories/firebase/rate_limit_stamp.dart`, already called from
/// several repositories — so a future writer is adopting a worn path, not
/// inventing one.
const _dartStamp = 'stampRateLimit(';

/// A reference to the collection that a COMPILER would resolve — the qualified
/// constant, or the string literal.
final _collectionRef = RegExp(
  r'''FirestoreCollections\.ingredientSuggestions|['"]ingredient_suggestions['"]''',
);

/// Firestore mutations, as they appear on a reference chain.
final _writeVerb = RegExp(r'\.(set|add|update|delete)\(');

/// How far past a collection reference a write verb still counts as bound to
/// it. A real chain — `.collection(X).doc(id).set({...})` — fits well inside
/// this even after the formatter wraps it.
const _windowChars = 240;

/// What a pinned file is allowed to do with the collection.
///
/// The distinction is what gives a correctly built client path a way back to
/// green. Without it, `_boundWrites` reddens on every writer forever and the
/// only way to a green suite is deleting the guard — which is how a guard
/// teaches people to ignore it.
enum _Kind {
  /// Reads, names or declares it. A write here is the finding.
  reader,

  /// Writes it, and is therefore subject to the rule and stamp tests below.
  writer,
}

/// Every file in `lib/` that references the collection, and what it does with
/// it. Pinned so that a NEW one forces a decision instead of arriving unnoticed
/// — the census doctrine `rules_allowlist_drift_test.dart` already runs on
/// allowlists.
///
/// Measured 2026-09-21 against `main`: five files, all readers. Paths use
/// forward slashes; the scan normalises before comparing, because this suite
/// runs on Windows.
const _pinned = <String, ({_Kind kind, String note})>{
  'lib/core/constants/firestore_collections.dart': (
    kind: _Kind.reader,
    note: 'declares the constant; touches no document',
  ),
  'lib/repositories/firebase/firebase_data_export_repository.dart': (
    kind: _Kind.reader,
    note: 'Art. 15 export — a `where(userId)` list query, no write',
  ),
  'lib/services/account/data_export_service.dart': (
    kind: _Kind.reader,
    note: 'names the export section; delegates to the content manager',
  ),
  'lib/services/account/export/content_export_manager.dart': (
    kind: _Kind.reader,
    note: 'builds the export section from rows it read',
  ),
  'lib/services/account/export/export_pagination_helper.dart': (
    kind: _Kind.reader,
    note: 'page size for the export section; touches no document',
  ),
};

/// Files under `lib/` referencing the collection, mapped to the stripped source
/// the match was found in.
///
/// Returns the source rather than just the path because a second
/// `readAsStringSync` would be a second ANSWER: this repo
/// expects parallel sessions editing `lib/` while a suite runs, so membership
/// decided on one read and scanned on another can straddle two versions of the
/// same file.
Map<String, String> _referencingSources() {
  final found = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = withoutCStyleComments(entity.readAsStringSync());
    if (_collectionRef.hasMatch(source)) {
      found[entity.path.replaceAll(r'\', '/')] = source;
    }
  }
  return found;
}

/// Write verbs sitting within [_windowChars] of a collection reference in
/// [source], which must already be comment-stripped.
///
/// The window reaches BOTH WAYS, and that is a correction this file's own
/// self-test forced: a forward-only window read `.collection(X).doc(id).set()`
/// and missed `batch.set(db.collection(X).doc(id), data)`, where the verb sits
/// BEFORE the reference. The batched form is not the exotic one — it is how
/// every rate-limited writer in `lib/` already writes, because the rule
/// requires the stamp in the same batch as the document.
///
/// Returns the offending snippets so a failure can print what it saw rather
/// than only that it saw something.
List<String> _boundWrites(String source) {
  final hits = <String>[];
  for (final ref in _collectionRef.allMatches(source)) {
    final start = (ref.start - _windowChars).clamp(0, source.length);
    final end = (ref.end + _windowChars).clamp(0, source.length);
    final window = source.substring(start, end);
    if (_writeVerb.hasMatch(window)) {
      hits.add(window.replaceAll(RegExp(r'\s+'), ' ').trim());
    }
  }
  return hits;
}

void main() {
  late String rules;
  late String block;
  late Set<String> referencing;
  late Map<String, List<String>> writesByFile;
  late Map<String, String> strippedByFile;

  setUpAll(() {
    rules = withoutCStyleComments(File('firestore.rules').readAsStringSync());
    final extracted = rulesBlock(rules, _anchor);
    expect(
      extracted,
      isNotNull,
      reason:
          'the anchor "$_anchor" is gone from firestore.rules. If the block '
          'was renamed, update `_anchor`; if the collection was removed, '
          'delete this file. Do not leave the assertions below reading an '
          'empty string, which every one of them would pass on.',
    );
    block = extracted!;

    // One read per file, and every consumer descends from it: the scan itself
    // hands back the source it matched on, so membership, the write scan and
    // the stamp check cannot be decided on different versions of the same file
    // while a parallel session edits `lib/`.
    strippedByFile = _referencingSources();
    referencing = strippedByFile.keys.toSet();
    writesByFile = {
      for (final entry in strippedByFile.entries)
        entry.key: _boundWrites(entry.value),
    };
  });

  test('every lib/ file referencing ingredient_suggestions is pinned', () {
    expect(
      referencing,
      _pinned.keys.toSet(),
      reason:
          'the set of files referencing `ingredient_suggestions` changed.\n'
          'A NEW file here is the client path BUT-2033 was filed about. '
          'Decide what it is and say so:\n'
          '  - it only READS or names the collection -> add it to `_pinned` '
          'as `_Kind.reader` with a one-line note;\n'
          '  - it WRITES -> add it as `_Kind.writer`, AND give it '
          '`rateLimitStamped` in firestore.rules AND a `stampRateLimit` call '
          'in the same batch, in this same change. The two tests below say '
          'which half is missing.\n'
          'A file that DISAPPEARED from this set is the harmless direction: '
          'drop its entry.',
    );
  });

  test('no file pinned as a reader writes to ingredient_suggestions', () {
    final offenders = {
      for (final entry in writesByFile.entries)
        if (entry.value.isNotEmpty && _pinned[entry.key]?.kind != _Kind.writer)
          entry.key: entry.value,
    };
    expect(
      offenders,
      isEmpty,
      reason:
          'a write verb appeared within $_windowChars characters of a '
          '`ingredient_suggestions` reference in a file pinned as a reader.\n'
          'If it really writes, this is the client path: move its `_pinned` '
          'entry to `_Kind.writer`, add `rateLimitStamped` to the rule block '
          'and `stampRateLimit` to the write — all in this change. The two '
          'tests below then hold it, and this one goes green.\n'
          'If the verb is a DELETE rather than a create, that remedy is the '
          'wrong one and this message is not your instruction: erasure for '
          'this collection lives in `account-deletion-cascade.ts` under the '
          'Admin SDK, which rules do not gate.\n'
          'Saw: $offenders',
    );
  });

  test('the rule\'s burst guard matches whether a Dart writer exists', () {
    final hasWriter = writesByFile.values.any((w) => w.isNotEmpty);
    final hasRuleGuard = block.contains(_ruleGuard);

    if (hasWriter) {
      expect(
        hasRuleGuard,
        isTrue,
        reason:
            'a Dart writer to `ingredient_suggestions` exists and the rule '
            'block carries no `$_ruleGuard`. Any signed-in account can now '
            'spam the collection: `create` has been client-reachable since '
            'BUT-2038, and nothing bounds the row count. Add '
            "`rateLimitStamped('ingredient_suggestions', <seconds>, "
            'suggestionId)` to the create limb.',
      );
    } else {
      expect(
        hasRuleGuard,
        isFalse,
        reason:
            '`$_ruleGuard` was added to the `ingredient_suggestions` rule '
            'block while no code in `lib/` writes to the collection.\n'
            'That is not harmless caution: the helper requires a stamp at '
            '`users/{uid}/rate_limits/ingredient_suggestions` written in the '
            'SAME request, so with no writer to stamp it every create is '
            'DENIED — silently, with no error any user would report, for as '
            'long as it stands.\n'
            'Add the writer and its `stampRateLimit` call in this same change, '
            'or take the guard back out. This is BUT-2038\'s decision '
            '(`accepted-deviations.md`), not an oversight to tidy up.',
      );
    }
  });

  test('a Dart writer stamps the rate limit in the same change', () {
    final writers = writesByFile.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();
    if (writers.isEmpty) {
      // SKIPPED, not a bare return. A `return` reports a green tick with zero
      // assertions run, and the runner output is where a future reader looks —
      // they would read dormancy as coverage.
      markTestSkipped(
        'no DETECTED lib/ writer to ingredient_suggestions — dormant',
      );
      return;
    }

    // Reads the stripped source for the same reason the write scan does: an
    // un-stripped read lets a COMMENTED-OUT `stampRateLimit(` satisfy this,
    // which the self-test `a commented-out write cannot satisfy the reader
    // pin` refuses two assertions away.
    final unstamped = writers
        .where((path) => !strippedByFile[path]!.contains(_dartStamp))
        .toList();
    expect(
      unstamped,
      isEmpty,
      reason:
          'these files write to `ingredient_suggestions` without calling '
          '`$_dartStamp`: $unstamped\n'
          'The rule\'s `rateLimitStamped` reads a stamp at '
          '`users/{uid}/rate_limits/ingredient_suggestions` whose `lastDocId` '
          'must equal the suggestion\'s own id and whose `lastWrite` must be '
          'this request\'s server time. Without the stamp in the SAME batch as '
          'the create, the write is denied. See '
          '`lib/repositories/firebase/rate_limit_stamp.dart` and its '
          'existing call sites.',
    );
  });

  group('the detectors themselves', () {
    // A regex that has quietly stopped matching reads exactly like a clean
    // repo, so the verdicts are pinned against fixtures rather than assumed.
    // In memory only: nothing on disk is mutated, which is what makes this
    // safe to run while other sessions share the working tree.

    test('an inline chained write is detected', () {
      expect(
        _boundWrites(
          'firestore.collection(FirestoreCollections.ingredientSuggestions)'
          '    .doc(id)\n    .set(payload);',
        ),
        isNotEmpty,
      );
    });

    test('a batched write through the literal is detected', () {
      expect(
        _boundWrites(
          "batch.set(db.collection('ingredient_suggestions').doc(id), data);",
        ),
        isNotEmpty,
      );
    });

    test('a read-only query is not detected as a write', () {
      expect(
        _boundWrites(
          'firestore\n'
          '    .collection(FirestoreCollections.ingredientSuggestions)\n'
          "    .where('userId', isEqualTo: userId)\n"
          '    .get();',
        ),
        isEmpty,
      );
    });

    test(
      'a write far past the window is NOT detected — the named residual',
      () {
        // Pins the hole the header describes, so nobody reads a green run as
        // coverage it does not have.
        //
        // The distance is a LITERAL, not `_windowChars + n`. Derived from the
        // constant it guards, this test follows any widening and stays green —
        // it would then pin nothing while reading as a pin.
        final far =
            "final ref = db.collection('ingredient_suggestions');"
            "${' ' * 2000}ref.doc(id).set(payload);";
        expect(_boundWrites(far), isEmpty);
      },
    );

    test('the bare identifier alone is not a collection reference', () {
      expect(
        _collectionRef.hasMatch('final ingredientSuggestions = search(q);'),
        isFalse,
      );
    });

    test('a commented-out write cannot satisfy the reader pin', () {
      expect(
        _boundWrites(
          withoutCStyleComments(
            "// db.collection('ingredient_suggestions').doc(id).set(x);",
          ),
        ),
        isEmpty,
      );
    });

    test('the rule block is bounded at the next match', () {
      const sample =
          'match /a/{id} {\n  allow read: if true;\n}\n'
          'match /b/{id} {\n  allow write: if false;\n}';
      expect(
        rulesBlock(sample, 'match /a/{id}'),
        isNot(contains('allow write')),
      );
      expect(rulesBlock(sample, 'match /zzz/{id}'), isNull);
    });
  });
}
