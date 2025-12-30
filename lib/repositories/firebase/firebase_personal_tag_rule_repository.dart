import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

/// Firebase repository for personal tag automation rules.
///
/// Stores rules in user subcollection: users/{userId}/personalTagRules/{ruleId}
/// Each user can only access their own rules (owner-only permissions).
class FirebasePersonalTagRuleRepository
    extends BaseFirebaseRepository<PersonalTagRule>
    with UserScopedFirebaseRepository<PersonalTagRule> {
  FirebasePersonalTagRuleRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => 'personalTagRules';

  @override
  PersonalTagRule fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PersonalTagRule.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(PersonalTagRule entity) {
    return entity.toFirestore();
  }

  @override
  String getId(PersonalTagRule entity) => entity.id;

  // Owner-only permissions - user can only access their own subcollection
  @override
  Future<bool> validateCreatePermission(
    String userId,
    PersonalTagRule entity,
  ) async => true;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    PersonalTagRule? entity,
  ) async => true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    PersonalTagRule entity,
  ) async => true;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => true;

  /// Gets all rules for a specific tag.
  Future<List<PersonalTagRule>> getRulesForTag(String tagId) async {
    final snapshot = await getCollectionRef()
        .where('tagId', isEqualTo: tagId)
        .get();

    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Gets all enabled rules.
  Future<List<PersonalTagRule>> getEnabledRules() async {
    final snapshot = await getCollectionRef()
        .where('isEnabled', isEqualTo: true)
        .get();

    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Watches all enabled rules with real-time updates.
  Stream<List<PersonalTagRule>> watchEnabledRules() {
    return getCollectionRef()
        .where('isEnabled', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }

  /// Watches all rules (enabled and disabled) with real-time updates.
  Stream<List<PersonalTagRule>> watchAllRules() {
    return getCollectionRef()
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }

  /// Watches rules for a specific tag.
  Stream<List<PersonalTagRule>> watchRulesForTag(String tagId) {
    return getCollectionRef()
        .where('tagId', isEqualTo: tagId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }

  /// Deletes all rules for a specific tag (cascade delete).
  ///
  /// Call this when deleting a PersonalTag to clean up associated rules.
  Future<void> deleteRulesForTag(String tagId) async {
    requireCurrentUserId();
    final rules = await getRulesForTag(tagId);

    if (rules.isEmpty) return;

    final batch = firestore.batch();
    final ref = getCollectionRef();

    for (final rule in rules) {
      batch.delete(ref.doc(rule.id));
    }

    await batch.commit();
  }

  /// Enables or disables a rule.
  Future<void> setEnabled(String ruleId, {required bool enabled}) async {
    requireCurrentUserId();

    await getCollectionRef().doc(ruleId).update({
      'isEnabled': enabled,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Finds a rule by name (case-insensitive).
  Future<PersonalTagRule?> findByName(String name) async {
    final normalizedName = name.trim().toLowerCase();
    final all = await readAll();

    return all.cast<PersonalTagRule?>().firstWhere(
          (rule) => rule!.name.toLowerCase() == normalizedName,
          orElse: () => null,
        );
  }
}
