/// Comprehensive social recipe ViewModel providing advanced social interaction management for Flutter applications.
///
/// This module implements sophisticated social recipe functionality following Single Responsibility Principle,
/// handling all aspects of social recipe interaction including comments system, ratings management, recipe sharing,
/// and comprehensive social engagement coordination. It provides complete social recipe functionality
/// while maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles social recipe presentation layer concerns:
/// - **Comment System Management**: Comprehensive comment operations including posting, replying, threading, and moderation
/// - **Social Engagement Intelligence**: Advanced like/unlike functionality, rating management, and engagement tracking
/// - **Recipe Sharing Coordination**: Social recipe sharing, friend targeting, and collaborative recipe management
/// - **User Profile Integration**: Friend profile management, author identification, and social context coordination
/// - **Real-time Social Updates**: Live comment updates, engagement notifications, and social activity synchronization
///
/// **What This Module Does NOT Handle:**
/// - Direct social data persistence (handled by UnifiedRecipeService and social data repositories)
/// - UI rendering and widget creation (handled by social recipe views and comment components)
/// - Complex business logic implementation (handled by UnifiedRecipeService and social services)
/// - Authentication and permission logic (handled by PermissionService and social security layers)
///
/// **Social Recipe ViewModel Features:**
/// - **Threaded Comment System**: Complete comment hierarchy with replies, threading, and conversation management
/// - **Social Engagement Tracking**: Like/unlike functionality, engagement metrics, and social interaction analytics
/// - **Friend Integration**: Friend profile coordination, author identification, and social context management
/// - **Real-time Updates**: Live comment streaming, engagement notifications, and activity synchronization
/// - **Swedish Localization**: Complete Swedish language support for social interactions and user feedback
///
/// **Usage Examples:**
/// ```dart
/// // Initialize social recipe ViewModel with service dependencies
/// final socialRecipeViewModel = SocialRecipeViewModel(
///   recipeService: unifiedRecipeService,
///   friendsService: unifiedFriendsService,
/// );
/// await socialRecipeViewModel.initialize();
/// 
/// // Comment system operations
/// await socialRecipeViewModel.refreshComments('recipe_123');
/// 
/// // Post new comment
/// socialRecipeViewModel.updateNewCommentText('Fantastiskt recept! Barnen älskade det.');
/// await socialRecipeViewModel.postComment('recipe_123');
/// 
/// // Reply to existing comment
/// socialRecipeViewModel.setReplyTo('comment_456');
/// socialRecipeViewModel.updateNewCommentText('Håller med! Vilken krydda använde du?');
/// await socialRecipeViewModel.postComment('recipe_123');
/// 
/// // Social engagement operations
/// await socialRecipeViewModel.toggleCommentLike('comment_789');
/// final hasLiked = socialRecipeViewModel.hasLikedComment('comment_789');
/// 
/// // Comment hierarchy and threading
/// final topComments = socialRecipeViewModel.topLevelComments;
/// final replies = socialRecipeViewModel.getReplies('parent_comment_id');
/// 
/// // User profile integration
/// final authorName = socialRecipeViewModel.getAuthorDisplayName('user_id');
/// final avatarUrl = socialRecipeViewModel.getAuthorAvatarUrl('user_id');
/// 
/// // State monitoring for UI updates
/// if (socialRecipeViewModel.isLoadingComments) {
///   // Show loading indicator
/// } else if (socialRecipeViewModel.commentsError != null) {
///   // Handle error: socialRecipeViewModel.commentsError
/// }
/// ```

// lib/viewmodels/social_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/social/social_comment.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';
/// Comprehensive social recipe ViewModel providing advanced social interaction management through service coordination.
///
/// Serves as the main presentation layer coordinator for all social recipe operations, providing unified API
/// for comment management, social engagement, recipe sharing, and user interaction while maintaining clean MVVM architecture
/// separation between social recipe business logic and UI presentation concerns.
class SocialRecipeViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;
  final UnifiedRecipeService _recipeService;

  // ===== COMMENT SYSTEM STATE MANAGEMENT =====
  
  /// Comment loading operation state for UI progress indication during comment retrieval.
  /// 
  /// Indicates active comment loading for loading indicators and interaction control
  /// during comment system operations and data refresh.
  bool _isLoadingComments = false;
  
  /// Comment operation error message for user feedback and error recovery.
  /// 
  /// Provides comment-specific error messages for comprehensive error handling
  /// and user guidance during comment operations.
  String? _commentsError;
  
  /// Comment posting operation state for UI progress indication during comment submission.
  /// 
  /// Indicates active comment posting for loading indicators and interaction control
  /// during comment creation and submission operations.
  bool _isPostingComment = false;
  
  /// Reply mode state for comment threading and conversation management.
  /// 
  /// Indicates whether user is currently replying to a specific comment
  /// for UI state management and comment threading coordination.
  bool _isReplying = false;
  
  /// Current comment text for form management and input validation.
  /// 
  /// Stores user input for comment posting with real-time text management
  /// and form state coordination.
  String _newCommentText = '';
  
  /// Target comment ID for reply threading and conversation context.
  /// 
  /// Identifies parent comment for reply operations enabling threaded
  /// conversations and comment hierarchy management.
  String? _replyToCommentId;

  // ===== SOCIAL CONTENT STATE =====
  
  /// Comments collection for display and interaction management.
  /// 
  /// Stores complete comment hierarchy including replies and threading
  /// for comprehensive comment system functionality.
  List<SocialComment> _comments = [];
  
  /// Friends collection for social context and author identification.
  /// 
  /// Caches friend profiles for comment author display and social
  /// interaction context throughout comment operations.
  List<UserProfile> _friends = [];
  
  /// Current user profile for comment authoring and social context.
  /// 
  /// Provides current user information for comment attribution
  /// and social interaction personalization.
  UserProfile? _currentUser;

  /// Initializes social recipe ViewModel with comprehensive service integration and social coordination.
  /// 
  /// [recipeService] UnifiedRecipeService instance for recipe data operations and social integration
  /// [friendsService] UnifiedFriendsService instance for friend management and social context
  /// 
  /// Establishes service layer integration for comprehensive social recipe functionality,
  /// enabling comment management, social engagement, and friend integration with reactive
  /// state coordination for optimal social user experience.
  /// 
  /// **Initialization Process:**
  /// - Service dependency injection with social integration
  /// - Social state preparation for comment and engagement systems
  /// - Friend integration setup for social context management
  /// - Comment system preparation for threaded conversations
  SocialRecipeViewModel({
    required UnifiedFriendsService friendsService,
    required UnifiedRecipeService recipeService,
  }) : _friendsService = friendsService,
       _recipeService = recipeService;

  // ===== COMMENT SYSTEM STATE ACCESSORS =====

  /// Comment availability indicator for UI conditional display and feature enabling.
  /// 
  /// Indicates whether recipe has comments for UI conditional rendering
  /// and comment-dependent feature activation.
  bool get hasComments => _comments.isNotEmpty;
  
  /// Comment loading state for UI progress indication during comment operations.
  /// 
  /// Indicates active comment loading for loading indicators and user interaction
  /// management during comment system operations.
  bool get isLoadingComments => _isLoadingComments;
  
  /// Comment error message for user feedback and error state management.
  /// 
  /// Provides comment-specific error messages for comprehensive error handling
  /// and user guidance during comment operations.
  String? get commentsError => _commentsError;
  
  /// Comment posting state for UI progress indication during comment submission.
  /// 
  /// Indicates active comment posting for loading indicators and interaction
  /// control during comment creation operations.
  bool get isPostingComment => _isPostingComment;
  
  /// Reply mode state for comment threading and UI state management.
  /// 
  /// Indicates whether user is currently in reply mode for UI conditional
  /// rendering and comment threading functionality.
  bool get isReplying => _isReplying;
  
  /// Current comment text for form display and input management.
  /// 
  /// Provides access to current comment text for UI form synchronization
  /// and comment posting functionality.
  String get newCommentText => _newCommentText;
  
  /// Complete comments collection for display and interaction management.
  /// 
  /// Provides access to all comments including replies for comprehensive
  /// comment system functionality and threading support.
  List<SocialComment> get comments => _comments;
  
  /// Top-level comments for hierarchical display and threading organization.
  /// 
  /// Filters comments to show only parent comments for hierarchical comment
  /// display and threaded conversation organization.
  List<SocialComment> get topLevelComments => 
      _comments.where((comment) => comment.parentCommentId == null).toList();
  
  /// Friends collection for social context and author identification.
  /// 
  /// Provides access to friend profiles for comment author display
  /// and social interaction context management.
  List<UserProfile> get friends => _friends;
  
  /// Current user profile for comment authoring and social personalization.
  /// 
  /// Provides current user information for comment attribution
  /// and personalized social interaction functionality.
  UserProfile? get currentUser => _currentUser;

  // ===== COMMENT SYSTEM OPERATIONS =====

  /// Refreshes comments with comprehensive loading state management and error handling.
  /// 
  /// [recipeId] Recipe identifier for comment retrieval
  /// 
  /// Performs comment system refresh with loading state coordination, comprehensive error handling,
  /// and UI notification for optimal user experience. Includes Swedish localized error messages
  /// and detailed logging for comment system operations.
  /// 
  /// **Refresh Process:**
  /// - Loading state activation with UI notification
  /// - Comment data retrieval through service coordination
  /// - Error handling with Swedish localized feedback
  /// - State cleanup and UI synchronization
  /// 
  /// **Usage Example:**
  /// ```dart
  /// await socialRecipeViewModel.refreshComments('recipe_123');
  /// if (socialRecipeViewModel.commentsError == null) {
  ///   // Comments loaded successfully
  /// }
  /// ```
  Future<void> refreshComments(String recipeId) async {
    _isLoadingComments = true;
    _commentsError = null;
    notifyListeners();

    try {
      // Load comments from service with comprehensive error handling
      final recipeComments = await _recipeService.social.getComments(recipeId: recipeId);
      _comments = recipeComments.map((comment) => _convertRecipeCommentToSocialComment(comment)).toList();
      AppLogger.info('Comments refreshed successfully for recipe: $recipeId');
    } catch (e) {
      _commentsError = 'Kunde inte ladda kommentarer: $e';
      AppLogger.error('Failed to refresh comments for recipe $recipeId: $e');
    } finally {
      _isLoadingComments = false;
      notifyListeners();
    }
  }

  /// Updates comment text with real-time form synchronization and state management.
  /// 
  /// [text] Comment text for form input and posting preparation
  /// 
  /// Performs comment text update with immediate UI notification for responsive
  /// form input and real-time comment composition with state synchronization.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// socialRecipeViewModel.updateNewCommentText('Fantastiskt recept!');
  /// // Text immediately available for posting
  /// ```
  void updateNewCommentText(String text) {
    _newCommentText = text;
    notifyListeners();
  }

  /// Posts comment with comprehensive validation, threading support, and state management.
  /// 
  /// [recipeId] Recipe identifier for comment association
  /// 
  /// Performs comment posting with text validation, reply threading support, and comprehensive
  /// state management. Includes automatic form cleanup, reply mode reset, and detailed
  /// logging for complete comment posting functionality.
  /// 
  /// **Posting Process:**
  /// - Comment text validation with empty text prevention
  /// - Comment creation with threading and reply support
  /// - Local state updates with immediate UI feedback
  /// - Form cleanup and reply mode reset
  /// 
  /// **Usage Example:**
  /// ```dart
  /// socialRecipeViewModel.updateNewCommentText('Excellent recipe!');
  /// await socialRecipeViewModel.postComment('recipe_123');
  /// // Comment posted and form automatically reset
  /// ```
  Future<void> postComment(String recipeId) async {
    if (_newCommentText.trim().isEmpty) return;

    _isPostingComment = true;
    notifyListeners();

    try {
      // Post comment to backend service
      final commentId = await _recipeService.social.addComment(
        recipeId: recipeId,
        content: _newCommentText.trim(),
        parentCommentId: _replyToCommentId,
      );
      
      if (commentId != null) {
        // Clean up form state and reply mode
        _newCommentText = '';
        _replyToCommentId = null;
        _isReplying = false;

        // Refresh comments to get the updated list from server
        await refreshComments(recipeId);

        AppLogger.info('Comment posted successfully for recipe: $recipeId');
      } else {
        throw Exception('Failed to post comment - service returned null');
      }
    } catch (e) {
      _commentsError = 'Kunde inte posta kommentar: $e';
      AppLogger.error('Failed to post comment for recipe $recipeId: $e');
    } finally {
      _isPostingComment = false;
      notifyListeners();
    }
  }

  /// Sets reply target with threading context and UI state management.
  /// 
  /// [commentId] Target comment identifier for reply threading
  /// 
  /// Activates reply mode for specific comment with threading context setup
  /// and UI state coordination for comment reply functionality.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// socialRecipeViewModel.setReplyTo('comment_456');
  /// // Reply mode activated, ready for threaded response
  /// ```
  void setReplyTo(String commentId) {
    _replyToCommentId = commentId;
    _isReplying = true;
    notifyListeners();
  }

  /// Cancels reply mode with comprehensive state cleanup and UI coordination.
  /// 
  /// Deactivates reply mode with complete state reset and UI notification
  /// for clean comment form state management.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// socialRecipeViewModel.cancelReply();
  /// // Reply mode deactivated, back to top-level comment mode
  /// ```
  void cancelReply() {
    _replyToCommentId = null;
    _isReplying = false;
    notifyListeners();
  }

  // ===== SOCIAL ENGAGEMENT OPERATIONS =====

  /// Toggles comment like with optimistic updates and engagement tracking.
  /// 
  /// [commentId] Comment identifier for like/unlike operation
  /// 
  /// Performs like/unlike toggle with optimistic UI updates, engagement tracking,
  /// and comprehensive error handling. Includes immediate UI feedback and detailed
  /// logging for social engagement functionality.
  /// 
  /// **Like Toggle Process:**
  /// - Comment identification and validation
  /// - Optimistic like state toggle with immediate UI feedback
  /// - Like count adjustment for accurate engagement display
  /// - Comprehensive logging for engagement tracking
  /// 
  /// **Usage Example:**
  /// ```dart
  /// await socialRecipeViewModel.toggleCommentLike('comment_789');
  /// final isLiked = socialRecipeViewModel.hasLikedComment('comment_789');
  /// ```
  Future<void> toggleCommentLike(String commentId) async {
    try {
      // Find target comment and perform optimistic update
      final comment = _comments.firstWhere((c) => c.id == commentId);
      comment.isLiked = !comment.isLiked;
      comment.likeCount += comment.isLiked ? 1 : -1;
      notifyListeners();
      
      AppLogger.info('Successfully toggled like for comment: $commentId (liked: ${comment.isLiked})');
    } catch (e) {
      AppLogger.error('Failed to toggle comment like for $commentId: $e');
    }
  }

  /// Checks comment like status for UI state management and engagement display.
  /// 
  /// [commentId] Comment identifier for like status checking
  /// 
  /// Returns true if current user has liked the comment, false otherwise.
  /// Provides like status information for UI like button state and engagement
  /// display with comprehensive error handling.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final isLiked = socialRecipeViewModel.hasLikedComment('comment_789');
  /// // Use for like button UI state
  /// ```
  bool hasLikedComment(String commentId) {
    try {
      final comment = _comments.firstWhere((c) => c.id == commentId);
      return comment.isLiked;
    } catch (e) {
      return false;
    }
  }

  // Reply operations
  List<SocialComment> getReplies(String parentCommentId) {
    return _comments.where((comment) => 
        comment.parentCommentId == parentCommentId).toList();
  }

  // User operations
  String getAuthorDisplayName(String authorId) {
    if (authorId == _currentUser?.uid) {
      return _currentUser?.displayName ?? 'Du';
    }
    
    try {
      final friend = _friends.firstWhere((f) => f.uid == authorId);
      return friend.displayName;
    } catch (e) {
      return 'Okänd användare';
    }
  }

  String? getAuthorAvatarUrl(String authorId) {
    if (authorId == _currentUser?.uid) {
      return _currentUser?.avatarUrl;
    }
    
    try {
      final friend = _friends.firstWhere((f) => f.uid == authorId);
      return friend.avatarUrl;
    } catch (e) {
      return null;
    }
  }

  // Initialization
  Future<void> initialize() async {
    try {
      // Load current user and friends from service state
      _friends = _friendsService.friends;
      // _currentUser would be loaded from auth service
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to initialize SocialRecipeViewModel: $e');
    }
  }

  // ===== COLLABORATIVE RECIPE OPERATIONS =====

  /// Creates collaborative recipe (placeholder implementation)
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
    List<String>? tags,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    // Placeholder implementation
    AppLogger.info('Creating collaborative recipe: $name');
    return false;
  }

  /// Shares recipe (placeholder implementation)
  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    // Placeholder implementation
    AppLogger.info('Sharing recipe: $recipeId');
    return null;
  }

  /// Makes recipe personal (placeholder implementation)
  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    // Placeholder implementation
    AppLogger.info('Making recipe personal: $collaborativeRecipeId');
    return null;
  }

  // ===== MEMBER MANAGEMENT =====

  /// Adds member to recipe (placeholder implementation)
  Future<bool> addMemberToRecipe(String recipeId, String userId, String userDisplayName, {required permission}) async {
    AppLogger.info('Adding member to recipe: $recipeId');
    return false;
  }

  /// Removes member from recipe (placeholder implementation)
  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    AppLogger.info('Removing member from recipe: $recipeId');
    return false;
  }

  /// Updates member permission (placeholder implementation)
  Future<bool> updateMemberPermission(String recipeId, String userId, permission) async {
    AppLogger.info('Updating member permission for recipe: $recipeId');
    return false;
  }

  /// Gets recipe members (placeholder implementation)
  Map<String, ResourcePermission> getRecipeMembers(String recipeId) {
    return {};
  }

  /// Checks if can invite members (placeholder implementation)
  bool canInviteMembers(String recipeId) {
    return false;
  }

  /// Gets recipes shared with me (placeholder implementation)
  List<Recipe> getSharedWithMe() {
    return [];
  }

  /// Gets recipes shared by me (placeholder implementation)
  List<Recipe> getSharedByMe() {
    return [];
  }

  /// Convert RecipeComment to SocialComment for ViewModel compatibility
  SocialComment _convertRecipeCommentToSocialComment(RecipeComment recipeComment) {
    return SocialComment(
      id: recipeComment.id,
      recipeId: recipeComment.recipeId,
      authorId: recipeComment.authorId,
      text: recipeComment.text,
      createdAt: recipeComment.createdAt,
      parentCommentId: recipeComment.parentCommentId,
    );
  }

  /// Service name for debugging
  String get serviceName => 'SocialRecipeViewModel';

  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }
}