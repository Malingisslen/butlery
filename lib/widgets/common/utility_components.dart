/// lib/widgets/common/utility_components.dart

import 'package:flutter/material.dart';
import '../../models/recipe_unified.dart';
import '../../models/permissions/edit_mode.dart';

// Import the focused components
import 'buttons/action_buttons.dart';
import 'service/service_widgets.dart';
import 'loading/loading_widgets.dart';
import 'friends/friend_category_widgets.dart';
import 'permissions/permission_widgets.dart';
import 'feedback/snackbar_widgets.dart';

// Re-export ActionButtonStyle from the focused component
export 'buttons/action_buttons.dart' show ActionButtonStyle;

/// UtilityComponents - Den kompletta utility widget API:en
///
/// Konsoliderar ActionButton, RecipeServiceWidget, FriendCategoryManager och utility helpers
/// till en unified API för alla utility patterns i Butlery appen.
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

