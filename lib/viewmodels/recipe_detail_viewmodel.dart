/// Comprehensive recipe detail ViewModel providing advanced recipe interaction and management for Flutter applications.
/// This module implements sophisticated recipe detail management following Single Responsibility Principle,
/// handling all aspects of individual recipe presentation including detailed display coordination, recipe interactions,
/// analytics tracking, and comprehensive state management. It provides complete recipe detail infrastructure while
/// maintaining clean separation from UI rendering, data persistence, and business logic implementation.
/// **Single Responsibility Focus:**
/// This module exclusively handles recipe detail presentation layer concerns:
/// - **Recipe Display Intelligence**: Comprehensive recipe detail coordination with multi-image support and dynamic UI state
/// - **Recipe Interaction Management**: Advanced recipe operations including cooking tracking, rating management, and user engagement
/// - **Analytics Integration**: Sophisticated analytics tracking for recipe interactions, cooking events, and user behavior
/// - **State Synchronization**: Reactive state management with service integration and real-time recipe update coordination
/// - **UI Convenience Accessors**: Comprehensive convenience getters for complex UI display logic and conditional rendering
/// **What This Module Does NOT Handle:**
/// - Recipe data persistence and storage (handled by UnifiedRecipeService and data repositories)
/// - UI rendering and widget creation (handled by RecipeDetailView and recipe detail UI components)
/// - Recipe business logic and validation (handled by recipe service layer and business logic)
/// - Analytics implementation and data processing (handled by AnalyticsService for focused analytics responsibility)
/// **Recipe Detail ViewModel Features:**
/// - **Multi-Image Support**: Advanced image management with multiple image display and gallery coordination
/// - **Cooking Interaction**: Comprehensive cooking tracking with timestamp management and analytics integration
/// - **Real-time Synchronization**: Intelligent recipe state updates with service coordination and change detection
/// - **Analytics Intelligence**: Detailed user interaction tracking with cooking events and engagement metrics
/// - **Swedish Localization**: Complete Swedish language support for display formatting and user interface
/// **Usage Examples:**
/// ```dart
/// // Initialize recipe detail ViewModel with recipe data
/// final recipeDetailViewModel = RecipeDetailViewModel(
///   recipe: selectedRecipe,
///   recipeService: unifiedRecipeService,
///   analyticsService: analyticsService,
/// );
/// // Recipe interaction operations
/// final cookingMarked = await recipeDetailViewModel.markAsCooked();
/// if (cookingMarked) {
///   // Show cooking success feedback
/// }
/// // Recipe management operations
/// final deleted = await recipeDetailViewModel.deleteRecipe();
/// if (deleted) {
///   // Navigate back to recipe list
/// }
/// // UI display convenience accessors
/// if (recipeDetailViewModel.hasMultipleImages) {
///   // Show image gallery UI
/// }
/// final portions = recipeDetailViewModel.portionsDisplay; // "4" or "–"
/// final cookingTime = recipeDetailViewModel.timeDisplay; // "30" or "–"
/// final rating = recipeDetailViewModel.ratingDisplay; // "4.5" or "–"
/// // State monitoring for UI updates
/// if (recipeDetailViewModel.isDeleting) {
///   // Show deletion progress
/// }
/// // Reactive recipe updates
/// final currentRecipe = recipeDetailViewModel.recipe; // Always current version
/// ```

// lib/viewmodels/recipe_detail_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive recipe detail ViewModel providing advanced recipe interaction and management for Flutter applications.
/// Serves as the presentation layer coordinator for individual recipe operations, providing detailed display coordination,
/// recipe interactions, analytics tracking, and real-time state management while maintaining clean MVVM architecture
/// separation between recipe detail business logic and UI presentation concerns.
class RecipeDetailViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  StreamSubscription? _recipeServiceSubscription;
  final UnifiedRecipeService _recipeService;
  final AnalyticsService _analyticsService;

  /// Current recipe data with real-time synchronization and state coordination.
  Recipe _recipe;

  /// Deletion operation state for UI progress indication and interaction control.
  bool _isDeleting = false;

  /// Initializes recipe detail ViewModel with comprehensive service integration and reactive state coordination.
  /// [recipe] Recipe instance for detailed display and interaction management
  /// [recipeService] Optional UnifiedRecipeService instance for dependency injection
  /// [analyticsService] Optional AnalyticsService instance for dependency injection
  /// Establishes service layer integration with reactive state coordination, enabling
  /// comprehensive recipe detail management with automatic synchronization and analytics tracking
  /// for optimal user experience and interaction monitoring.
  RecipeDetailViewModel({
    required Recipe recipe,
    UnifiedRecipeService? recipeService,
    AnalyticsService? analyticsService,
  })  : _recipe = recipe,
        _recipeService =
            recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
        _analyticsService =
            analyticsService ?? ServiceLocator.get<AnalyticsService>() {
    _recipeServiceSubscription =
        _recipeService.stateStream.listen((_) => _onRecipeServiceUpdate());

    _analyticsService.recipe.logRecipeViewed(
      recipeId: recipe.id,
      recipeType: recipe.type.name,
      source: 'detail',
    );
  }

  /// Performs comprehensive ViewModel disposal with service listener cleanup and memory management.
  /// Removes UnifiedRecipeService listener connections and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic recipe detail scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _recipeServiceSubscription?.cancel();
    super.dispose();
  }

  /// Handles reactive updates from recipe service changes with intelligent state synchronization.
  /// Provides seamless state synchronization between UnifiedRecipeService and ViewModel ensuring
  /// recipe data changes are immediately reflected with change detection and automatic UI updates
  /// for consistent user experience and real-time recipe status coordination.
  void _onRecipeServiceUpdate() {
    // Update our recipe if it has changed in service
    final updatedRecipe = _recipeService.getRecipeById(_recipe.id);
    if (updatedRecipe != null && updatedRecipe.updatedAt != _recipe.updatedAt) {
      _recipe = updatedRecipe;
      notifyListeners();
    }
  }

  /// Current recipe data with real-time synchronization and comprehensive detail access.
  /// Provides access to current recipe state with automatic synchronization from service updates
  /// ensuring UI components always display the most current recipe information.
  Recipe get recipe => _recipe;

  /// Exposes recipe service for sub-widgets that need social operations (e.g. rating checks).
  UnifiedRecipeService get recipeService => _recipeService;

  /// Deletion operation state for UI progress indication and interaction control.
  /// Indicates active deletion operation for UI loading indicators and interaction disabling
  /// during recipe deletion processes for optimal user experience and operation feedback.
  bool get isDeleting => _isDeleting;

  /// Error state placeholder for future error handling expansion and consistency.
  /// Currently returns null as recipe detail operations use ErrorHandlingMixin
  /// for comprehensive error management, designed for future error state expansion.
  @override
  String? get error => null; // No error state needed for now

  /// Error presence indicator for UI conditional rendering and future error handling.
  /// Currently returns false as recipe detail operations use ErrorHandlingMixin
  /// for error management, maintaining consistency with other ViewModels.
  @override
  bool get hasError => false; // No error state needed for now
  /// Image presence indicator for conditional image display and gallery coordination.
  /// Indicates whether recipe has associated images for UI conditional rendering
  /// of image display components and gallery functionality.
  bool get hasImages => _recipe.hasImages;

  /// Multiple image indicator for gallery UI coordination and advanced image display.
  /// Indicates whether recipe has multiple images for UI gallery display decisions
  /// and advanced image navigation functionality activation.
  bool get hasMultipleImages => _recipe.imageUrls.length > 1;

  /// Formatted portions display with fallback for consistent UI presentation.
  /// Provides portions information formatted for UI display with Swedish dash fallback
  /// for recipes without portion information, ensuring consistent UI presentation.
  String get portionsDisplay => _recipe.portions?.toString() ?? '–';

  /// Formatted cooking time display with fallback for consistent UI presentation.
  /// Provides cooking time in minutes formatted for UI display with Swedish dash fallback
  /// for recipes without time information, ensuring consistent UI presentation.
  String get timeDisplay => _recipe.timeMinutes?.toString() ?? '–';

  /// Rating presence indicator for conditional rating display and UI coordination.
  /// Indicates whether recipe has rating information for UI conditional rendering
  /// of rating display components and rating-related functionality.
  bool get hasRating => _recipe.rating != null;

  /// Formatted rating display with precision control and fallback for consistent UI presentation.
  /// Provides rating formatted to one decimal place for UI display with Swedish dash fallback
  /// for recipes without rating information, ensuring consistent UI presentation.
  String get ratingDisplay => _recipe.rating?.toStringAsFixed(1) ?? '–';

  /// Tags presence indicator for conditional tag display and UI coordination.
  /// Indicates whether recipe has associated tags for UI conditional rendering
  /// of tag display components and tag-related functionality.
  bool get hasTags =>
      _recipe.personalTagIds != null && _recipe.personalTagIds!.isNotEmpty;

  /// Deletes recipe with comprehensive analytics tracking and progress management.
  /// Returns true if deletion succeeds, false if operation fails.
  /// Performs complete recipe deletion flow including service coordination, analytics tracking,
  /// and comprehensive error handling with progress state management for optimal user experience.
  /// **Deletion Process:**
  /// - Deletion state management with UI progress indication
  /// - Service-coordinated recipe deletion with error handling
  /// - Comprehensive analytics tracking with recipe metadata
  /// - Progress state cleanup with automatic UI synchronization
  /// **Usage Example:**
  /// ```dart
  /// final deleted = await recipeDetailViewModel.deleteRecipe();
  /// if (deleted) {
  ///   // Navigate back to recipe list
  /// } else {
  ///   // Show deletion error message
  /// }
  /// ```
  Future<bool> deleteRecipe() async {
    _setDeleting(true);

    try {
      final result = await executeAsync(() async {
        final success = await _recipeService.deleteRecipe(_recipe.id);

        if (success) {
          // Log analytics for recipe deletion
          await _analyticsService.logRecipeDeleted(
            recipeId: _recipe.id,
            mealType: _recipe.mealType,
            isPersonal: _recipe.isPersonal,
            createdAt: _recipe.createdAt,
          );

          // P8-15: Update recipe count user property
          await _analyticsService.setUserProperties(
            recipeCount: _recipeService.recipes.length,
          );

          return true;
        } else {
          final errorMessage = _recipeService.error ??
              AppLocale.current.errorCouldNotDeleteRecipe;
          throw Exception(errorMessage);
        }
      });

      return result;
    } finally {
      _setDeleting(false);
    }
  }

  /// Marks recipe as cooked with comprehensive analytics tracking and state management.
  /// Returns true if cooking mark succeeds, false if operation fails.
  /// Performs complete cooking tracking flow including timestamp update, service coordination,
  /// analytics integration, and state synchronization for comprehensive cooking interaction management.
  /// **Cooking Tracking Process:**
  /// - Recipe state update with current cooking timestamp
  /// - Service-coordinated recipe update with error handling
  /// - Local state synchronization with immediate UI updates
  /// - Comprehensive analytics tracking with first-time cooking detection
  /// **Usage Example:**
  /// ```dart
  /// final cookingMarked = await recipeDetailViewModel.markAsCooked();
  /// if (cookingMarked) {
  ///   // Show cooking success feedback
  ///   // Analytics automatically tracked
  /// } else {
  ///   // Handle cooking mark failure
  /// }
  /// ```
  bool get wasCookedToday {
    final last = _recipe.lastCookedAt;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  Future<bool> markAsCooked() async {
    if (wasCookedToday) return false;

    return await executeAsync(() async {
      final isFirstTime = _recipe.lastCookedAt == null;

      final updatedRecipe = _recipe.copyWith(
        lastCookedAt: DateTime.now(),
        cookCount: _recipe.cookCount + 1,
      );

      final success = await _recipeService.updateRecipe(updatedRecipe);

      if (success) {
        _recipe = updatedRecipe;
        notifyListeners();

        await _analyticsService.logRecipeCooked(
          recipeId: _recipe.id,
          mealType: _recipe.mealType,
          isFirstTime: isFirstTime,
        );

        return true;
      } else {
        throw Exception(AppLocale.current.errorCouldNotUpdate('recept'));
      }
    });
  }

  /// Toggles the favorite status of this recipe.
  /// Performs optimistic UI update then persists via service.
  Future<void> toggleFavorite() async {
    final newValue = !_recipe.isFavorite;
    _recipe = _recipe.copyWith(isFavorite: newValue);
    notifyListeners();
    await _recipeService.toggleFavorite(_recipe.id, newValue);
  }

  /// Rates this recipe with a 1-5 star value.
  /// For personal recipes: persists via updateRecipe.
  /// For shared/collaborative: uses social rating system.
  Future<bool> rateRecipe(double rating) async {
    return await executeAsync(() async {
      final previousRating = _recipe.rating;

      if (_recipe.isPersonal) {
        // Optimistic update
        _recipe = _recipe.copyWith(rating: rating);
        notifyListeners();

        final success = await _recipeService.updateRecipe(_recipe);
        if (!success) {
          // Revert on failure
          _recipe = _recipe.copyWith(rating: previousRating);
          notifyListeners();
          throw Exception(AppLocale.current.errorCouldNotUpdate('betyg'));
        }
        return true;
      } else {
        // Shared/collaborative — use social rating system
        final success = await _recipeService.social.rateRecipe(
          recipeId: _recipe.id,
          rating: rating,
        );
        if (success) {
          _recipe = _recipe.copyWith(rating: rating);
          notifyListeners();
          return true;
        } else {
          throw Exception(AppLocale.current.errorCouldNotUpdate('betyg'));
        }
      }
    });
  }

  /// Removes the current user's rating from this recipe.
  /// Returns true if the rating was successfully removed.
  Future<bool> removeMyRating() async {
    return await executeAsync(() async {
      final success = await _recipeService.social.removeRating(_recipe.id);
      if (success) {
        // Clear the local rating so UI updates immediately
        _recipe = _recipe.copyWith(rating: null);
        notifyListeners();
        return true;
      } else {
        throw Exception(AppLocale.current.errorCouldNotDelete('betyg'));
      }
    });
  }

  /// Updates deletion state with automatic UI notification for progress indication.
  /// [value] New deletion state for progress tracking
  /// Manages deletion operation state with immediate UI notification enabling
  /// progress indicators and interaction control during recipe deletion operations.
  void _setDeleting(bool value) {
    _isDeleting = value;
    notifyListeners();
  }

  /// Updates recipe with new data and notifies listeners.
  /// Used for in-place updates like re-tagging without full service reload.
  void updateRecipe(Recipe updatedRecipe) {
    _recipe = updatedRecipe;
    notifyListeners();
  }

  /// Clears error state with comprehensive state management and UI synchronization.
  /// Provides error state cleanup capability designed for future error handling expansion
  /// and consistency with other ViewModels for comprehensive error management patterns.
  @override
  void clearError() {
    // Clear any error state if needed
    notifyListeners();
  }
}
