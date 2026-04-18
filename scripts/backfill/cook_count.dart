// ignore_for_file: avoid_print

/// Backfill cookCount=1 on recipes that were cooked at least once under the
/// pre-counter era (lastCookedAt != null, cookCount == null).
///
/// The production app treats null cookCount as legacy. Without a backfill the
/// future "Årets Kök" recap would under-count anyone who cooked before the
/// counter shipped. Setting those to 1 is the conservative choice — we know
/// the recipe was cooked at least once, just not how many times.
///
/// Usage:
///   dart scripts/backfill/cook_count.dart --dry-run
///   dart scripts/backfill/cook_count.dart --user USER_ID
///   dart scripts/backfill/cook_count.dart              # full live run
///
/// Wire up admin credentials before running live — this script expects the
/// caller to inject a FirebaseFirestore via the Admin SDK equivalent. In dev
/// we exercise the same code path under FakeFirebaseFirestore (see
/// test/scripts/cook_count_backfill_test.dart).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Outcome of a backfill pass — testable without touching stdout.
class CookCountBackfillResult {
  /// Recipes that matched the predicate (lastCookedAt!=null, cookCount==null).
  final int candidateCount;

  /// Recipes actually written. Equals 0 under --dry-run, equals
  /// [candidateCount] on a successful live run.
  final int writtenCount;

  /// Number of batched commits used (respects Firestore's 500-op limit).
  final int batchCount;

  const CookCountBackfillResult({
    required this.candidateCount,
    required this.writtenCount,
    required this.batchCount,
  });
}

/// Max ops per Firestore batch. Project-known invariant, shared with
/// BatchOperationsFirebaseRepository.
const _firestoreBatchLimit = 500;

/// Run the backfill. Public so tests can invoke it with a FakeFirebaseFirestore.
///
/// [firestore] — Firestore client to walk. In production pass the Admin SDK
/// instance; in tests pass FakeFirebaseFirestore.
/// [dryRun] — true to report counts without writing.
/// [userId] — when non-null, scopes the scan to `/users/{userId}/recipes`
/// (useful for targeted repair). Null walks every user via a collection-group
/// query on "recipes".
Future<CookCountBackfillResult> runCookCountBackfill({
  required FirebaseFirestore firestore,
  bool dryRun = false,
  String? userId,
}) async {
  final candidates = <DocumentReference<Map<String, dynamic>>>[];

  if (userId != null) {
    // Single-user path: direct query on the user's recipes subcollection.
    final snap = await firestore
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .get();
    for (final doc in snap.docs) {
      if (_needsBackfill(doc.data())) {
        candidates.add(doc.reference);
      }
    }
  } else {
    // All-users path: collection-group query across every user's "recipes".
    // Works identically against FakeFirebaseFirestore and production.
    final snap = await firestore.collectionGroup('recipes').get();
    for (final doc in snap.docs) {
      if (_needsBackfill(doc.data())) {
        candidates.add(doc.reference);
      }
    }
  }

  print('Found ${candidates.length} recipes needing cookCount=1');

  if (dryRun) {
    print('--dry-run: skipping writes');
    return CookCountBackfillResult(
      candidateCount: candidates.length,
      writtenCount: 0,
      batchCount: 0,
    );
  }

  // Commit in chunks of _firestoreBatchLimit — standard project idiom.
  var written = 0;
  var batchCount = 0;
  for (var i = 0; i < candidates.length; i += _firestoreBatchLimit) {
    final end = (i + _firestoreBatchLimit).clamp(0, candidates.length);
    final batch = firestore.batch();
    for (final ref in candidates.sublist(i, end)) {
      batch.update(ref, {'core.cookCount': 1});
    }
    await batch.commit();
    written += end - i;
    batchCount += 1;
    print('Committed batch $batchCount (${end - i} docs)');
  }

  print('Backfill done: wrote $written recipes across $batchCount batch(es)');
  return CookCountBackfillResult(
    candidateCount: candidates.length,
    writtenCount: written,
    batchCount: batchCount,
  );
}

/// Predicate: matches recipes with a cooking history but no counter set yet.
bool _needsBackfill(Map<String, dynamic> data) {
  final core = data['core'];
  if (core is! Map) return false;
  final lastCookedAt = core['lastCookedAt'];
  final cookCount = core['cookCount'];
  // lastCookedAt must be set (recipe was cooked at least once) AND cookCount
  // must be missing/null (legacy doc that pre-dates the counter feature).
  return lastCookedAt != null && cookCount == null;
}

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  String? targetUser;
  final userIdx = args.indexOf('--user');
  if (userIdx != -1 && userIdx + 1 < args.length) {
    targetUser = args[userIdx + 1];
  }

  print('=== cook_count backfill ===');
  print('dryRun=$dryRun, user=${targetUser ?? '<all>'}');

  // Real invocation would initialize Firebase Admin here. This main() is
  // a placeholder so the script is runnable; the CI/test path calls
  // runCookCountBackfill(...) directly against a fake.
  print('NOTE: initialize Firebase Admin before live run.');
}
