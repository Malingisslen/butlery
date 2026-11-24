import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/meal_box_repository.dart';

/// `users/{uid}/meal_boxes/{id}`. Ownership is structural (the user's own
/// subcollection, owner-only in `firestore.rules`), as for the pantry.
class FirebaseMealBoxRepository extends BaseFirebaseRepository<MealBox>
    with UserScopedFirebaseRepository<MealBox>
    implements MealBoxRepository {
  FirebaseMealBoxRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  static const int defaultListLimit = 200;

  @override
  String get collectionName => FirestoreCollections.mealBoxes;

  @override
  MealBox fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MealBox.fromMap(doc.id, doc.data() ?? const {});

  @override
  Map<String, dynamic> toFirestore(MealBox entity) => {
    if (entity.recipeId != null) 'recipeId': entity.recipeId,
    'recipeTitle': MealBox.clampTitle(entity.recipeTitle),
    'location': entity.location.name,
    'storedOn': Timestamp.fromDate(entity.storedOn),
    'count': entity.count.clamp(0, MealBox.maxCount),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  String getId(MealBox entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(String userId, MealBox entity) async =>
      true;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    MealBox? entity,
  ) async => true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    MealBox entity,
  ) async => true;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => true;

  @override
  Future<List<MealBox>> list({int limit = defaultListLimit}) async {
    final snapshot = await getCollectionRef().limit(limit).get();
    return snapshot.docs.map(fromFirestore).toList();
  }

  @override
  Future<String> add(MealBox box) async {
    final ref = getCollectionRef().doc();
    await ref.set(toFirestore(box));
    return ref.id;
  }

  @override
  Future<void> setCount(String id, int count) =>
      getCollectionRef().doc(_checked(id)).update({
        'count': count.clamp(0, MealBox.maxCount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> foldTakes(MealBox box, Iterable<String> eatenKeys) {
    final keys = eatenKeys.where(box.takes.containsKey).toList();
    if (keys.isEmpty) return Future.value();
    final eaten = keys.fold(0, (total, k) => total + box.takes[k]!);
    return getCollectionRef().doc(_checked(box.id)).update({
      'count': math.max(0, box.count - eaten),
      for (final k in keys) FieldPath(['takes', k]): FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String id) =>
      getCollectionRef().doc(_checked(id)).delete();

  /// The box a lunch take writes to, under [userId].
  static DocumentReference<Map<String, dynamic>> takeRef(
    FirebaseFirestore firestore,
    String userId,
    MealBoxTake take,
  ) => firestore
      .collection(FirestoreCollections.users)
      .doc(userId)
      .collection(FirestoreCollections.mealBoxes)
      .doc(_checked(take.boxId));

  /// The `set(merge)` map of one lunch take. It names the box in full, so it
  /// succeeds, recreating the box without a count, when the document is gone:
  /// a deleted box must never stop the week's save it rides with.
  static Map<String, dynamic> takeWriteMap(MealBoxTake take) => {
    if (take.recipeId != null) 'recipeId': take.recipeId,
    'recipeTitle': MealBox.clampTitle(take.recipeTitle),
    'location': take.location.name,
    'storedOn': Timestamp.fromDate(take.storedOn),
    'takes': {take.key: take.portions ?? FieldValue.delete()},
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static String _checked(String id) {
    if (!MealBox.isValidId(id)) {
      throw ArgumentError.value(id, 'id', 'not a meal box id');
    }
    return id;
  }
}
