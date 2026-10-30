/// Firebase implementation of [SignupAllowlistRepository] (BUT-2452).
///
/// `signup_allowlist/{email}` is admin-only in firestore.rules, which also
/// pins the three fields, the server time and the caller's uid. The client
/// checks that someone is signed in; the rules decide whether that someone
/// is an admin.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/admin/signup_invite.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/signup_allowlist_repository.dart';

class FirebaseSignupAllowlistRepository
    extends BaseFirebaseRepository<SignupInvite>
    implements SignupAllowlistRepository {
  FirebaseSignupAllowlistRepository({
    super.firestore,
    required super.authRepository,
  });

  /// The rules accept at most request.time + 30 days + 1 minute; an hour of
  /// margin keeps a phone whose clock runs fast inside that bound.
  static const inviteLifetime = Duration(days: 29, hours: 23);

  @override
  String get collectionName => FirestoreCollections.signupAllowlist;

  @override
  SignupInvite fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SignupInvite.fromFirestore(doc.id, doc.data() ?? const {});

  @override
  Map<String, dynamic> toFirestore(SignupInvite entity) => {
    'invitedAt': FieldValue.serverTimestamp(),
    'invitedBy': requireCurrentUserId(),
    'expireAt': Timestamp.fromDate(clock.now().add(inviteLifetime)),
  };

  @override
  String getId(SignupInvite entity) => entity.email;

  @override
  Future<bool> validateCreatePermission(
    String userId,
    SignupInvite entity,
  ) async => userId == requireCurrentUserId();

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    SignupInvite? entity,
  ) async => userId == requireCurrentUserId();

  /// An invite is added or removed, never edited.
  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    SignupInvite entity,
  ) async => false;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => userId == requireCurrentUserId();

  @override
  Future<List<SignupInvite>> listInvites() async {
    requireCurrentUserId();
    final snapshot = await collection
        .orderBy('invitedAt', descending: true)
        .get();
    return [
      for (final doc in snapshot.docs)
        SignupInvite.fromFirestore(doc.id, doc.data()),
    ];
  }

  @override
  Future<void> invite(String email) async {
    final invite = SignupInvite(email: email);
    final ref = collection.doc(email);
    // A second write on an existing id is an update, which the rules refuse;
    // checking first turns that into a message the admin can act on.
    if ((await ref.get()).exists) throw const SignupInviteExistsException();
    await ref.set(toFirestore(invite));
  }

  @override
  Future<void> remove(String email) async {
    requireCurrentUserId();
    await collection.doc(email).delete();
  }
}
