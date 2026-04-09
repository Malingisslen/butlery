/// ViewModel managing social recipe interactions including comments, likes, and sharing.

// lib/viewmodels/social_recipe_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/social_recipe/social_comments_manager.dart';
import 'package:butlery/viewmodels/social_recipe/social_engagement_manager.dart';
import 'package:butlery/viewmodels/social_recipe/social_profile_manager.dart';

class SocialRecipeViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;
  final UnifiedRecipeService _recipeService;
  final UserService _userService;

  late final SocialCommentsManager _commentsManager;
  late final SocialEngagementManager _engagementManager;
  late final SocialProfileManager _profileManager;

  SocialRecipeViewModel({
    required UnifiedFriendsService friendsService,
    required UnifiedRecipeService recipeService,
    required UserService userService,
  })  : _friendsService = friendsService,
        _recipeService = recipeService,
        _userService = userService {
    _commentsManager = SocialCommentsManager(_recipeService);
    _engagementManager = SocialEngagementManager();
    _profileManager = SocialProfileManager(_friendsService, _userService);

    _commentsManager.addListener(_onManagerChanged);
    _engagementManager.addListener(_onManagerChanged);
    _profileManager.addListener(_onManagerChanged);
  }

  void _onManagerChanged() {
    notifyListeners();
  }

  // State accessors - delegate to comment manager
  bool get hasComments => _commentsManager.hasComments;
  int? get commentCount => _commentsManager.commentCount;
  bool get isLoadingComments => _commentsManager.isLoadingComments;
  String? get commentsError => _commentsManager.commentsError;
  bool get isPostingComment => _commentsManager.isPostingComment;
  bool get isReplying => _commentsManager.isReplying;
  String get newCommentText => _commentsManager.newCommentText;
  List<RecipeComment> get comments => _commentsManager.comments;
  List<RecipeComment> get topLevelComments => _commentsManager.topLevelComments;

  // Profile accessors - delegate to profile manager
  List<UserProfile> get friends => _profileManager.friends;
  UserProfile? get currentUser => _profileManager.currentUser;

  // Comment operations - delegate to comment manager
  Future<void> refreshComments(String recipeId) async {
    await _commentsManager.refreshComments(recipeId);
    final commentIds = comments.map((c) => c.id).toList();
    await _engagementManager.loadLikeStatus(commentIds);
  }

  Future<void> fetchCommentCount(String recipeId) async {
    await _commentsManager.fetchCommentCount(recipeId);
  }

  void startWatchingComments(String recipeId) {
    _commentsManager.startWatchingComments(recipeId);
  }

  void stopWatchingComments() {
    _commentsManager.stopWatchingComments();
  }

  void updateNewCommentText(String text) {
    _commentsManager.updateNewCommentText(text);
  }

  Future<void> postComment(String recipeId) async {
    await _commentsManager.postComment(recipeId);
  }

  void setReplyTo(String commentId) {
    _commentsManager.setReplyTo(commentId);
  }

  void cancelReply() {
    _commentsManager.cancelReply();
  }

  Future<void> deleteComment(String recipeId, String commentId) async {
    await _commentsManager.deleteComment(recipeId, commentId);
  }

  Future<void> editComment(
      String recipeId, String commentId, String newContent) async {
    await _commentsManager.editComment(recipeId, commentId, newContent);
  }

  List<RecipeComment> getReplies(String parentCommentId) {
    return _commentsManager.getReplies(parentCommentId);
  }

  // Engagement operations - delegate to engagement manager
  Future<void> toggleCommentLike(String commentId) async {
    await _engagementManager.toggleCommentLike(commentId);
  }

  bool hasLikedComment(String commentId) {
    return _engagementManager.hasLikedComment(commentId);
  }

  // Profile operations - delegate to profile manager
  String getAuthorDisplayName(String authorId) {
    return _profileManager.getAuthorDisplayName(authorId);
  }

  String? getAuthorAvatarUrl(String authorId) {
    return _profileManager.getAuthorAvatarUrl(authorId);
  }

  Future<void> initialize() async {
    await _profileManager.initialize();
  }

  // Collaborative recipe operations (delegated to service layer)
  Future<bool> createCollaborativeRecipe({
    required String name,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    final recipeId = await _recipeService.createCollaborativeRecipe(
      title: name,
      memberIds: memberIds,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
      descriptionCollaborative: descriptionCollaborative,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
    return recipeId != null;
  }

  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _recipeService.social.shareRecipe(
      recipeId: recipeId,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      collaborativeDescription: collaborativeDescription,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    return await _recipeService.social.makeRecipePersonal(
      collaborativeRecipeId: collaborativeRecipeId,
    );
  }

  // Member management operations (delegated to service layer)
  Future<bool> addMemberToRecipe(
      String recipeId, String userId, String userDisplayName,
      {required ResourcePermission permission}) async {
    return await _recipeService.addMemberToRecipe(
      recipeId,
      userId,
      permission,
    );
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _recipeService.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, ResourcePermission permission) async {
    return await _recipeService.updateMemberPermission(
      recipeId,
      userId,
      permission,
    );
  }

  /// Synchronous accessor for recipe member permissions.
  /// For full member details use the async service method directly.
  Map<String, ResourcePermission> getRecipeMembers(String recipeId) {
    AppLogger.warning('Not yet implemented: getRecipeMembers (sync accessor)');
    return {};
  }

  bool canInviteMembers(String recipeId) {
    return _recipeService.social.canInviteMembers(recipeId);
  }

  /// Synchronous accessor for recipes shared with the current user.
  /// The underlying service method is async; use the service directly for full results.
  List<Recipe> getSharedWithMe() {
    AppLogger.warning(
        'Not yet implemented: getSharedWithMe (sync accessor — use service.social.getSharedWithMe())');
    return [];
  }

  /// Synchronous accessor for recipes shared by the current user.
  /// The underlying service method is async; use the service directly for full results.
  List<Recipe> getSharedByMe() {
    AppLogger.warning(
        'Not yet implemented: getSharedByMe (sync accessor — use service.social.getSharedByMe())');
    return [];
  }

  String get serviceName => 'SocialRecipeViewModel';

  @override
  void dispose() {
    _commentsManager.removeListener(_onManagerChanged);
    _engagementManager.removeListener(_onManagerChanged);
    _profileManager.removeListener(_onManagerChanged);
    _commentsManager.dispose();
    _engagementManager.dispose();
    _profileManager.dispose();
    AppLogger.info('SocialRecipeViewModel disposed');
    super.dispose();
  }
}
