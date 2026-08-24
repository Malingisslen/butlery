// lib/repositories/firebase/firebase_chat_group_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';

/// Reads `chat_groups`; every write goes through a Cloud Function.
///
/// Not a [BaseFirebaseRepository]: that base exists for collections the client
/// both reads and writes, and implementing its `toFirestore`/`create`/`update`
/// here would mean writing a serializer for a document `firestore.rules`
/// refuses from every client. A dead write path is how somebody later "fixes"
/// a bug by using it, and a Firestore-rules denial is invisible from the Dart
/// side — only a rules test or a real device sees it (BUT-1482).
///
/// It carries [PermissionValidationMixin] like every other repository
/// (CLAUDE.md rule 3), in the same CLASS shape as `BaseMetadataRepository` —
/// but stated plainly: that class also calls `logPermissionCheck` and this one
/// calls nothing from the mixin at all. The membership decisions happen
/// server-side, in the callables, and the audit trail for them is an open gap
/// rather than something this class provides. Do not read the precedent as a
/// claim that this logs.
class FirebaseChatGroupRepository
    with PermissionValidationMixin
    implements ChatGroupRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final FirebaseFunctions _functions;

  FirebaseChatGroupRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authRepository = authRepository,
       // europe-west1: the callables inherit it from setGlobalOptions, so a
       // default-region handle here would call a function that does not exist.
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.chatGroups);

  String _requireUserId() {
    final userId = _authRepository.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw PermissionDeniedException(
        'Sign-in required for chat groups',
        operation: 'chat_group_access',
      );
    }
    return userId;
  }

  @override
  Future<ChatGroup?> getGroup(String groupId) async {
    try {
      _requireUserId();
      final doc = await _collection.doc(groupId).get();
      if (!doc.exists) return null;
      return ChatGroup.fromFirestore(doc);
    } catch (e) {
      AppLogger.error('Failed to read chat group $groupId', e);
      rethrow;
    }
  }

  @override
  Stream<ChatGroup?> watchGroup(String groupId) {
    _requireUserId();
    return _collection
        .doc(groupId)
        .snapshots()
        .map((doc) => doc.exists ? ChatGroup.fromFirestore(doc) : null);
  }

  @override
  Stream<List<ChatGroup>> watchMyGroups() {
    final userId = _requireUserId();
    // Equality-shaped only (`array-contains`, no orderBy), so the automatic
    // single-field index covers it and no composite is needed. Adding an
    // orderBy here later DOES need one declared in firestore.indexes.json
    // before it ships.
    return _collection
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs.map(ChatGroup.fromFirestore).toList());
  }

  @override
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    _requireUserId();
    final response = await _call('createChatGroup', {
      'name': name,
      'memberIds': memberIds,
    });
    final groupId = response['groupId'];
    if (groupId is! String || groupId.isEmpty) {
      throw ResourceNotFoundException(
        'createChatGroup returned no group id',
        resourceType: 'chat_group',
      );
    }
    return groupId;
  }

  @override
  Future<String> ensureCategoryChat({
    required String ownerId,
    required String categoryId,
  }) async {
    _requireUserId();
    final response = await _call('ensureCategoryChat', {
      'ownerId': ownerId,
      'categoryId': categoryId,
    });
    final conversationId = response['conversationId'];
    if (conversationId is! String || conversationId.isEmpty) {
      throw ResourceNotFoundException(
        'ensureCategoryChat returned no conversation id',
        resourceType: 'chat_group',
      );
    }
    return conversationId;
  }

  @override
  Future<List<String>> addMembers({
    required String groupId,
    required List<String> userIds,
  }) async {
    _requireUserId();
    final response = await _call('addChatGroupMembers', {
      'groupId': groupId,
      'userIds': userIds,
    });
    final added = response['addedUserIds'];
    return added is List ? added.whereType<String>().toList() : const [];
  }

  @override
  Future<void> removeMember({required String groupId, String? userId}) async {
    _requireUserId();
    final response = await _call('removeChatGroupMember', {
      'groupId': groupId,
      'userId': ?userId,
    });
    // `removed: false` is the callable's no-oracle answer: the group is gone,
    // you were never in it, or you already left. Reporting it as success is
    // what turned "lämna gruppen" into a silent lie once before (BUT-1795), so
    // the caller is told plainly instead.
    if (response['removed'] != true) {
      throw ResourceNotFoundException(
        'removeChatGroupMember reported no change for $groupId',
        resourceType: 'chat_group',
        resourceId: groupId,
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(payload);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // The gate's refusal travels in `details.blockedUserIds`. Kept as a
      // typed exception rather than flattened to a string so the UI can name
      // who could not be added without ever saying why — the reason is that
      // someone is a minor, and that is not the inviter's business.
      AppLogger.error('Callable $name failed: ${e.code}', e);
      rethrow;
    }
  }
}
