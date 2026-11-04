import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';

/// What `createIngredientChangePr` reports back.
class IngredientChangePrResult {
  const IngredientChangePrResult({
    required this.prNumber,
    required this.prUrl,
    required this.applied,
    required this.conflicts,
    required this.rejected,
    required this.reopened,
    required this.skipped,
    this.merged = 0,
    this.wordLists,
    this.wordListError,
  });

  /// Reads a callable response; a missing number reads as 0 so a changed
  /// server shape shows up as an empty summary instead of a crash.
  factory IngredientChangePrResult.fromMap(Map<dynamic, dynamic> data) {
    int count(String key) => data[key] is num ? (data[key] as num).toInt() : 0;
    final url = data['prUrl'];
    final occasion = data['occasion'];
    final occasionError = data['occasionError'];
    return IngredientChangePrResult(
      prNumber: count('prNumber'),
      prUrl: url is String ? url : '',
      applied: count('applied'),
      conflicts: count('conflicts'),
      rejected: count('rejected'),
      reopened: count('reopened'),
      skipped: count('skipped'),
      merged: count('merged'),
      wordLists: occasion is Map
          ? IngredientChangePrResult.fromMap(occasion)
          : null,
      wordListError: occasionError is String ? occasionError : null,
    );
  }

  final int prNumber;
  final String prUrl;
  final int applied;
  final int conflicts;
  final int rejected;
  final int reopened;
  final int skipped;

  /// Word-list proposals whose PR was merged, marked applied in this run.
  final int merged;

  /// The word-list PR (admin-vy step D), built in the same run on its own
  /// branch. Null when that part failed; [wordListError] then holds the code.
  final IngredientChangePrResult? wordLists;
  final String? wordListError;
}

enum IngredientChangePrFailure {
  notAdmin,
  locked,
  tooManyProposals,
  notConfigured,
  unavailable,
  mainMoved,
  foreignCommits,
  rateLimited,
  other,
}

class IngredientChangePrException implements Exception {
  const IngredientChangePrException(this.failure);
  final IngredientChangePrFailure failure;

  @override
  String toString() => 'IngredientChangePrException($failure)';
}

/// The admin-only `createIngredientChangePr` callable.
class IngredientChangePrService extends BaseService {
  IngredientChangePrService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  String get serviceName => 'IngredientChangePrService';

  /// Throws [IngredientChangePrException] on a refusal.
  Future<IngredientChangePrResult> createPr() async {
    try {
      // Must outlast the function's own 300 s timeout, or the client gives up
      // on a run the server is still finishing.
      final result = await _functions
          .httpsCallable(
            'createIngredientChangePr',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 310),
            ),
          )
          .call<Map<dynamic, dynamic>>();
      return IngredientChangePrResult.fromMap(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw IngredientChangePrException(failureFor(e));
    }
  }

  static IngredientChangePrFailure failureFor(FirebaseFunctionsException e) =>
      switch (e.code) {
        'permission-denied' => IngredientChangePrFailure.notAdmin,
        'failed-precondition' => switch (e.message) {
          'locked' => IngredientChangePrFailure.locked,
          'too-many-proposals' => IngredientChangePrFailure.tooManyProposals,
          'not-configured' ||
          'github-not-configured' => IngredientChangePrFailure.notConfigured,
          _ => IngredientChangePrFailure.other,
        },
        'unavailable' => IngredientChangePrFailure.unavailable,
        'aborted' =>
          e.message == 'foreign-commits'
              ? IngredientChangePrFailure.foreignCommits
              : IngredientChangePrFailure.mainMoved,
        'resource-exhausted' => IngredientChangePrFailure.rateLimited,
        _ => IngredientChangePrFailure.other,
      };
}
