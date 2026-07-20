import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';

/// BUT-1629: client wrapper for the `setProfileSearchability` callable — the
/// only path by which a minor can become discoverable in people-search.
///
/// Why this exists rather than an ordinary profile save: `firestore.rules`
/// (BUT-1626) denies any CLIENT write that sets
/// `public_profiles/{uid}.isSearchable:true` while `users/{uid}.isMinor` is
/// true, and [UserProfile.toFirestore] independently forces the field to false
/// for a minor. Both stay in force — this callable writes with the Admin SDK
/// server-side, so the deliberate opt-in works without loosening either guard.
///
/// The callable takes no uid: it always targets the authenticated caller.
///
/// Errors ([FirebaseFunctionsException] and friends) propagate so the caller
/// can leave the toggle in its previous position and surface a failure.
class ProfileSearchabilityService extends BaseService {
  @override
  String get serviceName => 'ProfileSearchabilityService';

  final FirebaseFunctions _functions;
  static const String _callableName = 'setProfileSearchability';

  ProfileSearchabilityService({required FirebaseFunctions functions})
    : _functions = functions;

  /// Sets the caller's own discoverability. Returns the value the server
  /// stored, which is authoritative over the local optimistic value.
  Future<bool> setSearchable(bool searchable) async {
    final callable = _functions.httpsCallable(_callableName);
    final response = await callable.call<Map<dynamic, dynamic>>({
      'searchable': searchable,
    });
    return response.data['searchable'] == true;
  }
}
