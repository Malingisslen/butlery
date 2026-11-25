import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/queued_write.dart';
import 'package:butlery/repositories/interfaces/meal_box_repository.dart';

/// `users/{uid}/meal_boxes/{id}`. Ownership is structural (the user's own
/// subcollection, owner-only in `firestore.rules`), as for the pantry.
///
/// Writes wait for the server at most [queuedWritePatience] and are otherwise
/// left in Firestore's queue, as the pantry's are (BUT-2288), so the fridge
/// list works without a connection.
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
    await awaitOrLeaveQueued(
      ref.set(toFirestore(box)),
      what: 'meal box add ${ref.id}',
    );
    return ref.id;
  }

  @override
  Future<void> setCount(String id, int count) => awaitOrLeaveQueued(
    getCollectionRef().doc(_checked(id)).update({
      'count': count.clamp(0, MealBox.maxCount),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
    what: 'meal box count $id',
  );

  @override
  Future<void> foldTakes(MealBox box, Iterable<String> eatenKeys) {
    final keys = eatenKeys.where(box.takes.containsKey).toList();
    if (keys.isEmpty) return Future.value();
    final eaten = keys.fold(0, (total, k) => total + box.takes[k]!);
    return awaitOrLeaveQueued(
      getCollectionRef().doc(_checked(box.id)).update({
        'count': math.max(0, box.count - eaten),
        for (final k in keys) FieldPath(['takes', k]): FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      what: 'meal box fold ${box.id}',
    );
  }

  @override
  Future<void> delete(String id) => awaitOrLeaveQueued(
    getCollectionRef().doc(_checked(id)).delete(),
    what: 'meal box delete $id',
  );

  @override
  Future<void> restore(MealBox box) => awaitOrLeaveQueued(
    getCollectionRef().doc(_checked(box.id)).set(restoreWriteMap(box)),
    what: 'meal box restore ${box.id}',
  );

  @override
  Future<void> setStoredOn(String id, DateTime storedOn) => awaitOrLeaveQueued(
    getCollectionRef().doc(_checked(id)).update({
      'storedOn': Timestamp.fromDate(storedOn),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
    what: 'meal box date $id',
  );

  @override
  Future<String> move(
    MealBox box,
    MealBoxLocation to,
    DateTime storedOn,
  ) async {
    final source = getCollectionRef().doc(_checked(box.id));
    final target = getCollectionRef().doc();
    final batch = firestore.batch()
      ..set(
        target,
        toFirestore(
          MealBox(
            id: target.id,
            recipeId: box.recipeId,
            recipeTitle: box.recipeTitle,
            location: to,
            storedOn: storedOn,
            count: box.remaining,
          ),
        ),
      );
    if (box.takes.isEmpty) {
      batch.delete(source);
    } else {
      batch.update(source, {
        'count': box.taken.clamp(0, MealBox.maxCount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await awaitOrLeaveQueued(
      batch.commit(),
      what: 'meal box move ${box.id} -> ${target.id}',
    );
    return target.id;
  }

  @override
  Future<void> undoMove(MealBox original, String movedId) {
    final batch = firestore.batch()
      ..delete(getCollectionRef().doc(_checked(movedId)))
      ..set(
        getCollectionRef().doc(_checked(original.id)),
        restoreWriteMap(original),
      );
    return awaitOrLeaveQueued(
      batch.commit(),
      what: 'meal box undo move ${original.id}',
    );
  }

  /// The whole box, its planned lunches included, as [restore] writes it.
  static Map<String, dynamic> restoreWriteMap(MealBox box) => {
    if (box.recipeId != null) 'recipeId': box.recipeId,
    'recipeTitle': MealBox.clampTitle(box.recipeTitle),
    'location': box.location.name,
    'storedOn': Timestamp.fromDate(box.storedOn),
    'count': box.count.clamp(0, MealBox.maxCount),
    if (box.takes.isNotEmpty) 'takes': box.takes,
    'updatedAt': FieldValue.serverTimestamp(),
  };

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
