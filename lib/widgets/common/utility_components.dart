/// Comprehensive utility components facade providing unified interface for all application utility widgets and helper functionality.
/// This facade implements a centralized utility system that consolidates action buttons, service integration widgets,
/// loading states, friend category management, permission-based actions, and feedback mechanisms into a single
/// cohesive API. It delegates to specialized utility modules while maintaining consistent interface patterns and
/// providing comprehensive support for Swedish localization throughout all utility functionality.
/// **Architecture Integration:**
/// - Implements Facade Pattern for unified access to specialized utility modules
/// - Provides consistent API for all utility patterns throughout the application
/// - Integrates with service layer for data loading and error handling
/// - Supports permission-based UI rendering with collaborative editing features
/// - Maintains responsive design patterns for various screen sizes and orientations
/// **Utility Categories:**
/// - **Action Buttons**: Primary, secondary, outlined, and specialized button variants
/// - **Service Integration**: Widgets for service data loading with state management
/// - **Loading Components**: Overlays, error boundaries, and responsive wrappers
/// - **Friend Management**: Category selection and social sharing functionality
/// - **Permission Widgets**: Collaborative editing buttons based on user permissions
/// - **Feedback Systems**: Success, error, and warning notifications with Swedish localization
/// **Key Features:**
/// - Comprehensive button system with loading states and multiple styling options
/// - Service integration widgets with automatic error handling and loading states
/// - Friend category management for social sharing and collaborative features
/// - Permission-aware UI components for collaborative editing scenarios
/// - Responsive design support with adaptive layouts and spacing
/// - Swedish localization throughout all utility components and messaging
/// **Usage Examples:**
/// ```dart
/// // Action button with loading state
/// UtilityComponents.primaryButton(
///   context,
///   label: 'Spara recept',
///   icon: Icons.save,
///   isLoading: isLoading,
///   onPressed: () => saveRecipe(),
/// );
/// // Friend category manager for sharing
/// UtilityComponents.friendCategoryManager(
///   selectedFriendIds: selectedFriends,
///   onSelectionChanged: (friends) => updateSelection(friends),
///   title: 'Dela med vänner',
/// );
/// // Permission-based action buttons
/// UtilityComponents.permissionsActionButtons(
///   context: context,
///   editMode: editMode,
///   onSave: () => saveChanges(),
///   onFork: () => createFork(),
/// );
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/edit_mode.dart';

// Import the focused components
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/service/service_widgets.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/widgets/common/friends/friend_category_widgets.dart';
import 'package:butlery/widgets/common/permissions/permission_widgets.dart';
import 'package:butlery/widgets/common/feedback/snackbar_widgets.dart';

// Re-export ActionButtonStyle from the focused component
export 'buttons/action_buttons.dart' show ActionButtonStyle;

/// Comprehensive utility components facade implementing unified interface for all application utility widgets and helper functionality.
/// This class serves as the central access point for all utility-related functionality throughout the application,
/// providing consistent interface patterns and delegating to specialized utility modules for optimal performance
/// and maintainability. It supports Swedish localization, responsive design, collaborative features, and
/// comprehensive state management across all utility scenarios.
/// **Utility Architecture:**
/// - **Modular Design**: Each utility type is handled by a focused specialized module
/// - **Consistent API**: Unified method signatures and parameter patterns across all components
/// - **Swedish Localization**: Native Swedish language support throughout all utility messaging
/// - **Permission Integration**: Collaborative editing support with role-based UI rendering
/// - **Responsive Support**: Adaptive layouts for various screen sizes and device orientations
/// **Migration Support:**
/// This facade maintains full backward compatibility while providing improved organization,
/// performance, and consistency through the delegation pattern to specialized utility modules.
class UtilityComponents {
  // ============================================================================
  // === ACTION BUTTON COMPONENTS (delegerar till ActionButtons) ===
  // ============================================================================

  /// Standard action button med loading support och flera styles
  static Widget actionButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    ActionButtonStyle style = ActionButtonStyle.primary,
    bool isExpanded = false,
  }) {
    return ActionButtons.actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: style,
      isExpanded: isExpanded,
    );
  }

  /// Square button for grid layouts (recipe upload view)
  static Widget squareButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
  }) {
    return ActionButtons.squareButton(
      context,
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
    );
  }

  /// Large prominent button for important actions
  static Widget largeButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
    double height = 100,
    EdgeInsets? margin,
  }) {
    return ActionButtons.largeButton(
      context,
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
      height: height,
      margin: margin,
    );
  }

  /// Primary action button convenience method
  static Widget primaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return ActionButtons.primaryButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      isExpanded: isExpanded,
    );
  }

  /// Secondary action button convenience method
  static Widget secondaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return ActionButtons.secondaryButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      isExpanded: isExpanded,
    );
  }

  /// Outlined action button convenience method
  static Widget outlinedButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return ActionButtons.outlinedButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      isExpanded: isExpanded,
    );
  }

  // ============================================================================
  // === SERVICE INTEGRATION COMPONENTS (delegerar till ServiceWidgets) ===
  // ============================================================================

  /// Widget som integrerar med RecipeService och hanterar loading/error states
  static Widget serviceWidget({
    required Widget Function(List<Recipe> recipes) builder,
    Widget? loadingWidget,
    Widget Function(String error)? errorBuilder,
    bool showLoadingOverlay = false,
  }) {
    return ServiceWidgets.serviceWidget(
      builder: builder,
      loadingWidget: loadingWidget,
      errorBuilder: errorBuilder,
      showLoadingOverlay: showLoadingOverlay,
    );
  }

  /// Generic service widget för andra services
  static Widget genericServiceWidget<T extends Listenable>({
    required T service,
    required Widget Function(BuildContext context, T service) builder,
  }) {
    return ServiceWidgets.genericServiceWidget(
      service: service,
      builder: builder,
    );
  }

  // ============================================================================
  // === LOADING & ERROR UTILITY COMPONENTS (delegerar till LoadingWidgets) ===
  // ============================================================================

  /// Loading overlay som visas över existerande innehåll
  static Widget loadingOverlay({
    Widget? child,
    bool isLoading = false,
    String? loadingMessage,
    Color? overlayColor,
  }) {
    return LoadingWidgets.loadingOverlay(
      child: child,
      isLoading: isLoading,
      loadingMessage: loadingMessage,
      overlayColor: overlayColor,
    );
  }

  /// Error boundary som hanterar exceptions gracefully
  static Widget errorBoundary({
    required Widget child,
    Widget? errorWidget,
    Function(Object error, StackTrace stack)? onError,
  }) {
    return LoadingWidgets.errorBoundary(
      child: child,
      errorWidget: errorWidget,
      onError: onError,
    );
  }

  /// Responsive wrapper för adaptiv layout
  static Widget responsiveWrapper({
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
  }) {
    return LoadingWidgets.responsiveWrapper(
      child: child,
      maxWidth: maxWidth,
      padding: padding,
    );
  }

  // ============================================================================
  // === FRIEND CATEGORY MANAGEMENT (delegerar till FriendCategoryWidgets) ===
  // ============================================================================

  /// Komplett friend category manager för social sharing
  static Widget friendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    bool allowMultipleCategories = true,
    String title = 'Välj vänner',
    String subtitle = 'Välj kategorier eller individuella vänner',
  }) {
    return FriendCategoryWidgets.friendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      allowMultipleCategories: allowMultipleCategories,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Kompakt variant för mindre utrymmen
  static Widget compactFriendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    int maxHeight = 300,
  }) {
    return FriendCategoryWidgets.compactFriendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      maxHeight: maxHeight,
    );
  }

  // ============================================================================
  // === PERMISSIONS ACTION BUTTONS (delegerar till PermissionWidgets) ===
  // ============================================================================

  /// Action buttons baserat på användares permissions för kollaborativ redigering
  static Widget permissionsActionButtons({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onSave,
    VoidCallback? onFork,
    bool isSaving = false,
    bool isForking = false,
    String? saveLabel,
    String? forkLabel,
    bool isExpanded = true,
  }) {
    return PermissionWidgets.permissionsActionButtons(
      context: context,
      editMode: editMode,
      onSave: onSave,
      onFork: onFork,
      isSaving: isSaving,
      isForking: isForking,
      saveLabel: saveLabel,
      forkLabel: forkLabel,
      isExpanded: isExpanded,
    );
  }

  /// Horizontal layout för permissions buttons (för mindre skärmar)
  static Widget permissionsActionButtonsHorizontal({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onSave,
    VoidCallback? onFork,
    bool isSaving = false,
    bool isForking = false,
    String? saveLabel,
    String? forkLabel,
  }) {
    return PermissionWidgets.permissionsActionButtonsHorizontal(
      context: context,
      editMode: editMode,
      onSave: onSave,
      onFork: onFork,
      isSaving: isSaving,
      isForking: isForking,
      saveLabel: saveLabel,
      forkLabel: forkLabel,
    );
  }

  // ============================================================================
  // === SNACKBAR UTILITIES (delegerar till SnackbarWidgets) ===
  // ============================================================================

  /// Visa success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    SnackbarWidgets.showSuccessSnackbar(context, message);
  }

  /// Visa error snackbar
  static void showErrorSnackbar(BuildContext context, String message) {
    SnackbarWidgets.showErrorSnackbar(context, message);
  }

  /// Visa warning snackbar
  static void showWarningSnackbar(BuildContext context, String message) {
    SnackbarWidgets.showWarningSnackbar(context, message);
  }
}

