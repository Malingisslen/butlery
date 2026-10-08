// lib/core/storage/drift/recipe_revision_record.dart
//
// BUT-2213: which server revisions of a recipe this device produced itself.
//
// A queued update is compared against the revision (`rev`) its content was
// built on. The device's own sends move the server's revision on, while an
// editor or cache still holds the copy read before them; a save from that
// copy is built on content the device itself sent, so its base may be raised
// to the revision those sends produced. Nothing else may raise it: a base
// raised over a revision another device produced would write over that
// version without a conflict.
//
// The record lives in the device copy's JSON next to the recipe, under
// [key], as `{from, to}`: the sends that started from `from` (null: from the
// device's own create) brought the server to `to`. Only the queue's sender
// writes it, and taking the server's recipe after a conflict drops it.
library;

class RecipeRevisionRecord {
  RecipeRevisionRecord._();

  /// The key in the device copy's JSON. `Recipe.fromJson` ignores it.
  static const String key = '_ownRevisions';

  /// The base of an update whose base is not known: it equals no server
  /// revision, so the server takes it only when it already holds the same
  /// content, and otherwise answers with a conflict.
  static const int unknownBase = -1;

  /// The base a queued update of [rev] is built on, given the device copy
  /// [stored] (its decoded JSON, or null when the device holds none).
  static int? baseFor(int? rev, Map<String, dynamic>? stored) {
    final own = stored?[key];
    if (own is Map && own['to'] is int) {
      final from = own['from'];
      final to = own['to'] as int;
      final fromCreate = from == null;
      final builtOnOwn = rev == null
          ? fromCreate
          : rev < to && rev >= (fromCreate ? 0 : from as int);
      if (builtOnOwn) return to;
    }
    if (rev != null) return rev;
    // No revision: a copy the server has not seen yet (a create still in
    // the queue) or one queued before revisions existed is the device's
    // own, and is sent without comparing, as before BUT-2213.
    if (stored != null && stored['rev'] == null) return null;
    return unknownBase;
  }

  /// [json] after the server took a write of it built on [sentRev] and is
  /// now at [newRev] ([created]: the write was the create).
  static Map<String, dynamic> advanced(
    Map<String, dynamic> json, {
    required int? sentRev,
    required int newRev,
    required bool created,
  }) {
    final own = json[key];
    final Object? from;
    if (created) {
      from = null;
    } else if (sentRev == null || sentRev < 0) {
      // Sent without a known base: no revision before it is the device's.
      return {...json, 'rev': newRev}..remove(key);
    } else if (own is Map && own['to'] == sentRev) {
      from = own['from'];
    } else {
      from = sentRev;
    }
    return {
      ...json,
      'rev': newRev,
      key: {'from': from, 'to': newRev},
    };
  }
}
