// lib/services/offline/comment_upload_completion.dart
//
// BUT-2294: the second step of a queued comment: the comment is created once
// all of its photos are in Storage, under the id the queue fixed for it.
library;

import 'dart:convert';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/services/offline/grouped_upload_completion.dart';

/// A comment ready to be created from its rows.
typedef QueuedComment = ({
  String commentId,
  String recipeId,
  String userId,
  String text,
  String? parentCommentId,
  List<String> imageUrls,
});

class CommentUploadCompletion extends GroupedUploadCompletion<QueuedComment> {
  CommentUploadCompletion({
    required super.database,
    required super.storage,
    required CommentsRepository Function() repository,
    super.spacing,
  }) : _repository = repository,
       super(entityType: SyncQueueEntityType.comment);

  final CommentsRepository Function() _repository;

  @override
  Future<bool> exists(String targetId) =>
      _repository().ownCommentExists(targetId);

  @override
  Future<void> create(QueuedComment target) async {
    await _repository().createQueuedComment(
      commentId: target.commentId,
      recipeId: target.recipeId,
      userId: target.userId,
      content: target.text,
      parentCommentId: target.parentCommentId,
      imageUrls: target.imageUrls,
    );
  }

  /// The rows' own `order`, not the order they sit in the table: rows queued
  /// in the same second tie on time.
  @override
  QueuedComment build(List<UploadQueueEntry> group, String userId) {
    Map<String, dynamic> metaOf(UploadQueueEntry r) =>
        jsonDecode(r.metadata ?? '{}') as Map<String, dynamic>;
    int orderOf(UploadQueueEntry r) => metaOf(r)['order'] as int? ?? 0;
    final photos = [...group]..sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    final meta = metaOf(photos.first);
    return (
      commentId: photos.first.entityId!,
      recipeId: meta['recipeId'] as String,
      userId: userId,
      text: meta['text'] as String,
      parentCommentId: meta['parentCommentId'] as String?,
      imageUrls: [for (final r in photos) r.uploadedUrl!],
    );
  }
}
