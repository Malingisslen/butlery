// lib/services/offline/cook_snap_upload_completion.dart
//
// BUT-2294: the second step of a queued cook snap: the snap is created once
// all the photos of its album are in Storage.
library;

import 'dart:convert';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/services/offline/grouped_upload_completion.dart';

/// The name and picture the snap shows for its author.
typedef CookSnapAuthor = ({String displayName, String? avatarUrl});

class CookSnapUploadCompletion extends GroupedUploadCompletion<CookSnap> {
  CookSnapUploadCompletion({
    required super.database,
    required super.storage,
    required CookSnapRepository Function() repository,
    required CookSnapAuthor Function(String userId) author,
    required void Function(
      CookSnap snap, {
      required String recipeAuthorId,
      required String recipeName,
      required String senderName,
    })
    announce,
    super.spacing,
  }) : _repository = repository,
       _author = author,
       _announce = announce,
       super(entityType: SyncQueueEntityType.cookSnap);

  final CookSnapRepository Function() _repository;
  final CookSnapAuthor Function(String userId) _author;
  final void Function(
    CookSnap snap, {
    required String recipeAuthorId,
    required String recipeName,
    required String senderName,
  })
  _announce;

  @override
  Future<bool> exists(String targetId) => _repository().ownSnapExists(targetId);

  @override
  Future<void> create(CookSnap target) async {
    await _repository().addCookSnap(target);
  }

  @override
  void created(CookSnap target, List<UploadQueueEntry> group) {
    final meta = _metaOf(group.first);
    _announce(
      target,
      recipeAuthorId: (meta['recipeAuthorId'] as String?).orEmpty(),
      recipeName: (meta['recipeName'] as String?).orEmpty(),
      senderName: target.userDisplayName,
    );
  }

  Map<String, dynamic> _metaOf(UploadQueueEntry row) =>
      jsonDecode(row.metadata ?? '{}') as Map<String, dynamic>;

  /// The rows' own `order`, not the order they sit in the table: rows queued
  /// in the same second tie on time.
  @override
  CookSnap build(List<UploadQueueEntry> group, String userId) {
    int orderOf(UploadQueueEntry r) => _metaOf(r)['order'] as int? ?? 0;
    final photos = [...group]..sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    final meta = _metaOf(photos.first);
    final author = _author(userId);
    return CookSnap.create(
      id: photos.first.entityId,
      recipeId: meta['recipeId'] as String,
      userId: userId,
      userDisplayName: author.displayName,
      userAvatarUrl: author.avatarUrl,
      photoUrls: [for (final r in photos) r.uploadedUrl!],
      thumbnailUrl: photos.first.uploadedThumbnailUrl,
      caption: meta['caption'] as String?,
      visibility: CookSnapVisibility.values.firstWhere(
        (v) => v.name == meta['visibility'],
        orElse: () => CookSnapVisibility.sameAsRecipe,
      ),
    );
  }
}
