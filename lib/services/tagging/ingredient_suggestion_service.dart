import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/base/base_service.dart' hide PermissionService;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';

/// Service for submitting unknown ingredient suggestions to admins.
///
/// When the tagging system encounters unknown ingredients, users can
/// submit suggestions for adding them to the ingredient database.
/// Suggestions are stored in Firestore and trigger admin notifications.
class IngredientSuggestionService extends BaseService {
  final FirebaseFirestore _firestore;
  final PermissionService _permissionService;

  @override
  String get serviceName => 'IngredientSuggestionService';

  IngredientSuggestionService({
    required FirebaseFirestore firestore,
    required PermissionService permissionService,
  })  : _firestore = firestore,
        _permissionService = permissionService;

  /// Collection reference for ingredient suggestions.
  CollectionReference<Map<String, dynamic>> get _suggestionsCollection =>
      _firestore.collection('ingredientSuggestions');

  /// Submits a suggestion for an unknown ingredient.
  ///
  /// Parameters:
  /// - [ingredientName]: The unknown ingredient name as entered by user
  /// - [recipeContext]: Optional recipe title/id for context
  /// - [suggestedCategory]: Optional category suggestion from user
  /// - [suggestedProperties]: Optional properties the user thinks apply
  ///
  /// Returns the suggestion ID if successful, null if failed.
  Future<String?> submitSuggestion({
    required String ingredientName,
    String? recipeContext,
    String? suggestedCategory,
    List<String>? suggestedProperties,
  }) async {
    final userId = _permissionService.currentUserId;
    if (userId == null) {
      AppLogger.warning('Cannot submit suggestion: user not logged in');
      return null;
    }

    final normalizedName = ingredientName.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      AppLogger.warning('Cannot submit suggestion: empty ingredient name');
      return null;
    }

    return await executeServiceOperation(
      () async {
        // Check for duplicate pending suggestions from same user
        final existing = await _suggestionsCollection
            .where('userId', isEqualTo: userId)
            .where('ingredientName', isEqualTo: normalizedName)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          AppLogger.info(
            'Duplicate suggestion skipped: $normalizedName already pending',
          );
          return existing.docs.first.id;
        }

        final suggestion = IngredientSuggestion(
          userId: userId,
          ingredientName: normalizedName,
          originalName: ingredientName.trim(),
          suggestedCategory: suggestedCategory,
          suggestedProperties: suggestedProperties,
          recipeContext: recipeContext,
          status: SuggestionStatus.pending,
          createdAt: DateTime.now(),
        );

        final docRef =
            await _suggestionsCollection.add(suggestion.toFirestore());

        AppLogger.info(
          '📤 Submitted ingredient suggestion: $normalizedName (${docRef.id})',
        );

        return docRef.id;
      },
      operationName: 'Submit ingredient suggestion',
      requiresAuth: true,
    );
  }

  /// Gets pending suggestions for the current user.
  Future<List<IngredientSuggestion>> getMyPendingSuggestions() async {
    final userId = _permissionService.currentUserId;
    if (userId == null) return [];

    final result = await executeServiceOperation(
      () async {
        final snapshot = await _suggestionsCollection
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

        return snapshot.docs
            .map((doc) => IngredientSuggestion.fromFirestore(doc))
            .toList();
      },
      operationName: 'Get pending suggestions',
      requiresAuth: true,
    );
    return result ?? [];
  }

  /// Cancels a pending suggestion.
  Future<bool> cancelSuggestion(String suggestionId) async {
    return await executeServiceOperation(
          () async {
            final userId = _permissionService.currentUserId;
            if (userId == null) return false;

            final doc = await _suggestionsCollection.doc(suggestionId).get();
            if (!doc.exists) return false;

            final data = doc.data()!;
            if (data['userId'] != userId) {
              AppLogger.warning(
                  'Cannot cancel: suggestion belongs to another user');
              return false;
            }

            if (data['status'] != 'pending') {
              AppLogger.warning('Cannot cancel: suggestion already processed');
              return false;
            }

            await _suggestionsCollection.doc(suggestionId).update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });

            AppLogger.info('Cancelled ingredient suggestion: $suggestionId');
            return true;
          },
          operationName: 'Cancel suggestion',
          requiresAuth: true,
        ) ??
        false;
  }
}

/// Status of an ingredient suggestion.
enum SuggestionStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

/// Model for ingredient suggestions.
class IngredientSuggestion {
  final String? id;
  final String userId;
  final String ingredientName;
  final String originalName;
  final String? suggestedCategory;
  final List<String>? suggestedProperties;
  final String? recipeContext;
  final SuggestionStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;

  const IngredientSuggestion({
    this.id,
    required this.userId,
    required this.ingredientName,
    required this.originalName,
    this.suggestedCategory,
    this.suggestedProperties,
    this.recipeContext,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'ingredientName': ingredientName,
      'originalName': originalName,
      if (suggestedCategory != null) 'suggestedCategory': suggestedCategory,
      if (suggestedProperties != null)
        'suggestedProperties': suggestedProperties,
      if (recipeContext != null) 'recipeContext': recipeContext,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewNotes != null) 'reviewNotes': reviewNotes,
    };
  }

  factory IngredientSuggestion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return IngredientSuggestion(
      id: doc.id,
      userId: data['userId'] as String,
      ingredientName: data['ingredientName'] as String,
      originalName: data['originalName'] as String? ?? data['ingredientName'],
      suggestedCategory: data['suggestedCategory'] as String?,
      suggestedProperties: data['suggestedProperties'] != null
          ? List<String>.from(data['suggestedProperties'])
          : null,
      recipeContext: data['recipeContext'] as String?,
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewedBy: data['reviewedBy'] as String?,
      reviewNotes: data['reviewNotes'] as String?,
    );
  }

  static SuggestionStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return SuggestionStatus.approved;
      case 'rejected':
        return SuggestionStatus.rejected;
      case 'cancelled':
        return SuggestionStatus.cancelled;
      default:
        return SuggestionStatus.pending;
    }
  }
}
